-- Private storage bucket for trip photos and collaborator-aware access policies.

insert into storage.buckets (id, name, public)
values ('trip-photos', 'trip-photos', false)
on conflict (id) do nothing;

drop policy if exists "Trip members can view photos" on storage.objects;
create policy "Trip members can view photos"
on storage.objects
as permissive
for select
to authenticated
using (
    bucket_id = 'trip-photos'
    and exists (
        select 1
        from public.trips
        where trips.id::text = split_part(storage.objects.name, '/', 1)
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

drop policy if exists "Trip members can upload photos" on storage.objects;
create policy "Trip members can upload photos"
on storage.objects
as permissive
for insert
to authenticated
with check (
    bucket_id = 'trip-photos'
    and exists (
        select 1
        from public.trips
        where trips.id::text = split_part(storage.objects.name, '/', 1)
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

drop policy if exists "Trip members can delete photos" on storage.objects;
create policy "Trip members can delete photos"
on storage.objects
as permissive
for delete
to authenticated
using (
    bucket_id = 'trip-photos'
    and exists (
        select 1
        from public.trips
        where trips.id::text = split_part(storage.objects.name, '/', 1)
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
