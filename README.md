# HIT EVO

Event discovery and ticketing for Heavy Industries Taxila. Flutter client,
Supabase backend (Postgres + Auth + Storage + Realtime).

Two roles, one binary.

**Attendees** browse a curated Discover feed, search and filter, save events,
book a ticket, and carry a QR pass. Capacity is enforced, and a full event
puts the next person on a waitlist automatically.

**Admins** publish and edit events (venue, capacity, tags, gallery, running
order), scan passes at the gate, read the attendee roster, export it as CSV,
and see attendance and revenue figures.

## Requirements

| Tool     | Version            |
| -------- | ------------------ |
| Flutter  | 3.38 or newer      |
| Dart     | 3.10 or newer      |
| Supabase | any hosted project |

## Setup

### 1. Install dependencies

```bash
flutter pub get
```

### 2. Provision the database

Create the admin account first, in the Supabase dashboard:

**Authentication → Users → Add user**

- Email: `admin@hit.com`
- Password: your own
- Auto Confirm User: **on**

Then run these in **SQL Editor → New query**, in this order:

| File                                     | What it does                                       |
| ---------------------------------------- | -------------------------------------------------- |
| `supabase/schema.sql`                    | profiles, events, favourites, RLS, storage bucket   |
| `supabase/migrations/0001_event_details.sql` | venue, tags, capacity, gallery, agenda, drafts  |
| `supabase/migrations/0002_ticketing.sql` | tickets, waitlist, seat counters, gate check-in      |

Every script is idempotent, so re-running one is safe. The signup trigger
grants `admin` to `admin@hit.com` and `user` to everyone else.

Migration `0002` copies any existing `rsvps` rows into `tickets` and leaves
the old table in place, marked deprecated. Drop it yourself once you are
happy with the ticket data.

### 3. Point the app at your project

The project URL is in [lib/core/supabase_config.dart](lib/core/supabase_config.dart).
The publishable key is **not** committed — it is passed in at build time:

```bash
flutter run --dart-define=SUPABASE_PUBLISHABLE_KEY=your_key_here
```

Find it under **Project Settings → API**. Either the legacy `anon public` JWT
or the newer `publishable` key works.

For VS Code, copy the template and fill in your key:

```bash
cp .vscode/launch.json.example .vscode/launch.json
```

`.vscode/` is gitignored, so the key stays on your machine.

> The publishable key is safe to ship inside a compiled app — it only grants
> what the Row Level Security policies allow. It is kept out of the repo
> anyway, so that rotating it never means rewriting git history.

## Architecture

```
lib/
  core/        config, formatters, .ics and CSV builders, external launchers
  models/      immutable data classes + Postgres row mapping
  services/    one class per Supabase concern (auth, events, tickets, …)
  screens/
    auth/      sign in, register
    user/      attendee shell: discover, tickets, saved, profile
    admin/     admin shell: events, scanner, analytics, account
  theme/       colour, spacing and type tokens; ThemeData assembly
  widgets/     reusable presentation widgets
supabase/
  schema.sql   initial schema
  migrations/  incremental, ordered, idempotent changes
```

A few rules the code follows throughout:

- **Services take a `SupabaseClient` and are provided, not threaded.** Reads
  return broadcast `Stream`s so screens rebuild the moment a row changes;
  writes return `Future`s. Nothing in `widgets/` talks to Supabase directly.
- **Styling lives in `theme/`.** Screens contain layout. Every gap comes from
  the 4pt scale in `app_dimens.dart`, every colour from the scheme.
- **Money and dates are formatted in one place**, `core/formatters.dart`, so
  the same event never renders two different ways on two screens.

### Why ticket writes go through the database

`public.tickets` has a `SELECT` policy and nothing else. Booking, cancelling
and check-in are `SECURITY DEFINER` functions, because capacity has to be
evaluated under a row lock — a client that could `INSERT` directly would be
able to oversell an event simply by racing another client. Cancelling a seat
promotes whoever has been waiting longest, in the same transaction.

Seat counts are mirrored into `event_ticket_stats` by trigger. Attendees need
to see how full an event is, but must not be able to read other people's
ticket rows, and RLS is row-level rather than column-level — so the aggregate
lives in its own table that everyone may read.

## Build

```bash
flutter analyze
flutter build apk --release --dart-define=SUPABASE_PUBLISHABLE_KEY=your_key_here
```

Release builds are currently signed with the debug keystore. Generate a real
one and add `android/key.properties` (already gitignored) before shipping,
and change `applicationId` off `com.example.hit_app` in
[android/app/build.gradle.kts](android/app/build.gradle.kts).

The gate scanner needs camera access; the permission and the maps, tel and
mailto intent queries are declared in the Android manifest and iOS
`Info.plist`.
