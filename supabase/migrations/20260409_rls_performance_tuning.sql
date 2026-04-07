-- RLS performance tuning:
-- 1) Eliminate remaining auth_rls_initplan warnings by wrapping auth.uid().
-- 2) Remove multiple permissive policy overlaps for trips/events/invite_links.

-- device_push_tokens
do $$
declare
    p record;
begin
    for p in
        select policyname
        from pg_policies
        where schemaname = 'public' and tablename = 'device_push_tokens'
    loop
        execute format('drop policy if exists %I on public.device_push_tokens', p.policyname);
    end loop;
end $$;

create policy "device_push_tokens: owner manages"
on public.device_push_tokens
as permissive
for all
to authenticated
using (user_id = (select auth.uid()))
with check (user_id = (select auth.uid()));

-- trip_activity_log
do $$
declare
    p record;
begin
    for p in
        select policyname
        from pg_policies
        where schemaname = 'public' and tablename = 'trip_activity_log'
    loop
        execute format('drop policy if exists %I on public.trip_activity_log', p.policyname);
    end loop;
end $$;

create policy "trip_activity_log: members can view"
on public.trip_activity_log
as permissive
for select
to authenticated
using (
    exists (
        select 1
        from public.trips
        where trips.id = trip_activity_log.trip_id
          and (
              trips.owner_id = (select auth.uid())
              or public.is_trip_collaborator(trips.id)
          )
    )
);

create policy "trip_activity_log: members can insert"
on public.trip_activity_log
as permissive
for insert
to authenticated
with check (
    user_id = (select auth.uid())
    and exists (
        select 1
        from public.trips
        where trips.id = trip_activity_log.trip_id
          and (
              trips.owner_id = (select auth.uid())
              or public.is_trip_collaborator(trips.id)
          )
    )
);

-- trips
do $$
declare
    p record;
begin
    for p in
        select policyname
        from pg_policies
        where schemaname = 'public' and tablename = 'trips'
    loop
        execute format('drop policy if exists %I on public.trips', p.policyname);
    end loop;
end $$;

create policy "trips: owner insert"
on public.trips
as permissive
for insert
to authenticated
with check (owner_id = (select auth.uid()));

create policy "trips: owner delete"
on public.trips
as permissive
for delete
to authenticated
using (owner_id = (select auth.uid()));

create policy "trips: member read"
on public.trips
as permissive
for select
to authenticated
using (
    owner_id = (select auth.uid())
    or public.is_trip_collaborator(id)
);

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
    owner_id = (
        select t.owner_id
        from public.trips t
        where t.id = trips.id
    )
);

-- events
do $$
declare
    p record;
begin
    for p in
        select policyname
        from pg_policies
        where schemaname = 'public' and tablename = 'events'
    loop
        execute format('drop policy if exists %I on public.events', p.policyname);
    end loop;
end $$;

create policy "events: owner insert"
on public.events
as permissive
for insert
to authenticated
with check (owner_id = (select auth.uid()));

create policy "events: owner delete"
on public.events
as permissive
for delete
to authenticated
using (owner_id = (select auth.uid()));

create policy "events: member read"
on public.events
as permissive
for select
to authenticated
using (
    owner_id = (select auth.uid())
    or public.is_event_collaborator(id)
);

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
    owner_id = (
        select e.owner_id
        from public.events e
        where e.id = events.id
    )
);

-- invite_links
do $$
declare
    p record;
begin
    for p in
        select policyname
        from pg_policies
        where schemaname = 'public' and tablename = 'invite_links'
    loop
        execute format('drop policy if exists %I on public.invite_links', p.policyname);
    end loop;
end $$;

create policy "invite_links: token lookup"
on public.invite_links
as permissive
for select
to authenticated
using (true);

create policy "invite_links: creator insert"
on public.invite_links
as permissive
for insert
to authenticated
with check (created_by = (select auth.uid()));

create policy "invite_links: creator update"
on public.invite_links
as permissive
for update
to authenticated
using (created_by = (select auth.uid()))
with check (created_by = (select auth.uid()));

create policy "invite_links: creator delete"
on public.invite_links
as permissive
for delete
to authenticated
using (created_by = (select auth.uid()));
