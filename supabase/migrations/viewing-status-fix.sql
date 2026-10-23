-- Viewing request status fix. NOT RUN. Review before executing in the Supabase SQL Editor.
--
-- Canonical spelling: 'Pending', 'Approved', 'Rejected' (capitalised), matching what the
-- student panel compares against ('Approved') and what the admin UI writes locally.
-- The function below matches the incoming status case-insensitively, so existing rows
-- stored as 'pending' or 'Pending' can both be decided, and it always writes the
-- canonical capitalised value.
--
-- Run Step 0 first and compare against the current definition:
--   select pg_get_functiondef('public.admin_decide_viewing_request(uuid, text, text)'::regprocedure);
-- "create or replace" fails if the existing function has a different return type or
-- different parameter names. If it does, tell me and I will adjust before you run it.
--
-- Assumptions that were not verified against the live database:
--   * viewing_requests.id is uuid and the existing function signature is
--     (request_id uuid, decision text, note text), matching the app's rpc() call.
--   * viewing_requests has decided_at, decided_by, decided_by_email, cancellation_reason
--     (the admin loader already selects them).
--   * notifications.kind accepts 'viewing_request' and audit_events accepts the
--     columns used below.

create or replace function public.admin_decide_viewing_request(
  request_id uuid,
  decision text,
  note text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_admin uuid := auth.uid();
  v_email text;
  v_request public.viewing_requests%rowtype;
  v_decision text := lower(btrim(coalesce(decision, '')));
  v_status text;
  v_note text := nullif(btrim(coalesce(note, '')), '');
  v_now timestamptz := now();
begin
  if v_admin is null then
    raise exception 'Not authenticated' using errcode = '28000';
  end if;

  if not public.is_admin() then
    raise exception 'Not authorized' using errcode = '42501';
  end if;

  if v_decision not in ('approved', 'rejected') then
    raise exception 'Decision must be approved or rejected' using errcode = '22023';
  end if;
  v_status := case v_decision when 'approved' then 'Approved' else 'Rejected' end;

  select * into v_request
  from public.viewing_requests
  where id = request_id
  for update;

  if not found then
    raise exception 'Viewing request not found' using errcode = 'P0002';
  end if;

  if lower(btrim(v_request.status)) <> 'pending' then
    raise exception 'Viewing request has already been decided' using errcode = '23514';
  end if;

  select email into v_email from auth.users where id = v_admin;

  update public.viewing_requests
  set status = v_status,
      decided_at = v_now,
      decided_by = v_admin,
      decided_by_email = v_email,
      cancellation_reason = case when v_decision = 'rejected' then v_note else null end
  where id = request_id;

  insert into public.audit_events (actor_id, action, entity_type, entity_id, metadata)
  values (
    v_admin,
    'viewing_request_' || v_decision,
    'viewing_request',
    request_id,
    jsonb_build_object(
      'previous_status', v_request.status,
      'status', v_status,
      'reason', v_note
    )
  );

  if v_request.student_id is not null then
    insert into public.notifications (user_id, title, body, kind)
    values (
      v_request.student_id,
      case v_decision when 'approved' then 'Viewing request approved' else 'Viewing request rejected' end,
      case v_decision
        when 'approved' then 'Your viewing request for ' || v_request.preferred_date || ' at ' || v_request.preferred_time || ' was approved.'
        else 'Your viewing request for ' || v_request.preferred_date || ' at ' || v_request.preferred_time || ' was rejected.' || coalesce(' Reason: ' || v_note, '')
      end,
      'viewing_request'
    );
  end if;
end;
$$;

revoke all on function public.admin_decide_viewing_request(uuid, text, text) from public;
revoke all on function public.admin_decide_viewing_request(uuid, text, text) from anon;
grant execute on function public.admin_decide_viewing_request(uuid, text, text) to authenticated;
