-- Security and performance hardening:
-- 1) Pin function search_path for security-definer and trigger functions.
-- 2) Add covering indexes for frequently filtered foreign keys.

alter function public.handle_new_user()
    set search_path = public, auth, pg_temp;

alter function public.is_trip_collaborator(uuid)
    set search_path = public, auth, pg_temp;

alter function public.is_event_collaborator(uuid)
    set search_path = public, auth, pg_temp;

alter function public.touch_updated_at()
    set search_path = public, pg_temp;

alter function public.update_daily_tasks_updated_at()
    set search_path = public, pg_temp;

alter function public.update_daily_routines_updated_at()
    set search_path = public, pg_temp;

create index if not exists idx_trips_owner_id
    on public.trips(owner_id);

create index if not exists idx_events_owner_id
    on public.events(owner_id);

create index if not exists idx_events_trip_id
    on public.events(trip_id);

create index if not exists idx_trip_shares_user_id
    on public.trip_shares(user_id);

create index if not exists idx_trip_shares_invited_by
    on public.trip_shares(invited_by);

create index if not exists idx_event_shares_user_id
    on public.event_shares(user_id);

create index if not exists idx_event_shares_invited_by
    on public.event_shares(invited_by);

create index if not exists idx_invite_links_created_by
    on public.invite_links(created_by);

create index if not exists idx_trip_activity_log_user_id
    on public.trip_activity_log(user_id);
