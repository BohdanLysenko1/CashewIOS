-- Audit log for trip changes visible to trip members.

create table if not exists public.trip_activity_log (
    id uuid primary key default gen_random_uuid(),
    trip_id uuid not null references public.trips(id) on delete cascade,
    user_id uuid not null references public.users(id) on delete cascade,
    summary text not null,
    created_at timestamptz not null default now()
);

create index if not exists idx_trip_activity_log_trip_id
    on public.trip_activity_log(trip_id, created_at desc);

alter table public.trip_activity_log enable row level security;

drop policy if exists "Trip members can view activity log" on public.trip_activity_log;
create policy "Trip members can view activity log"
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
              trips.owner_id = auth.uid()
              or exists (
                  select 1
                  from public.trip_shares
                  where trip_shares.trip_id = trips.id
                    and trip_shares.user_id = auth.uid()
                    and trip_shares.accepted_at is not null
              )
          )
    )
);

drop policy if exists "Trip members can insert activity" on public.trip_activity_log;
create policy "Trip members can insert activity"
on public.trip_activity_log
as permissive
for insert
to authenticated
with check (
    user_id = auth.uid()
    and exists (
        select 1
        from public.trips
        where trips.id = trip_activity_log.trip_id
          and (
              trips.owner_id = auth.uid()
              or exists (
                  select 1
                  from public.trip_shares
                  where trip_shares.trip_id = trips.id
                    and trip_shares.user_id = auth.uid()
                    and trip_shares.accepted_at is not null
              )
          )
    )
);
