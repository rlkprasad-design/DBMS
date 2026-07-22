-- DBMS Quest schema. Tables are prefixed `dbms_` because this project is
-- shared with other apps (BA Quest, and the original VOM game) - keeps
-- everything independent, no collisions.
-- Run this once in the Supabase SQL editor (Project > SQL Editor > New query).

create table if not exists dbms_scores (
  player_name text primary key,
  bronze_count integer not null default 0,
  silver_count integer not null default 0,
  gold_count integer not null default 0,
  total_marks integer not null default 0,
  updated_at timestamptz not null default now()
);

create table if not exists dbms_flagged_terms (
  id bigint generated always as identity primary key,
  word text not null,
  meaning text,
  difficulty text,
  source_mode text,
  flagged_by text,
  created_at timestamptz not null default now()
);

alter table dbms_scores enable row level security;
alter table dbms_flagged_terms enable row level security;

-- No login, so every visitor uses the anon (publishable) key. Anyone can
-- read the scoreboard and flagged-terms panel; anyone can write their own
-- score row or submit a flag. This matches the "no accounts, trusted
-- display name" identity model described in the brief - there is no
-- server-side way to verify identity, so RLS here is intentionally open
-- rather than pretending otherwise.
create policy "Anyone can read scores" on dbms_scores
  for select using (true);
create policy "Anyone can upsert their own score row" on dbms_scores
  for insert with check (true);
create policy "Anyone can update score rows" on dbms_scores
  for update using (true);

create policy "Anyone can read flagged terms" on dbms_flagged_terms
  for select using (true);
create policy "Anyone can submit a flag" on dbms_flagged_terms
  for insert with check (true);
