-- Track AI itinerary generation usage for rate limiting.

create table if not exists public.itinerary_generations (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references public.users(id) on delete cascade,
    destination text not null,
    days integer not null,
    created_at timestamptz not null default now()
);

create index if not exists idx_itinerary_generations_user_created
    on public.itinerary_generations(user_id, created_at desc);

alter table public.itinerary_generations enable row level security;

create policy "itinerary_generations: owner manages"
on public.itinerary_generations
as permissive
for all
to authenticated
using (user_id = (select auth.uid()))
with check (user_id = (select auth.uid()));
