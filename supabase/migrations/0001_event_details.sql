-- 0001 - richer event data: venue, media gallery, agenda, tags, capacity and
-- a draft/published flag.
--
-- Run after supabase/schema.sql. Idempotent: safe to re-run.

-- 1. is_admin() ------------------------------------------------------------------
-- Row level security policies need to ask "is the caller an admin?", which means
-- reading public.profiles. A policy *on* profiles that queries profiles recurses
-- forever, so the check lives in a SECURITY DEFINER function instead: it runs as
-- the owner and therefore bypasses RLS. Every policy below calls this rather
-- than inlining the same EXISTS subquery.
create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.profiles
    where id = auth.uid() and role = 'admin'
  );
$$;

revoke all on function public.is_admin() from public;
grant execute on function public.is_admin() to authenticated, service_role;

-- Admins need to read other people's names for the attendee roster. Everyone
-- else still sees only their own row.
drop policy if exists "profiles_select_own" on public.profiles;
drop policy if exists "profiles_select_own_or_admin" on public.profiles;
create policy "profiles_select_own_or_admin"
  on public.profiles for select
  to authenticated
  using (auth.uid() = id or public.is_admin());

-- Let people correct their own display name. A policy WITH CHECK cannot see the
-- pre-update row, so identity and role are pinned by a BEFORE UPDATE trigger
-- instead - otherwise a user could simply set their own role to 'admin'.
drop policy if exists "profiles_update_own" on public.profiles;
create policy "profiles_update_own"
  on public.profiles for update
  to authenticated
  using (auth.uid() = id)
  with check (auth.uid() = id);

create or replace function public.protect_profile_identity()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  new.id := old.id;
  new.email := old.email;
  new.created_at := old.created_at;
  if new.role is distinct from old.role and not public.is_admin() then
    new.role := old.role;
  end if;
  return new;
end;
$$;

drop trigger if exists profiles_protect_identity on public.profiles;
create trigger profiles_protect_identity
  before update on public.profiles
  for each row execute function public.protect_profile_identity();

-- 2. New event columns -----------------------------------------------------------
alter table public.events
  add column if not exists venue_name      text,
  add column if not exists venue_address   text,
  add column if not exists latitude        double precision,
  add column if not exists longitude       double precision,
  add column if not exists organizer_name  text,
  add column if not exists organizer_phone text,
  add column if not exists organizer_email text,
  add column if not exists capacity        integer,
  add column if not exists tags            text[] not null default '{}',
  add column if not exists is_published    boolean not null default true,
  add column if not exists updated_at      timestamptz not null default now();

-- NULL capacity means "unlimited"; anything else has to be a real seat count.
alter table public.events drop constraint if exists events_capacity_positive;
alter table public.events
  add constraint events_capacity_positive
  check (capacity is null or capacity > 0);

alter table public.events drop constraint if exists events_latitude_range;
alter table public.events
  add constraint events_latitude_range
  check (latitude is null or latitude between -90 and 90);

alter table public.events drop constraint if exists events_longitude_range;
alter table public.events
  add constraint events_longitude_range
  check (longitude is null or longitude between -180 and 180);

create index if not exists events_tags_idx on public.events using gin (tags);
create index if not exists events_is_published_idx on public.events (is_published);

-- 3. Keep updated_at honest ------------------------------------------------------
create or replace function public.touch_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists events_touch_updated_at on public.events;
create trigger events_touch_updated_at
  before update on public.events
  for each row execute function public.touch_updated_at();

-- 4. Drafts are admin-only -------------------------------------------------------
-- Replaces schema.sql's blanket "any authenticated user can read any event".
drop policy if exists "events_select_all" on public.events;
drop policy if exists "events_select_published_or_admin" on public.events;
create policy "events_select_published_or_admin"
  on public.events for select
  to authenticated
  using (is_published or public.is_admin());

-- Same three write policies as schema.sql, rewritten to use is_admin().
drop policy if exists "events_insert_admin_only" on public.events;
create policy "events_insert_admin_only"
  on public.events for insert to authenticated with check (public.is_admin());

drop policy if exists "events_update_admin_only" on public.events;
create policy "events_update_admin_only"
  on public.events for update to authenticated using (public.is_admin());

drop policy if exists "events_delete_admin_only" on public.events;
create policy "events_delete_admin_only"
  on public.events for delete to authenticated using (public.is_admin());

-- 5. Extra cover images ----------------------------------------------------------
create table if not exists public.event_images (
  id         uuid primary key default gen_random_uuid(),
  event_id   uuid not null references public.events (id) on delete cascade,
  image_url  text not null,
  position   integer not null default 0,
  created_at timestamptz not null default now()
);

create index if not exists event_images_event_idx
  on public.event_images (event_id, position);

alter table public.event_images enable row level security;

drop policy if exists "event_images_select_all" on public.event_images;
create policy "event_images_select_all"
  on public.event_images for select to authenticated using (true);

drop policy if exists "event_images_write_admin" on public.event_images;
create policy "event_images_write_admin"
  on public.event_images for all to authenticated
  using (public.is_admin()) with check (public.is_admin());

-- 6. Agenda / schedule -----------------------------------------------------------
create table if not exists public.event_agenda (
  id         uuid primary key default gen_random_uuid(),
  event_id   uuid not null references public.events (id) on delete cascade,
  title      text not null,
  speaker    text,
  starts_at  timestamptz not null,
  ends_at    timestamptz,
  position   integer not null default 0,
  created_at timestamptz not null default now(),
  constraint agenda_end_after_start check (ends_at is null or ends_at >= starts_at)
);

create index if not exists event_agenda_event_idx
  on public.event_agenda (event_id, position, starts_at);

alter table public.event_agenda enable row level security;

drop policy if exists "event_agenda_select_all" on public.event_agenda;
create policy "event_agenda_select_all"
  on public.event_agenda for select to authenticated using (true);

drop policy if exists "event_agenda_write_admin" on public.event_agenda;
create policy "event_agenda_write_admin"
  on public.event_agenda for all to authenticated
  using (public.is_admin()) with check (public.is_admin());

-- 7. Realtime --------------------------------------------------------------------
-- The client subscribes with .stream(), which only receives changes for tables
-- inside the supabase_realtime publication.
do $$
declare
  t text;
begin
  foreach t in array array['event_images', 'event_agenda']
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
end $$;
