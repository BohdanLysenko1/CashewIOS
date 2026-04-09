-- Fix infinite recursion in trips/events member-update RLS policies.
-- The WITH CHECK clauses were querying the same table, causing PostgreSQL
-- to detect a recursive policy cycle even at INSERT (upsert) planning time.
-- This aborted all upserts (including brand-new inserts), making trips/events
-- disappear immediately after creation.
-- Solution: fetch current owner via SECURITY DEFINER helper functions
-- (same pattern as is_trip_collaborator / is_event_collaborator).

-- Helper: return current owner_id for a trip, bypassing RLS
create or replace function public.get_trip_owner_id(p_trip_id uuid)
returns uuid
language sql
security definer
stable
set search_path = public, auth, pg_temp
as $$
    select owner_id from public.trips where id = p_trip_id;
$$;

-- Helper: return current owner_id for an event, bypassing RLS
create or replace function public.get_event_owner_id(p_event_id uuid)
returns uuid
language sql
security definer
stable
set search_path = public, auth, pg_temp
as $$
    select owner_id from public.events where id = p_event_id;
$$;

-- Fix trips: member update (replace self-referencing subquery with helper)
drop policy if exists "trips: member update" on public.trips;
create policy "trips: member update"
on public.trips
as permissive
for update
to authenticated
using (
    owner_id = (select auth.uid())
    or public.is_trip_collaborator(id)
)
with check (
    owner_id = public.get_trip_owner_id(trips.id)
);

-- Fix events: member update (replace self-referencing subquery with helper)
drop policy if exists "events: member update" on public.events;
create policy "events: member update"
on public.events
as permissive
for update
to authenticated
using (
    owner_id = (select auth.uid())
    or public.is_event_collaborator(id)
)
with check (
    owner_id = public.get_event_owner_id(events.id)
);
