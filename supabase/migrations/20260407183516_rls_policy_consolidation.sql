-- Consolidates overlapping RLS policies and uses initplan-friendly auth checks.

-- users
drop policy if exists "Users can read own profile" on public.users;
drop policy if exists "Users can insert own profile" on public.users;
drop policy if exists "Users can update own profile" on public.users;

create policy "Users can read own profile"
on public.users
as permissive
for select
to authenticated
using ((select auth.uid()) = id);

create policy "Users can insert own profile"
on public.users
as permissive
for insert
to authenticated
with check ((select auth.uid()) = id);

create policy "Users can update own profile"
on public.users
as permissive
for update
to authenticated
using ((select auth.uid()) = id)
with check ((select auth.uid()) = id);

-- daily_tasks
drop policy if exists "Users can view own daily tasks" on public.daily_tasks;
drop policy if exists "Users can insert own daily tasks" on public.daily_tasks;
drop policy if exists "Users can update own daily tasks" on public.daily_tasks;
drop policy if exists "Users can delete own daily tasks" on public.daily_tasks;

create policy "Users can view own daily tasks"
on public.daily_tasks
as permissive
for select
to authenticated
using ((select auth.uid()) = owner_id);

create policy "Users can insert own daily tasks"
on public.daily_tasks
as permissive
for insert
to authenticated
with check ((select auth.uid()) = owner_id);

create policy "Users can update own daily tasks"
on public.daily_tasks
as permissive
for update
to authenticated
using ((select auth.uid()) = owner_id)
with check ((select auth.uid()) = owner_id);

create policy "Users can delete own daily tasks"
on public.daily_tasks
as permissive
for delete
to authenticated
using ((select auth.uid()) = owner_id);

-- daily_routines
drop policy if exists "Users can view own daily routines" on public.daily_routines;
drop policy if exists "Users can insert own daily routines" on public.daily_routines;
drop policy if exists "Users can update own daily routines" on public.daily_routines;
drop policy if exists "Users can delete own daily routines" on public.daily_routines;

create policy "Users can view own daily routines"
on public.daily_routines
as permissive
for select
to authenticated
using ((select auth.uid()) = owner_id);

create policy "Users can insert own daily routines"
on public.daily_routines
as permissive
for insert
to authenticated
with check ((select auth.uid()) = owner_id);

create policy "Users can update own daily routines"
on public.daily_routines
as permissive
for update
to authenticated
using ((select auth.uid()) = owner_id)
with check ((select auth.uid()) = owner_id);

create policy "Users can delete own daily routines"
on public.daily_routines
as permissive
for delete
to authenticated
using ((select auth.uid()) = owner_id);

-- trips
drop policy if exists "Owners have full access to trips" on public.trips;
drop policy if exists "Users can insert their own trips" on public.trips;
drop policy if exists "Collaborators can view shared trips" on public.trips;
drop policy if exists "Collaborators can edit shared trips" on public.trips;
drop policy if exists "trips: collaborator read" on public.trips;
drop policy if exists "trips: collaborator update" on public.trips;
drop policy if exists "trips: owner full access" on public.trips;

create policy "trips: owner full access"
on public.trips
as permissive
for all
to authenticated
using (owner_id = (select auth.uid()))
with check (owner_id = (select auth.uid()));

create policy "trips: collaborator read"
on public.trips
as permissive
for select
to authenticated
using (public.is_trip_collaborator(id));

create policy "trips: collaborator update"
on public.trips
as permissive
for update
to authenticated
using (public.is_trip_collaborator(id))
with check (
    owner_id = (
        select t.owner_id
        from public.trips t
        where t.id = trips.id
    )
);

-- events
drop policy if exists "Owners have full access to events" on public.events;
drop policy if exists "Users can insert their own events" on public.events;
drop policy if exists "Collaborators can view shared events" on public.events;
drop policy if exists "Collaborators can edit shared events" on public.events;
drop policy if exists "events: collaborator read" on public.events;
drop policy if exists "events: collaborator update" on public.events;
drop policy if exists "events: owner full access" on public.events;

create policy "events: owner full access"
on public.events
as permissive
for all
to authenticated
using (owner_id = (select auth.uid()))
with check (owner_id = (select auth.uid()));

create policy "events: collaborator read"
on public.events
as permissive
for select
to authenticated
using (public.is_event_collaborator(id));

create policy "events: collaborator update"
on public.events
as permissive
for update
to authenticated
using (public.is_event_collaborator(id))
with check (
    owner_id = (
        select e.owner_id
        from public.events e
        where e.id = events.id
    )
);

-- trip_shares
drop policy if exists "trip_shares: invitee reads and accepts" on public.trip_shares;
drop policy if exists "trip_shares: owner manages" on public.trip_shares;
drop policy if exists "trip_shares: member manages" on public.trip_shares;

create policy "trip_shares: member manages"
on public.trip_shares
as permissive
for all
to authenticated
using (
    user_id = (select auth.uid())
    or exists (
        select 1
        from public.trips
        where trips.id = trip_shares.trip_id
          and trips.owner_id = (select auth.uid())
    )
)
with check (
    user_id = (select auth.uid())
    or exists (
        select 1
        from public.trips
        where trips.id = trip_shares.trip_id
          and trips.owner_id = (select auth.uid())
    )
);

-- event_shares
drop policy if exists "event_shares: invitee reads and accepts" on public.event_shares;
drop policy if exists "event_shares: owner manages" on public.event_shares;
drop policy if exists "event_shares: member manages" on public.event_shares;

create policy "event_shares: member manages"
on public.event_shares
as permissive
for all
to authenticated
using (
    user_id = (select auth.uid())
    or exists (
        select 1
        from public.events
        where events.id = event_shares.event_id
          and events.owner_id = (select auth.uid())
    )
)
with check (
    user_id = (select auth.uid())
    or exists (
        select 1
        from public.events
        where events.id = event_shares.event_id
          and events.owner_id = (select auth.uid())
    )
);

-- invite_links
drop policy if exists "invite_links: creator manages" on public.invite_links;
drop policy if exists "invite_links: token lookup" on public.invite_links;

create policy "invite_links: creator manages"
on public.invite_links
as permissive
for all
to authenticated
using (created_by = (select auth.uid()))
with check (created_by = (select auth.uid()));

create policy "invite_links: token lookup"
on public.invite_links
as permissive
for select
to authenticated
using (true);
