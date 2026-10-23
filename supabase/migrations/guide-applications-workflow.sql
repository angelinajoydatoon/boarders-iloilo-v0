-- =============================================================================
-- Guide applications workflow
-- Run this yourself in the Supabase SQL Editor. Nothing in the app runs it.
-- Plain ASCII only. Every statement is safe to re-run.
--
-- Run it in this order, as separate runs:
--   Step 0  read-only checks (review the output first)
--   Part 1  schema, status migration, functions, trigger   (re-runnable)
--   Part 2  duplicate pending cleanup                      (preview first, then delete)
--   Part 3  one-pending-per-student unique index           (fails if Part 2 was skipped)
--
-- Student guide statuses (exactly these four, this capitalisation):
--   Pending            written by the student form
--   Agreement Required written by admin Approve (admin_decide_guide_application)
--   Active Guide       written by the student accepting the agreement
--                      (accept_student_guide_agreement)
--   Rejected           written by admin Reject (with a reason), or by the student
--                      declining the agreement (decline_student_guide_agreement)
--
-- Old names that Part 1 maps to the new ones:
--   'Pending Review'                 -> 'Pending'
--   'Approved - Agreement Required'  -> 'Agreement Required'  (any dash style)
--   'Active Student Guide'           -> 'Active Guide'
--
-- The student_guide role is granted by a trigger when a row moves from
-- 'Agreement Required' to 'Active Guide', so guide access begins only after
-- the agreement is accepted. This file never touches admin_roles or is_admin().
--
-- Assumptions (not verifiable from the repo, check them with Step 0):
--   * student_guide_applications has id, student_id, status, full_name, email,
--     created_at, updated_at, eligible_to_reapply_at
--   * public.is_admin() exists and returns boolean
--   * audit_events(actor_id, action, entity_type, entity_id, metadata) exists
--   * notifications(user_id, title, body, kind) exists
-- =============================================================================


-- =============================================================================
-- STEP 0 (read-only). Run these selects first and check the results.
-- =============================================================================

-- 0a. Existing CHECK constraints on the table. Part 1 drops any CHECK that
--     depends only on the status column and replaces it with the four statuses.
select conname, pg_get_constraintdef(oid) as definition
from pg_constraint
where conrelid = 'public.student_guide_applications'::regclass
  and contype = 'c';

-- 0b. Column types for the tables the functions write to.
select table_name, column_name, data_type
from information_schema.columns
where table_schema = 'public'
  and table_name in ('student_guide_applications', 'audit_events', 'notifications')
order by table_name, ordinal_position;

-- 0c. Existing definition of public.is_admin().
select pg_get_functiondef('public.is_admin()'::regprocedure);

-- 0d. Definitions of the existing agreement functions. Part 1 DROPS every
--     function with these names in schema public and recreates them with the
--     new statuses. Check here whether they write columns this file does not
--     know about (for example an agreement date or version column).
select p.oid::regprocedure as signature, pg_get_functiondef(p.oid) as definition
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public'
  and p.proname in ('accept_student_guide_agreement', 'decline_student_guide_agreement');

-- 0e. Existing triggers and RLS policies on the applications table.
select tgname, pg_get_triggerdef(oid) as definition
from pg_trigger
where tgrelid = 'public.student_guide_applications'::regclass
  and not tgisinternal;

select policyname, cmd, roles, qual, with_check
from pg_policies
where schemaname = 'public' and tablename = 'student_guide_applications';

-- 0f. Distinct statuses currently stored. Part 1 stops with an error if any
--     value is not one of the four new statuses or one of the three old names.
select status, count(*) from public.student_guide_applications group by status order by 2 desc;

-- 0g. Older approval path. Check whether this function exists and what status it
--     writes. If it writes an old status it will fail against the new CHECK.
select p.oid::regprocedure as signature,
       pg_get_functiondef(p.oid) as definition,
       pg_get_userbyid(p.proowner) as owner,
       p.prosecdef as security_definer,
       p.proacl as acl
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public'
  and p.proname = 'admin_update_guide_application';

-- 0h. Who can execute the older approval path.
select p.oid::regprocedure as signature,
       r.rolname as role,
       has_function_privilege(r.oid, p.oid, 'execute') as can_execute
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
cross join (select oid, rolname from pg_roles where rolname in ('anon', 'authenticated')) r
where n.nspname = 'public'
  and p.proname = 'admin_update_guide_application';


-- =============================================================================
-- PART 1. Schema, status migration, functions and trigger
-- =============================================================================

-- 1a. Decision and agreement columns (additive only).
alter table public.student_guide_applications
  add column if not exists decided_by uuid references auth.users (id),
  add column if not exists decided_by_email text,
  add column if not exists decided_at timestamptz,
  add column if not exists decision_reason text,
  add column if not exists agreement_version text,
  add column if not exists agreement_accepted_at timestamptz;

-- 1b. Role assignments. Written only by SECURITY DEFINER code; there are
--     deliberately no insert/update/delete policies.
create table if not exists public.user_roles (
  user_id uuid not null references auth.users (id) on delete cascade,
  role text not null,
  granted_by uuid references auth.users (id),
  granted_at timestamptz not null default now(),
  primary key (user_id, role)
);

alter table public.user_roles enable row level security;

revoke all on public.user_roles from anon, authenticated;
grant select on public.user_roles to authenticated;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'user_roles'
      and policyname = 'Users can read their own roles'
  ) then
    create policy "Users can read their own roles"
      on public.user_roles for select to authenticated
      using (user_id = auth.uid());
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'user_roles'
      and policyname = 'Admins can read all roles'
  ) then
    create policy "Admins can read all roles"
      on public.user_roles for select to authenticated
      using (public.is_admin());
  end if;
end
$$;

-- 1c. Status migration. Order matters:
--       1. drop the role trigger, so renaming 'Active Student Guide' rows cannot
--          make the old trigger revoke their student_guide role
--       2. drop the old status CHECK
--       3. map old names to new names
--       4. refuse to continue if any other status value exists
--       5. add the new CHECK
--       6. make sure every Active Guide row has the student_guide role
drop trigger if exists student_guide_applications_sync_role on public.student_guide_applications;

do $$
declare
  v_constraint record;
begin
  for v_constraint in
    select c.conname
    from pg_constraint c
    join pg_attribute a
      on a.attrelid = c.conrelid and a.attname = 'status' and not a.attisdropped
    where c.conrelid = 'public.student_guide_applications'::regclass
      and c.contype = 'c'
      and c.conkey = array[a.attnum]
  loop
    execute format('alter table public.student_guide_applications drop constraint %I', v_constraint.conname);
  end loop;
end
$$;

update public.student_guide_applications
set status = 'Pending'
where lower(btrim(status)) = 'pending review';

update public.student_guide_applications
set status = 'Agreement Required'
where lower(btrim(status)) like 'approved%agreement required';

update public.student_guide_applications
set status = 'Active Guide'
where lower(btrim(status)) = 'active student guide';

do $$
declare
  v_unexpected text;
begin
  select string_agg(distinct coalesce(status, '<null>'), ', ')
  into v_unexpected
  from public.student_guide_applications
  where status is null
     or status not in ('Pending', 'Agreement Required', 'Active Guide', 'Rejected');

  if v_unexpected is not null then
    raise exception 'Unexpected status values in student_guide_applications: %. Map them yourself, then re-run.', v_unexpected
      using errcode = '23514';
  end if;
end
$$;

alter table public.student_guide_applications
  drop constraint if exists student_guide_applications_status_check;

alter table public.student_guide_applications
  add constraint student_guide_applications_status_check
  check (status in ('Pending', 'Agreement Required', 'Active Guide', 'Rejected'));

insert into public.user_roles (user_id, role, granted_by)
select a.student_id, 'student_guide', a.decided_by
from public.student_guide_applications a
where a.status = 'Active Guide'
  and a.student_id is not null
on conflict (user_id, role) do nothing;

-- 1d. Admin decision function. Approve sets 'Agreement Required', Reject sets
--     'Rejected' and requires a reason. Both notify the student and write an
--     audit event.
create or replace function public.admin_decide_guide_application(
  p_application_id uuid,
  p_decision text,
  p_reason text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_admin_id uuid := auth.uid();
  v_admin_email text;
  v_application public.student_guide_applications%rowtype;
  v_decision text := lower(btrim(coalesce(p_decision, '')));
  v_reason text := nullif(btrim(coalesce(p_reason, '')), '');
  v_new_status text;
  v_now timestamptz := now();
begin
  if v_admin_id is null then
    raise exception 'Authentication required' using errcode = '28000';
  end if;

  if not coalesce(public.is_admin(), false) then
    raise exception 'Administrator access required' using errcode = '42501';
  end if;

  if v_decision not in ('approved', 'rejected') then
    raise exception 'Decision must be approved or rejected' using errcode = '22023';
  end if;

  if v_decision = 'rejected' and v_reason is null then
    raise exception 'A reason is required when rejecting an application' using errcode = '22023';
  end if;

  select * into v_application
  from public.student_guide_applications
  where id = p_application_id
  for update;

  if not found then
    raise exception 'Application not found' using errcode = 'P0002';
  end if;

  if lower(btrim(v_application.status)) <> 'pending' then
    raise exception 'This application has already been decided' using errcode = '55000';
  end if;

  if v_application.student_id is null then
    raise exception 'Application has no linked student account' using errcode = '23502';
  end if;

  v_new_status := case v_decision
    when 'approved' then 'Agreement Required'
    else 'Rejected'
  end;

  select email into v_admin_email from auth.users where id = v_admin_id;

  update public.student_guide_applications
  set status = v_new_status,
      decided_by = v_admin_id,
      decided_by_email = v_admin_email,
      decided_at = v_now,
      decision_reason = case when v_decision = 'rejected' then v_reason else null end,
      updated_at = v_now
  where id = p_application_id;

  insert into public.notifications (user_id, title, body, kind)
  values (
    v_application.student_id,
    case when v_decision = 'approved'
      then 'Student Guide application approved'
      else 'Student Guide application not approved'
    end,
    case when v_decision = 'approved'
      then 'Your Student Guide application was approved. Open the Student Guide tab in your account and accept the Student Guide Agreement to activate your role.'
      else 'Your Student Guide application was not approved. Reason: ' || v_reason
    end,
    'guide_application'
  );

  insert into public.audit_events (actor_id, action, entity_type, entity_id, metadata)
  values (
    v_admin_id,
    'guide_application.' || v_decision,
    'student_guide_application',
    p_application_id,
    jsonb_build_object(
      'student_id', v_application.student_id,
      'previous_status', v_application.status,
      'new_status', v_new_status,
      'reason', case when v_decision = 'rejected' then v_reason else null end
    )
  );

  return jsonb_build_object(
    'id', p_application_id,
    'status', v_new_status,
    'decided_at', v_now,
    'decided_by_email', v_admin_email
  );
end;
$$;

revoke all on function public.admin_decide_guide_application(uuid, text, text) from public;
revoke all on function public.admin_decide_guide_application(uuid, text, text) from anon;
grant execute on function public.admin_decide_guide_application(uuid, text, text) to authenticated;

-- 1e. Student agreement functions. The old versions compare against the old
--     status names, so every function with these names is dropped and recreated.
--     The app calls them as:
--       accept_student_guide_agreement(application_id, version)
--       decline_student_guide_agreement(application_id)
--     and uses the returned row as the application.
do $$
declare
  v_function record;
begin
  for v_function in
    select p.oid::regprocedure as signature
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname in ('accept_student_guide_agreement', 'decline_student_guide_agreement')
  loop
    execute format('drop function %s', v_function.signature);
  end loop;
end
$$;

create function public.accept_student_guide_agreement(
  application_id uuid,
  version text
)
returns public.student_guide_applications
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_version text := nullif(btrim(coalesce(version, '')), '');
  v_application public.student_guide_applications%rowtype;
  v_now timestamptz := now();
begin
  if v_user_id is null then
    raise exception 'Authentication required' using errcode = '28000';
  end if;

  if v_version is null then
    raise exception 'Agreement version is required' using errcode = '22023';
  end if;

  select * into v_application
  from public.student_guide_applications a
  where a.id = application_id
    and a.student_id = v_user_id
  for update;

  if not found then
    raise exception 'Application not found' using errcode = 'P0002';
  end if;

  if lower(btrim(v_application.status)) <> 'agreement required' then
    raise exception 'This application is not waiting for an agreement' using errcode = '55000';
  end if;

  update public.student_guide_applications a
  set status = 'Active Guide',
      agreement_version = v_version,
      agreement_accepted_at = v_now,
      updated_at = v_now
  where a.id = v_application.id
  returning * into v_application;

  insert into public.audit_events (actor_id, action, entity_type, entity_id, metadata)
  values (
    v_user_id,
    'guide_application.agreement_accepted',
    'student_guide_application',
    v_application.id,
    jsonb_build_object(
      'student_id', v_user_id,
      'previous_status', 'Agreement Required',
      'new_status', 'Active Guide',
      'agreement_version', v_version
    )
  );

  return v_application;
end;
$$;

create function public.decline_student_guide_agreement(
  application_id uuid
)
returns public.student_guide_applications
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_application public.student_guide_applications%rowtype;
  v_now timestamptz := now();
begin
  if v_user_id is null then
    raise exception 'Authentication required' using errcode = '28000';
  end if;

  select * into v_application
  from public.student_guide_applications a
  where a.id = application_id
    and a.student_id = v_user_id
  for update;

  if not found then
    raise exception 'Application not found' using errcode = 'P0002';
  end if;

  if lower(btrim(v_application.status)) <> 'agreement required' then
    raise exception 'This application is not waiting for an agreement' using errcode = '55000';
  end if;

  update public.student_guide_applications a
  set status = 'Rejected',
      decided_by = null,
      decided_by_email = null,
      decided_at = v_now,
      decision_reason = 'The applicant declined the Student Guide agreement.',
      updated_at = v_now
  where a.id = v_application.id
  returning * into v_application;

  insert into public.audit_events (actor_id, action, entity_type, entity_id, metadata)
  values (
    v_user_id,
    'guide_application.agreement_declined',
    'student_guide_application',
    v_application.id,
    jsonb_build_object(
      'student_id', v_user_id,
      'previous_status', 'Agreement Required',
      'new_status', 'Rejected'
    )
  );

  return v_application;
end;
$$;

revoke all on function public.accept_student_guide_agreement(uuid, text) from public;
revoke all on function public.accept_student_guide_agreement(uuid, text) from anon;
grant execute on function public.accept_student_guide_agreement(uuid, text) to authenticated;

revoke all on function public.decline_student_guide_agreement(uuid) from public;
revoke all on function public.decline_student_guide_agreement(uuid) from anon;
grant execute on function public.decline_student_guide_agreement(uuid) to authenticated;

-- 1f. Role sync. Grants 'student_guide' only when a row moves from
--     'Agreement Required' to 'Active Guide', and revokes it if the row later
--     leaves 'Active Guide'. It fires on UPDATE only, so a row cannot jump from
--     'Pending' to active or be inserted as active and pick up the role.
create or replace function public.sync_student_guide_role()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.student_id is null then
    return new;
  end if;

  if lower(btrim(new.status)) = 'active guide'
     and lower(btrim(old.status)) = 'agreement required' then
    insert into public.user_roles (user_id, role, granted_by)
    values (new.student_id, 'student_guide', new.decided_by)
    on conflict (user_id, role) do nothing;
  elsif lower(btrim(old.status)) = 'active guide'
        and lower(btrim(new.status)) is distinct from lower(btrim(old.status)) then
    delete from public.user_roles
    where user_id = new.student_id and role = 'student_guide';
  end if;

  return new;
end;
$$;

revoke all on function public.sync_student_guide_role() from public;
revoke all on function public.sync_student_guide_role() from anon;
revoke all on function public.sync_student_guide_role() from authenticated;

drop trigger if exists student_guide_applications_sync_role on public.student_guide_applications;
create trigger student_guide_applications_sync_role
  after update of status on public.student_guide_applications
  for each row
  execute function public.sync_student_guide_role();


-- =============================================================================
-- PART 2. DUPLICATE PENDING CLEANUP  (the only part of this file that deletes)
--
-- Keeps the latest pending application per student and deletes older pending
-- duplicates. It only touches public.student_guide_applications and only rows
-- whose status is 'Pending'. Decided applications are never touched.
-- Run it after Part 1, which renames 'Pending Review' rows to 'Pending'.
-- =============================================================================

-- 2a. PREVIEW. Run this select alone first. Rows with keep_row = false are the
--     ones the delete below would remove. Nothing is changed by this select.
select
  id,
  student_id,
  full_name,
  email,
  status,
  created_at,
  (rn = 1) as keep_row
from (
  select
    a.*,
    row_number() over (
      partition by a.student_id
      order by a.created_at desc, a.id desc
    ) as rn,
    count(*) over (partition by a.student_id) as pending_count
  from public.student_guide_applications a
  where lower(btrim(a.status)) = 'pending'
) ranked
where pending_count > 1
order by student_id, created_at desc;

-- 2b. DELETE. Only run after you have reviewed the preview above.
--     RETURNING shows exactly which rows were removed.
with ranked as (
  select
    id,
    row_number() over (
      partition by student_id
      order by created_at desc, id desc
    ) as rn
  from public.student_guide_applications
  where lower(btrim(status)) = 'pending'
)
delete from public.student_guide_applications
where id in (select id from ranked where rn > 1)
returning id, student_id, full_name, email, status, created_at;


-- =============================================================================
-- PART 3. One pending application per student
-- Replaces the old index, which matched 'pending review'. Fails with a
-- duplicate-key error if Part 2 has not removed the duplicates.
-- =============================================================================
drop index if exists public.student_guide_applications_one_pending_per_student;

create unique index if not exists student_guide_applications_one_pending_per_student
  on public.student_guide_applications (student_id)
  where lower(btrim(status)) = 'pending';
