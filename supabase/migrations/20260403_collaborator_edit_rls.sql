-- Enables collaborators to view and edit shared trips/events.

create or replace function public.is_trip_collaborator(trip_id uuid)
returns boolean
language sql
security definer
set search_path = public, auth, pg_temp
as $$
    select exists (
        select 1
        from public.trip_shares
        where trip_shares.trip_id = $1
          and trip_shares.user_id = auth.uid()
          and trip_shares.accepted_at is not null
    );
$$;

create or replace function public.is_event_collaborator(event_id uuid)
returns boolean
language sql
security definer
set search_path = public, auth, pg_temp
as $$
    select exists (
        select 1
        from public.event_shares
        where event_shares.event_id = $1
          and event_shares.user_id = auth.uid()
          and event_shares.accepted_at is not null
    );
$$;

drop policy if exists "Owners have full access to trips" on public.trips;
drop policy if exists "Users can insert their own trips" on public.trips;
drop policy if exists "Collaborators can view shared trips" on public.trips;
drop policy if exists "Collaborators can edit shared trips" on public.trips;

create policy "Owners have full access to trips"
on public.trips
as permissive
for all
to authenticated
using (owner_id = auth.uid())
with check (owner_id = auth.uid());

create policy "Users can insert their own trips"
on public.trips
as permissive
for insert
to authenticated
with check (owner_id = auth.uid());

create policy "Collaborators can view shared trips"
on public.trips
as permissive
for select
to authenticated
using (
    exists (
        select 1
        from public.trip_shares
        where trip_shares.trip_id = trips.id
          and trip_shares.user_id = auth.uid()
          and trip_shares.accepted_at is not null
    )
);

create policy "Collaborators can edit shared trips"
on public.trips
as permissive
for update
to authenticated
using (
    exists (
        select 1
        from public.trip_shares
        where trip_shares.trip_id = trips.id
          and trip_shares.user_id = auth.uid()
          and trip_shares.accepted_at is not null
    )
)
with check (
    exists (
        select 1
        from public.trip_shares
        where trip_shares.trip_id = trips.id
          and trip_shares.user_id = auth.uid()
          and trip_shares.accepted_at is not null
    )
    and owner_id = (
        select t.owner_id
        from public.trips t
        where t.id = trips.id
    )
);

drop policy if exists "Owners have full access to events" on public.events;
drop policy if exists "Users can insert their own events" on public.events;
drop policy if exists "Collaborators can view shared events" on public.events;
drop policy if exists "Collaborators can edit shared events" on public.events;

create policy "Owners have full access to events"
on public.events
as permissive
for all
to authenticated
using (owner_id = auth.uid())
with check (owner_id = auth.uid());

create policy "Users can insert their own events"
on public.events
as permissive
for insert
to authenticated
with check (owner_id = auth.uid());

create policy "Collaborators can view shared events"
on public.events
as permissive
for select
to authenticated
using (
    exists (
        select 1
        from public.event_shares
        where event_shares.event_id = events.id
          and event_shares.user_id = auth.uid()
          and event_shares.accepted_at is not null
    )
);

create policy "Collaborators can edit shared events"
on public.events
as permissive
for update
to authenticated
using (
    exists (
        select 1
        from public.event_shares
        where event_shares.event_id = events.id
          and event_shares.user_id = auth.uid()
          and event_shares.accepted_at is not null
    )
)
with check (
    exists (
        select 1
        from public.event_shares
        where event_shares.event_id = events.id
          and event_shares.user_id = auth.uid()
          and event_shares.accepted_at is not null
    )
    and owner_id = (
        select e.owner_id
        from public.events e
        where e.id = events.id
    )
);
