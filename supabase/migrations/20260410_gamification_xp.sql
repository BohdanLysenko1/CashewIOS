-- Persist gamification XP in the users profile so progress syncs across devices.

alter table public.users
    add column if not exists total_xp integer not null default 0,
    add column if not exists xp_updated_at timestamp with time zone not null default now();

update public.users
set total_xp = greatest(coalesce(total_xp, 0), 0),
    xp_updated_at = coalesce(xp_updated_at, created_at, now());

do $$
begin
    if not exists (
        select 1
        from pg_constraint
        where conname = 'users_total_xp_nonnegative'
          and conrelid = 'public.users'::regclass
    ) then
        alter table public.users
            add constraint users_total_xp_nonnegative check (total_xp >= 0);
    end if;
end
$$;

create or replace function public.bump_users_xp_updated_at()
returns trigger
language plpgsql
set search_path = public
as $$
begin
    if new.total_xp is distinct from old.total_xp then
        new.xp_updated_at := now();
    end if;
    return new;
end;
$$;

drop trigger if exists users_bump_xp_updated_at on public.users;

create trigger users_bump_xp_updated_at
before update on public.users
for each row
execute function public.bump_users_xp_updated_at();
