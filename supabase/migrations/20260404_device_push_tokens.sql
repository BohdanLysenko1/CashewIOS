-- Stores APNs device tokens per user.

create table if not exists public.device_push_tokens (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references public.users(id) on delete cascade,
    token text not null,
    platform text not null default 'ios',
    created_at timestamptz not null default now(),
    unique(user_id, token)
);

create index if not exists idx_device_push_tokens_user_id
    on public.device_push_tokens(user_id);

alter table public.device_push_tokens enable row level security;

drop policy if exists "Users manage own push tokens" on public.device_push_tokens;
create policy "Users manage own push tokens"
on public.device_push_tokens
as permissive
for all
to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid());
