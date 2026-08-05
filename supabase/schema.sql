-- HIT Events schema.
-- Run this once in Supabase Dashboard -> SQL Editor -> New query -> Run.
-- Prerequisite: create the admin account first in Dashboard -> Authentication -> Users
-- -> Add user -> email: admin@hit.com, password: <your-own-password>, "Auto Confirm User": ON.
-- The trigger below detects that exact email and assigns the admin role automatically
-- when the row is inserted into auth.users. Every other signup (via the app's
-- Register screen) gets role = 'user'.

-- 1. Profiles table (one row per auth.users row, holds app-level role) -----------
create table if not exists public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  full_name text not null,
  email text not null,
  role text not null default 'user' check (role in ('user', 'admin')),
  created_at timestamptz not null default now()
);

alter table public.profiles enable row level security;

drop policy if exists "profiles_select_own" on public.profiles;
create policy "profiles_select_own"
  on public.profiles for select
  to authenticated
  using (auth.uid() = id);

-- 2. Auto-create a profile row whenever a new auth user is created --------------
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, full_name, email, role)
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'full_name', split_part(new.email, '@', 1)),
    new.email,
    case when new.email = 'admin@hit.com' then 'admin' else 'user' end
  );
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- Backfill: the trigger only fires for auth.users rows created AFTER it
-- exists. If you created admin@hit.com in the Dashboard before running this
-- script (as instructed above), it has no profile row yet without this.
-- Safe to re-run.
insert into public.profiles (id, full_name, email, role)
select
  u.id,
  coalesce(u.raw_user_meta_data ->> 'full_name', split_part(u.email, '@', 1)),
  u.email,
  case when u.email = 'admin@hit.com' then 'admin' else 'user' end
from auth.users u
left join public.profiles p on p.id = u.id
where p.id is null;

-- 3. Events table ----------------------------------------------------------------
create table if not exists public.events (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  description text not null,
  charges numeric(10, 2) not null default 0 check (charges >= 0),
  category text not null check (category in ('Family', 'Kids', 'Corporate', 'General', 'VIP')),
  image_url text,
  event_date timestamptz not null,
  end_date timestamptz not null,
  created_by uuid not null references public.profiles (id),
  created_at timestamptz not null default now(),
  constraint end_after_start check (end_date >= event_date)
);

create index if not exists events_event_date_idx on public.events (event_date);

-- The app subscribes to live changes on this table (.stream()), which
-- requires it to be in Supabase's realtime publication. Not on by default
-- for new tables. Safe to re-run.
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'events'
  ) then
    alter publication supabase_realtime add table public.events;
  end if;
end $$;

alter table public.events enable row level security;

drop policy if exists "events_select_all" on public.events;
create policy "events_select_all"
  on public.events for select
  to authenticated
  using (true);

drop policy if exists "events_insert_admin_only" on public.events;
create policy "events_insert_admin_only"
  on public.events for insert
  to authenticated
  with check (
    exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'admin')
  );

drop policy if exists "events_update_admin_only" on public.events;
create policy "events_update_admin_only"
  on public.events for update
  to authenticated
  using (
    exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'admin')
  );

drop policy if exists "events_delete_admin_only" on public.events;
create policy "events_delete_admin_only"
  on public.events for delete
  to authenticated
  using (
    exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'admin')
  );

-- 4. Storage bucket for event cover images ---------------------------------------
insert into storage.buckets (id, name, public)
values ('event-images', 'event-images', true)
on conflict (id) do nothing;

drop policy if exists "event_images_public_read" on storage.objects;
create policy "event_images_public_read"
  on storage.objects for select
  to public
  using (bucket_id = 'event-images');

drop policy if exists "event_images_admin_write" on storage.objects;
create policy "event_images_admin_write"
  on storage.objects for insert
  to authenticated
  with check (
    bucket_id = 'event-images'
    and exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'admin')
  );

drop policy if exists "event_images_admin_update" on storage.objects;
create policy "event_images_admin_update"
  on storage.objects for update
  to authenticated
  using (
    bucket_id = 'event-images'
    and exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'admin')
  );

drop policy if exists "event_images_admin_delete" on storage.objects;
create policy "event_images_admin_delete"
  on storage.objects for delete
  to authenticated
  using (
    bucket_id = 'event-images'
    and exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'admin')
  );

-- 5. RSVPs ("I'm Going") ----------------------------------------------------------
create table if not exists public.rsvps (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references public.events (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  unique (event_id, user_id)
);

create index if not exists rsvps_event_id_idx on public.rsvps (event_id);

do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'rsvps'
  ) then
    alter publication supabase_realtime add table public.rsvps;
  end if;
end $$;

alter table public.rsvps enable row level security;

-- Attendee counts are shown to every signed-in user, so reads are open to
-- any authenticated user (same as events); only user_id/event_id pairs are
-- exposed, not other users' profile data.
drop policy if exists "rsvps_select_all" on public.rsvps;
create policy "rsvps_select_all"
  on public.rsvps for select
  to authenticated
  using (true);

drop policy if exists "rsvps_insert_own" on public.rsvps;
create policy "rsvps_insert_own"
  on public.rsvps for insert
  to authenticated
  with check (auth.uid() = user_id);

drop policy if exists "rsvps_delete_own" on public.rsvps;
create policy "rsvps_delete_own"
  on public.rsvps for delete
  to authenticated
  using (auth.uid() = user_id);

-- 6. Favorites (bookmarks) ---------------------------------------------------------
create table if not exists public.favorites (
  event_id uuid not null references public.events (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (event_id, user_id)
);

alter table public.favorites enable row level security;

-- Private to each user - nobody else has a reason to read these.
drop policy if exists "favorites_select_own" on public.favorites;
create policy "favorites_select_own"
  on public.favorites for select
  to authenticated
  using (auth.uid() = user_id);

drop policy if exists "favorites_insert_own" on public.favorites;
create policy "favorites_insert_own"
  on public.favorites for insert
  to authenticated
  with check (auth.uid() = user_id);

drop policy if exists "favorites_delete_own" on public.favorites;
create policy "favorites_delete_own"
  on public.favorites for delete
  to authenticated
  using (auth.uid() = user_id);
