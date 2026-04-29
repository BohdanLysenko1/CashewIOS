-- Capture the full set of inputs the user provided to the AI itinerary
-- generator so we can later personalize / debug. Existing rows pre-date
-- this change and have NULLs for the new columns.

alter table public.itinerary_generations
  add column if not exists interests text[],
  add column if not exists user_note text,
  add column if not exists vibe text,
  add column if not exists pace text,
  add column if not exists target_date date,
  add column if not exists budget_allocation numeric;
