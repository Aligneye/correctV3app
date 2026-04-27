-- Aligneye — sessions table + RLS policy
-- Run in the Supabase SQL editor (or via psql) once per environment.
--
-- Every row is owned by the authenticated user. The BLE sync pipeline on
-- the device never deletes local records until the ACK handshake completes,
-- so duplicate inserts are possible in failure cases; consumers should be
-- idempotent on (user_id, start_ts, type).
--
-- posture_events: jsonb array of {s,c} pairs, where `s` is the seconds-from-
--   session-start at which a slouch began and `c` is the seconds at which it
--   was corrected. `c == 65535` means the slouch was still active when the
--   session ended.
-- therapy_patterns: jsonb array of integer pattern indices played (in order).

create table sessions (
  id               uuid primary key default gen_random_uuid(),
  user_id          uuid references auth.users not null,
  type             text not null check (type in ('posture','therapy')),
  start_ts         timestamptz,
  duration_sec     integer not null,
  wrong_count      integer,
  wrong_dur_sec    integer,
  therapy_pattern  integer,
  ts_synced        boolean default false,
  posture_events   jsonb,
  therapy_patterns jsonb,
  created_at       timestamptz default now()
);

create index on sessions (user_id, created_at desc);
create index on sessions (user_id, start_ts desc);

alter table sessions enable row level security;

create policy "own sessions" on sessions
  for all using (auth.uid() = user_id);
