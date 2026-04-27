-- Migration 002: surface firmware event timelines on the sessions table.
-- Adds two jsonb columns the BLE sync pipeline writes when the device
-- streams its extension packets after each session summary.
--
-- posture_events: array of {s,c} pairs. `s` = seconds-from-start the slouch
--   began, `c` = seconds-from-start it was corrected (or 65535 if still bad
--   when the session ended).
-- therapy_patterns: array of pattern indices played, in order.
--
-- Safe to run multiple times.

alter table sessions
  add column if not exists posture_events   jsonb,
  add column if not exists therapy_patterns jsonb;
create index if not exists sessions_user_start_idx
  on sessions (user_id, start_ts desc);

