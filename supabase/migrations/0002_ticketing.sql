-- 0002 - ticketing: one bookable ticket per person per event, with capacity
-- limits, an automatic waitlist, a scannable code and gate check-in.
--
-- Run after 0001_event_details.sql. Idempotent: safe to re-run.
--
-- Design note: public.tickets has a SELECT policy and nothing else. Every
-- write goes through the SECURITY DEFINER functions further down, because
-- capacity has to be evaluated under a row lock - a client able to INSERT
-- directly could oversell an event simply by racing another client.

-- 1. Ticket codes ----------------------------------------------------------------
-- Short enough to read out at a gate, random enough not to be guessable in
-- bulk. The UNIQUE constraint on tickets.code is the real guarantee.
create or replace function public.new_ticket_code()
returns text
language sql
volatile
as $fn$
  select 'HIT-' || upper(substr(h, 1, 4)) || '-' || upper(substr(h, 5, 4))
  from (select replace(gen_random_uuid()::text, '-', '') as h) s;
$fn$;

-- 2. Tickets ---------------------------------------------------------------------
create table if not exists public.tickets (
  id            uuid primary key default gen_random_uuid(),
  event_id      uuid not null references public.events (id) on delete cascade,
  user_id       uuid not null references public.profiles (id) on delete cascade,
  code          text not null unique default public.new_ticket_code(),
  status        text not null default 'confirmed'
                  check (status in ('confirmed', 'waitlisted', 'cancelled', 'checked_in')),
  booked_at     timestamptz not null default now(),
  cancelled_at  timestamptz,
  checked_in_at timestamptz,
  checked_in_by uuid references public.profiles (id),
  unique (event_id, user_id)
);

create index if not exists tickets_event_status_idx on public.tickets (event_id, status);
create index if not exists tickets_user_idx on public.tickets (user_id);

alter table public.tickets enable row level security;

-- Readable by the ticket holder, and by admins for the attendee roster.
drop policy if exists "tickets_select_own_or_admin" on public.tickets;
create policy "tickets_select_own_or_admin"
  on public.tickets for select
  to authenticated
  using (auth.uid() = user_id or public.is_admin());

-- Deliberately no INSERT / UPDATE / DELETE policy. See the design note above.

-- 3. Live counters ---------------------------------------------------------------
-- Attendees need to see "42 of 100 seats taken" but must not be able to read
-- other people's ticket rows, and RLS is row-level rather than column-level.
-- So the aggregate lives in its own table that everybody may read, kept in
-- sync by a trigger and published over realtime.
create table if not exists public.event_ticket_stats (
  event_id    uuid primary key references public.events (id) on delete cascade,
  seats_taken integer not null default 0,
  waitlisted  integer not null default 0,
  checked_in  integer not null default 0,
  updated_at  timestamptz not null default now()
);

alter table public.event_ticket_stats enable row level security;

drop policy if exists "event_ticket_stats_select_all" on public.event_ticket_stats;
create policy "event_ticket_stats_select_all"
  on public.event_ticket_stats for select to authenticated using (true);

-- Written only by the definer function below, never by a client.
create or replace function public.refresh_event_ticket_stats(p_event_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $fn$
begin
  insert into public.event_ticket_stats as s
    (event_id, seats_taken, waitlisted, checked_in, updated_at)
  select
    p_event_id,
    count(*) filter (where t.status in ('confirmed', 'checked_in')),
    count(*) filter (where t.status = 'waitlisted'),
    count(*) filter (where t.status = 'checked_in'),
    now()
  from public.tickets t
  where t.event_id = p_event_id
  on conflict (event_id) do update
    set seats_taken = excluded.seats_taken,
        waitlisted  = excluded.waitlisted,
        checked_in  = excluded.checked_in,
        updated_at  = excluded.updated_at;
end;
$fn$;

create or replace function public.tickets_stats_trigger()
returns trigger
language plpgsql
security definer
set search_path = public
as $fn$
begin
  if tg_op = 'DELETE' then
    perform public.refresh_event_ticket_stats(old.event_id);
    return old;
  end if;
  perform public.refresh_event_ticket_stats(new.event_id);
  if tg_op = 'UPDATE' and old.event_id is distinct from new.event_id then
    perform public.refresh_event_ticket_stats(old.event_id);
  end if;
  return new;
end;
$fn$;

drop trigger if exists tickets_refresh_stats on public.tickets;
create trigger tickets_refresh_stats
  after insert or update or delete on public.tickets
  for each row execute function public.tickets_stats_trigger();

-- Give every new event a zeroed stats row so the client never has to cope
-- with a missing one.
create or replace function public.events_init_ticket_stats()
returns trigger
language plpgsql
security definer
set search_path = public
as $fn$
begin
  insert into public.event_ticket_stats (event_id) values (new.id)
  on conflict (event_id) do nothing;
  return new;
end;
$fn$;

drop trigger if exists events_init_ticket_stats on public.events;
create trigger events_init_ticket_stats
  after insert on public.events
  for each row execute function public.events_init_ticket_stats();

-- 4. Booking ---------------------------------------------------------------------
-- Confirms a seat if one is free, otherwise adds the caller to the waitlist.
-- The FOR UPDATE on the event row is what makes concurrent bookings safe.
create or replace function public.book_ticket(p_event_id uuid)
returns public.tickets
language plpgsql
security definer
set search_path = public
as $fn$
declare
  v_user      uuid := auth.uid();
  v_capacity  integer;
  v_published boolean;
  v_end       timestamptz;
  v_taken     integer;
  v_status    text;
  v_ticket    public.tickets;
begin
  if v_user is null then
    raise exception 'You need to be signed in to book a ticket.' using errcode = '42501';
  end if;

  select e.capacity, e.is_published, e.end_date
    into v_capacity, v_published, v_end
  from public.events e
  where e.id = p_event_id
  for update;

  if not found then
    raise exception 'That event no longer exists.' using errcode = 'P0002';
  end if;
  if not v_published then
    raise exception 'That event is not open for booking yet.' using errcode = '42501';
  end if;
  if v_end < now() then
    raise exception 'That event has already finished.' using errcode = '22023';
  end if;

  select count(*) into v_taken
  from public.tickets
  where event_id = p_event_id and status in ('confirmed', 'checked_in');

  v_status := case
    when v_capacity is null or v_taken < v_capacity then 'confirmed'
    else 'waitlisted'
  end;

  -- Re-booking after a cancellation reuses the row, and therefore the code,
  -- rather than tripping the one-ticket-per-person constraint.
  insert into public.tickets as t (event_id, user_id, status)
  values (p_event_id, v_user, v_status)
  on conflict (event_id, user_id) do update
    set status       = case when t.status = 'cancelled' then excluded.status else t.status end,
        booked_at    = case when t.status = 'cancelled' then now() else t.booked_at end,
        cancelled_at = null
  returning * into v_ticket;

  return v_ticket;
end;
$fn$;

-- 5. Cancelling ------------------------------------------------------------------
-- Releases the seat and, if that leaves room, promotes whoever has been
-- waiting longest. A ticket already scanned at the gate cannot be cancelled.
create or replace function public.cancel_ticket(p_event_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $fn$
declare
  v_user     uuid := auth.uid();
  v_capacity integer;
  v_taken    integer;
begin
  if v_user is null then
    raise exception 'You need to be signed in to cancel a ticket.' using errcode = '42501';
  end if;

  select e.capacity into v_capacity
  from public.events e where e.id = p_event_id
  for update;

  if not found then
    raise exception 'That event no longer exists.' using errcode = 'P0002';
  end if;

  update public.tickets
     set status = 'cancelled', cancelled_at = now()
   where event_id = p_event_id
     and user_id = v_user
     and status in ('confirmed', 'waitlisted');

  if not found then
    return;
  end if;

  if v_capacity is not null then
    select count(*) into v_taken
    from public.tickets
    where event_id = p_event_id and status in ('confirmed', 'checked_in');

    if v_taken < v_capacity then
      update public.tickets
         set status = 'confirmed'
       where id = (
         select id from public.tickets
          where event_id = p_event_id and status = 'waitlisted'
          order by booked_at asc
          limit 1
       );
    end if;
  end if;
end;
$fn$;

-- 6. Gate check-in ---------------------------------------------------------------
-- Returns a verdict rather than raising, so the scanner UI can show a red
-- "already used" card instead of a generic error.
create or replace function public.check_in_ticket(p_code text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $fn$
declare
  v_ticket     public.tickets;
  v_event_name text;
  v_event_date timestamptz;
  v_attendee   text;
  v_verdict    text;
begin
  if not public.is_admin() then
    raise exception 'Only an admin can check tickets in.' using errcode = '42501';
  end if;

  select * into v_ticket
  from public.tickets
  where code = upper(btrim(p_code))
  for update;

  if not found then
    return jsonb_build_object('verdict', 'not_found', 'code', upper(btrim(p_code)));
  end if;

  v_verdict := case v_ticket.status
    when 'checked_in' then 'already_checked_in'
    when 'cancelled'  then 'cancelled'
    when 'waitlisted' then 'waitlisted'
    else 'ok'
  end;

  if v_verdict = 'ok' then
    update public.tickets
       set status = 'checked_in', checked_in_at = now(), checked_in_by = auth.uid()
     where id = v_ticket.id
    returning * into v_ticket;
  end if;

  select e.name, e.event_date into v_event_name, v_event_date
  from public.events e where e.id = v_ticket.event_id;

  select p.full_name into v_attendee
  from public.profiles p where p.id = v_ticket.user_id;

  return jsonb_build_object(
    'verdict',       v_verdict,
    'code',          v_ticket.code,
    'status',        v_ticket.status,
    'event_id',      v_ticket.event_id,
    'event_name',    v_event_name,
    'event_date',    v_event_date,
    'attendee_name', v_attendee,
    'checked_in_at', v_ticket.checked_in_at
  );
end;
$fn$;

-- Undo a mis-scan.
create or replace function public.revert_check_in(p_code text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $fn$
declare
  v_ticket public.tickets;
begin
  if not public.is_admin() then
    raise exception 'Only an admin can undo a check-in.' using errcode = '42501';
  end if;

  update public.tickets
     set status = 'confirmed', checked_in_at = null, checked_in_by = null
   where code = upper(btrim(p_code)) and status = 'checked_in'
  returning * into v_ticket;

  if not found then
    return jsonb_build_object('verdict', 'not_found');
  end if;
  return jsonb_build_object('verdict', 'reverted', 'code', v_ticket.code);
end;
$fn$;

-- 7. Grants ----------------------------------------------------------------------
revoke all on function public.book_ticket(uuid)                from public;
revoke all on function public.cancel_ticket(uuid)              from public;
revoke all on function public.check_in_ticket(text)            from public;
revoke all on function public.revert_check_in(text)            from public;
revoke all on function public.refresh_event_ticket_stats(uuid) from public;

grant execute on function public.book_ticket(uuid)     to authenticated;
grant execute on function public.cancel_ticket(uuid)   to authenticated;
grant execute on function public.check_in_ticket(text) to authenticated;
grant execute on function public.revert_check_in(text) to authenticated;

-- 8. Carry the old RSVPs over ----------------------------------------------------
-- Every rsvps row becomes a confirmed ticket, keeping its original timestamp.
-- The source table is left in place (see the comment below) so nothing is lost
-- if this needs unpicking. Note that a historical import can push an event
-- past a capacity set later on - that is intentional, existing attendees are
-- not retroactively waitlisted.
insert into public.tickets (event_id, user_id, status, booked_at)
select r.event_id, r.user_id, 'confirmed', r.created_at
from public.rsvps r
on conflict (event_id, user_id) do nothing;

comment on table public.rsvps is
  'DEPRECATED by migration 0002. Rows were copied into public.tickets and the '
  'app no longer reads or writes this table. Kept as a backup; safe to drop '
  'once you are happy with the ticket data.';

-- 9. Backfill stats for events that already existed ------------------------------
insert into public.event_ticket_stats (event_id)
select e.id from public.events e
on conflict (event_id) do nothing;

do $blk$
declare
  r record;
begin
  for r in select id from public.events loop
    perform public.refresh_event_ticket_stats(r.id);
  end loop;
end $blk$;

-- 10. Realtime -------------------------------------------------------------------
do $blk$
declare
  t text;
begin
  foreach t in array array['tickets', 'event_ticket_stats']
  loop
    if not exists (
      select 1 from pg_publication_tables
      where pubname = 'supabase_realtime'
        and schemaname = 'public'
        and tablename = t
    ) then
      execute format('alter publication supabase_realtime add table public.%I', t);
    end if;
  end loop;
end $blk$;
