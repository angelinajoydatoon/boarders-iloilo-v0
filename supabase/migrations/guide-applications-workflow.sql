-- =============================================================================
-- Guide applications workflow
-- Run this yourself in the Supabase SQL Editor. Nothing in the app runs it.
--
-- Run it in this order, as separate runs:
--   Step 0  read-only checks (review the output first)
--   Part 1  additive schema + function + policies   (safe, re-runnable)
--   Part 2  duplicate pending cleanup               (preview first, then delete)
--   Part 3  one-pending-per-student unique index    (fails if Part 2 was skipped)
--
-- Assumptions (verified against the app code and the live API where possible):
--   * student_guide_applications.student_id links an application to auth.users
--   * pending applications use status 'Pending Review' (written by the student form)
--   * public.is_admin() already exists (the admin portal calls it)
--   * audit_events(actor_id, action, entity_type, entity_id, metadata) exists
--   * notifications(user_id, title, body, kind) exists
--   * there is no general roles table, only admin_roles. Granting the guide role
--     there could make a student an admin if is_admin() checks that table, so
--     Part 1 adds a separate public.user_roles table instead.
--
-- Status lifecycle (the strings the student panel and the existing
-- accept_student_guide_agreement / decline_student_guide_agreement RPCs use):
--   'Pending Review'                -> written by the student form
--   'Approved — Agreement Required' -> written by admin approval (em dash, U+2014).
--                                      The student panel shows the agreement
--                                      prompt for exactly this string.
--   'Active Student Guide'          -> written by the existing accept RPC
--   'Rejected'                      -> written by admin rejection
-- The student_guide role is NOT granted on approval. It is granted by a trigger
-- when the existing accept RPC moves the row from 'Approved — Agreement Required'
-- to 'Active Student Guide', so guide access begins only after acceptance.
-- This file never modifies the existing accept/decline functions, admin_roles
-- or is_admin().
-- =============================================================================


-- =============================================================================
-- STEP 0 (read-only). Run these selects first and check the results.
-- =============================================================================

-- 0a. Existing CHECK constraints on the table. If 'status' is restricted to a
--     fixed list, make sure it allows 'Approved' and 'Rejected'.
select conname, pg_get_constraintdef(oid) as definition
from pg_constraint
where conrelid = 'public.student_guide_applications'::regclass
  and contype = 'c';

-- 0b. Existing column types for the tables the function writes to.
select table_name, column_name, data_type
from information_schema.columns
where table_schema = 'public'
  and table_name in ('student_guide_applications', 'audit_events', 'notifications')
order by table_name, ordinal_position;

-- 0c. Existing definition of public.is_admin(), to confirm it does not depend on
--     anything the new function cannot satisfy.
select pg_get_functiondef('public.is_admin()'::regprocedure);

-- 0d. Definitions of the existing agreement functions. Confirm that:
--       * accept checks status = 'Approved — Agreement Required' and writes
--         'Active Student Guide'
--       * decline accepts 'Approved — Agreement Required' and writes a status of
--         your choice (the trigger below revokes the role if it ever leaves
--         'Active Student Guide')
--       * neither inserts into admin_roles
--     Both are matched by name, so this works whatever their argument types are.
select p.oid::regprocedure as signature, pg_get_functiondef(p.oid) as definition
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public'
  and p.proname in ('accept_student_guide_agreement', 'decline_student_guide_agreement');

-- 0e. Existing triggers and RLS policies on the applications table. Check that
--     students cannot update their own row's status directly; the role trigger
--     below trusts status transitions on this table.
select tgname, pg_get_triggerdef(oid) as definition
from pg_trigger
where tgrelid = 'public.student_guide_applications'::regclass
  and not tgisinternal;

select policyname, cmd, roles, qual, with_check
from pg_policies
where schemaname = 'public' and tablename = 'student_guide_applications';

-- 0f. Distinct statuses currently stored, so the lifecycle strings above match
--     real data exactly (watch for a hyphen instead of the em dash).
select status, count(*) from public.student_guide_applications group by status order by 2 desc;


-- =============================================================================
-- PART 1. Additive schema, role table, policies and decision function
-- =============================================================================

-- 1a. Decision columns on student_guide_applications (additive only).
alter table public.student_guide_applications
  add column if not exists decided_by uuid references auth.users (id),
  add column if not exists decided_by_email text,
  add column if not exists decided_at timestamptz,
  add column if not exists decision_reason text;

-- 1b. Role assignments. Written only by the SECURITY DEFINER function below;
--     there are deliberately no insert/update/delete policies.
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

-- 1c. Decision function.
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

  if lower(btrim(v_application.status)) <> 'pending review' then
    raise exception 'This application has already been decided' using errcode = '55000';
  end if;

  if v_application.student_id is null then
    raise exception 'Application has no linked student account' using errcode = '23502';
  end if;

  -- Approval hands off to the existing agreement flow: the student panel shows
  -- the agreement prompt only for this exact string (note the em dash).
  v_new_status := case v_decision
    when 'approved' then 'Approved — Agreement Required'
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

-- 1d. Role sync. Grants 'student_guide' only when a row moves from
--     'Approved — Agreement Required' to 'Active Student Guide' (what the existing
--     accept RPC does), and revokes it if the row later leaves that status.
--     It fires on UPDATE only and requires the previous status to be the
--     agreement step, so a row cannot jump from 'Pending Review' to active or be
--     inserted as active and pick up the role. It never touches admin_roles.
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

  if new.status = 'Active Student Guide'
     and old.status = 'Approved — Agreement Required' then
    insert into public.user_roles (user_id, role, granted_by)
    values (new.student_id, 'student_guide', new.decided_by)
    on conflict (user_id, role) do nothing;
  elsif old.status = 'Active Student Guide'
        and new.status is distinct from old.status then
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
-- whose status is 'Pending Review'. Decided applications are never touched.
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
  where lower(btrim(a.status)) = 'pending review'
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
  where lower(btrim(status)) = 'pending review'
)
delete from public.student_guide_applications
where id in (select id from ranked where rn > 1)
returning id, student_id, full_name, email, status, created_at;


-- =============================================================================
-- PART 3. One pending application per student
-- Fails with a duplicate-key error if Part 2 has not removed the duplicates.
-- =============================================================================
create unique index if not exists student_guide_applications_one_pending_per_student
  on public.student_guide_applications (student_id)
  where lower(btrim(status)) = 'pending review';
