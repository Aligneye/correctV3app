-- Aligneye — sessions table + RLS policy
-- Run in the Supabase SQL editor (or via psql) once per environment.
--
-- Every row is owned by the authenticated user. The BLE sync pipeline on
-- the device never deletes local records until the ACK handshake completes,
-- so duplicate inserts are possible in failure cases; consumers should be
-- idempotent on (user_id, start_ts, type).

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
  created_at       timestamptz default now()
);

create index on sessions (user_id, created_at desc);

alter table sessions enable row level security;

create policy "own sessions" on sessions
  for all using (auth.uid() = user_id);
