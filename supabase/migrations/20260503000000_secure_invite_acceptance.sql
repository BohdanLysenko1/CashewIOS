-- Secure invite acceptance and remove direct client-side share grants.

create schema if not exists private;

grant usage on schema private to authenticated;

create or replace function private.is_trip_collaborator(p_trip_id uuid)
returns boolean
language sql
security definer
stable
set search_path = public, auth, pg_temp
as $$
    select exists (
        select 1
        from public.trip_shares ts
        where ts.trip_id = p_trip_id
          and ts.user_id = (select auth.uid())
          and ts.accepted_at is not null
    );
$$;

create or replace function private.is_event_collaborator(p_event_id uuid)
returns boolean
language sql
security definer
stable
set search_path = public, auth, pg_temp
as $$
    select exists (
        select 1
        from public.event_shares es
        where es.event_id = p_event_id
          and es.user_id = (select auth.uid())
          and es.accepted_at is not null
    );
$$;

create or replace function private.get_trip_owner_id(p_trip_id uuid)
returns uuid
language sql
security definer
stable
set search_path = public, auth, pg_temp
as $$
    select owner_id from public.trips where id = p_trip_id;
$$;

create or replace function private.get_event_owner_id(p_event_id uuid)
returns uuid
language sql
security definer
stable
set search_path = public, auth, pg_temp
as $$
    select owner_id from public.events where id = p_event_id;
$$;

grant execute on function private.is_trip_collaborator(uuid) to authenticated;
grant execute on function private.is_event_collaborator(uuid) to authenticated;
grant execute on function private.get_trip_owner_id(uuid) to authenticated;
grant execute on function private.get_event_owner_id(uuid) to authenticated;

-- Align app payloads with the live events table.
alter table public.events
    add column if not exists recurrence_rule jsonb;

-- Ensure invite acceptance can be idempotent.
delete from public.trip_shares a
using public.trip_shares b
where a.ctid < b.ctid
  and a.trip_id = b.trip_id
  and a.user_id = b.user_id;

delete from public.event_shares a
using public.event_shares b
where a.ctid < b.ctid
  and a.event_id = b.event_id
  and a.user_id = b.user_id;

do $$
begin
    if not exists (
        select 1
        from pg_index i
        join pg_class t on t.oid = i.indrelid
        join pg_namespace n on n.oid = t.relnamespace
        where n.nspname = 'public'
          and t.relname = 'trip_shares'
          and i.indisunique
          and (
              select array_agg(a.attname order by x.ordinality)
              from unnest(i.indkey) with ordinality as x(attnum, ordinality)
              join pg_attribute a on a.attrelid = t.oid and a.attnum = x.attnum
          ) = array['trip_id', 'user_id']
    ) then
        create unique index idx_trip_shares_unique_member
            on public.trip_shares(trip_id, user_id);
    end if;
end $$;

do $$
begin
    if not exists (
        select 1
        from pg_index i
        join pg_class t on t.oid = i.indrelid
        join pg_namespace n on n.oid = t.relnamespace
        where n.nspname = 'public'
          and t.relname = 'event_shares'
          and i.indisunique
          and (
              select array_agg(a.attname order by x.ordinality)
              from unnest(i.indkey) with ordinality as x(attnum, ordinality)
              join pg_attribute a on a.attrelid = t.oid and a.attnum = x.attnum
          ) = array['event_id', 'user_id']
    ) then
        create unique index idx_event_shares_unique_member
            on public.event_shares(event_id, user_id);
    end if;
end $$;

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
    or private.is_trip_collaborator(id)
);

create policy "trips: member update"
on public.trips
as permissive
for update
to authenticated
using (
    owner_id = (select auth.uid())
    or private.is_trip_collaborator(id)
)
with check (
    owner_id = private.get_trip_owner_id(trips.id)
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
    or private.is_event_collaborator(id)
);

create policy "events: member update"
on public.events
as permissive
for update
to authenticated
using (
    owner_id = (select auth.uid())
    or private.is_event_collaborator(id)
)
with check (
    owner_id = private.get_event_owner_id(events.id)
);

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
        from public.trips t
        where t.id = trip_activity_log.trip_id
          and (
              t.owner_id = (select auth.uid())
              or private.is_trip_collaborator(t.id)
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
        from public.trips t
        where t.id = trip_activity_log.trip_id
          and (
              t.owner_id = (select auth.uid())
              or private.is_trip_collaborator(t.id)
          )
    )
);

-- trip_shares: no direct client insert/update. Invite acceptance happens via RPC.
do $$
declare
    p record;
begin
    for p in
        select policyname
        from pg_policies
        where schemaname = 'public' and tablename = 'trip_shares'
    loop
        execute format('drop policy if exists %I on public.trip_shares', p.policyname);
    end loop;
end $$;

create policy "trip_shares: select"
on public.trip_shares
as permissive
for select
to authenticated
using (
    user_id = (select auth.uid())
    or invited_by = (select auth.uid())
    or private.is_trip_collaborator(trip_id)
    or exists (
        select 1
        from public.trips t
        where t.id = trip_shares.trip_id
          and t.owner_id = (select auth.uid())
    )
);

create policy "trip_shares: delete"
on public.trip_shares
as permissive
for delete
to authenticated
using (
    user_id = (select auth.uid())
    or exists (
        select 1
        from public.trips t
        where t.id = trip_shares.trip_id
          and t.owner_id = (select auth.uid())
    )
);

-- event_shares: no direct client insert/update. Invite acceptance happens via RPC.
do $$
declare
    p record;
begin
    for p in
        select policyname
        from pg_policies
        where schemaname = 'public' and tablename = 'event_shares'
    loop
        execute format('drop policy if exists %I on public.event_shares', p.policyname);
    end loop;
end $$;

create policy "event_shares: select"
on public.event_shares
as permissive
for select
to authenticated
using (
    user_id = (select auth.uid())
    or invited_by = (select auth.uid())
    or private.is_event_collaborator(event_id)
    or exists (
        select 1
        from public.events e
        where e.id = event_shares.event_id
          and e.owner_id = (select auth.uid())
    )
);

create policy "event_shares: delete"
on public.event_shares
as permissive
for delete
to authenticated
using (
    user_id = (select auth.uid())
    or exists (
        select 1
        from public.events e
        where e.id = event_shares.event_id
          and e.owner_id = (select auth.uid())
    )
);

-- invite_links: only creators can directly inspect/manage rows.
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

create policy "invite_links: creator select"
on public.invite_links
as permissive
for select
to authenticated
using (created_by = (select auth.uid()));

create policy "invite_links: creator insert"
on public.invite_links
as permissive
for insert
to authenticated
with check (
    created_by = (select auth.uid())
    and (
        (
            resource_type = 'trip'
            and exists (
                select 1
                from public.trips t
                where t.id = resource_id
                  and (
                      t.owner_id = (select auth.uid())
                      or private.is_trip_collaborator(t.id)
                  )
            )
        )
        or (
            resource_type = 'event'
            and exists (
                select 1
                from public.events e
                where e.id = resource_id
                  and (
                      e.owner_id = (select auth.uid())
                      or private.is_event_collaborator(e.id)
                  )
            )
        )
    )
);

create policy "invite_links: creator update"
on public.invite_links
as permissive
for update
to authenticated
using (created_by = (select auth.uid()))
with check (
    created_by = (select auth.uid())
    and (
        (
            resource_type = 'trip'
            and exists (
                select 1
                from public.trips t
                where t.id = resource_id
                  and (
                      t.owner_id = (select auth.uid())
                      or private.is_trip_collaborator(t.id)
                  )
            )
        )
        or (
            resource_type = 'event'
            and exists (
                select 1
                from public.events e
                where e.id = resource_id
                  and (
                      e.owner_id = (select auth.uid())
                      or private.is_event_collaborator(e.id)
                  )
            )
        )
    )
);

create policy "invite_links: creator delete"
on public.invite_links
as permissive
for delete
to authenticated
using (created_by = (select auth.uid()));

-- users select policy with private RLS helpers.
drop policy if exists "users: select" on public.users;

create policy "users: select"
on public.users
as permissive
for select
to authenticated
using (
    id = (select auth.uid())
    or exists (
        select 1
        from public.event_shares es
        where es.user_id = users.id
          and es.accepted_at is not null
          and (
              private.is_event_collaborator(es.event_id)
              or exists (
                  select 1
                  from public.events e
                  where e.id = es.event_id
                    and e.owner_id = (select auth.uid())
              )
          )
    )
    or exists (
        select 1
        from public.events e
        where e.owner_id = users.id
          and private.is_event_collaborator(e.id)
    )
    or exists (
        select 1
        from public.trip_shares ts
        where ts.user_id = users.id
          and ts.accepted_at is not null
          and (
              private.is_trip_collaborator(ts.trip_id)
              or exists (
                  select 1
                  from public.trips t
                  where t.id = ts.trip_id
                    and t.owner_id = (select auth.uid())
              )
          )
    )
    or exists (
        select 1
        from public.trips t
        where t.owner_id = users.id
          and private.is_trip_collaborator(t.id)
    )
);

create or replace function public.preview_share_invite(p_token text)
returns table (
    resource_type text,
    resource_id uuid,
    created_by uuid,
    created_by_name text,
    title text,
    expires_at timestamptz
)
language plpgsql
security definer
stable
set search_path = public, private, auth, pg_temp
as $$
declare
    v_invite record;
    v_creator_name text;
    v_title text;
    v_creator_can_share boolean;
begin
    if (select auth.uid()) is null then
        raise exception 'Not authenticated' using errcode = '28000';
    end if;

    select *
    into v_invite
    from public.invite_links il
    where il.token = p_token;

    if not found then
        raise exception 'Invalid invite token' using errcode = 'P0002';
    end if;

    if v_invite.expires_at is not null and v_invite.expires_at < now() then
        raise exception 'Invite link expired' using errcode = '22023';
    end if;

    select coalesce(nullif(u.display_name, ''), u.email, 'A collaborator')
    into v_creator_name
    from public.users u
    where u.id = v_invite.created_by;

    if v_invite.resource_type = 'trip' then
        select t.name,
               (
                   t.owner_id = v_invite.created_by
                   or exists (
                       select 1
                       from public.trip_shares ts
                       where ts.trip_id = t.id
                         and ts.user_id = v_invite.created_by
                         and ts.accepted_at is not null
                   )
               )
        into v_title, v_creator_can_share
        from public.trips t
        where t.id = v_invite.resource_id;
    elsif v_invite.resource_type = 'event' then
        select e.title,
               (
                   e.owner_id = v_invite.created_by
                   or exists (
                       select 1
                       from public.event_shares es
                       where es.event_id = e.id
                         and es.user_id = v_invite.created_by
                         and es.accepted_at is not null
                   )
               )
        into v_title, v_creator_can_share
        from public.events e
        where e.id = v_invite.resource_id;
    else
        raise exception 'Unknown invite resource type' using errcode = '22023';
    end if;

    if coalesce(v_creator_can_share, false) = false then
        raise exception 'Invalid invite token' using errcode = 'P0002';
    end if;

    return query select
        v_invite.resource_type,
        v_invite.resource_id,
        v_invite.created_by,
        coalesce(v_creator_name, 'A collaborator'),
        coalesce(v_title, 'Shared item'),
        v_invite.expires_at;
end;
$$;

create or replace function public.accept_share_invite(p_token text)
returns table (
    resource_type text,
    resource_id uuid
)
language plpgsql
security definer
set search_path = public, private, auth, pg_temp
as $$
declare
    v_preview record;
    v_user_id uuid := (select auth.uid());
    v_owner_id uuid;
begin
    if v_user_id is null then
        raise exception 'Not authenticated' using errcode = '28000';
    end if;

    select *
    into v_preview
    from public.preview_share_invite(p_token);

    if v_preview.resource_type = 'trip' then
        select owner_id into v_owner_id from public.trips where id = v_preview.resource_id;
        if v_owner_id is distinct from v_user_id then
            insert into public.trip_shares (trip_id, user_id, invited_by, accepted_at)
            values (v_preview.resource_id, v_user_id, v_preview.created_by, now())
            on conflict (trip_id, user_id)
            do update set
                invited_by = excluded.invited_by,
                accepted_at = excluded.accepted_at;
        end if;
    elsif v_preview.resource_type = 'event' then
        select owner_id into v_owner_id from public.events where id = v_preview.resource_id;
        if v_owner_id is distinct from v_user_id then
            insert into public.event_shares (event_id, user_id, invited_by, accepted_at)
            values (v_preview.resource_id, v_user_id, v_preview.created_by, now())
            on conflict (event_id, user_id)
            do update set
                invited_by = excluded.invited_by,
                accepted_at = excluded.accepted_at;
        end if;
    else
        raise exception 'Unknown invite resource type' using errcode = '22023';
    end if;

    return query select v_preview.resource_type, v_preview.resource_id;
end;
$$;

revoke all on function public.preview_share_invite(text) from public;
revoke all on function public.preview_share_invite(text) from anon;
grant execute on function public.preview_share_invite(text) to authenticated;

revoke all on function public.accept_share_invite(text) from public;
revoke all on function public.accept_share_invite(text) from anon;
grant execute on function public.accept_share_invite(text) to authenticated;

revoke all on function public.delete_user_account() from public;
revoke all on function public.delete_user_account() from anon;
grant execute on function public.delete_user_account() to authenticated;

do $$
begin
    if to_regprocedure('public.handle_new_user()') is not null then
        revoke all on function public.handle_new_user() from public;
        revoke all on function public.handle_new_user() from anon;
        revoke all on function public.handle_new_user() from authenticated;
    end if;
    if to_regprocedure('public.rls_auto_enable()') is not null then
        revoke all on function public.rls_auto_enable() from public;
        revoke all on function public.rls_auto_enable() from anon;
        revoke all on function public.rls_auto_enable() from authenticated;
    end if;
end $$;

drop function if exists public.is_trip_collaborator(uuid);
drop function if exists public.is_event_collaborator(uuid);
drop function if exists public.get_trip_owner_id(uuid);
drop function if exists public.get_event_owner_id(uuid);
