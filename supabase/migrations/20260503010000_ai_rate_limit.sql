-- Per-user rate limiting for AI Edge Functions.
--
-- Each call to public.ai_rate_limit either records a new invocation and
-- returns 0 (allowed), or returns the number of seconds the caller must wait
-- before the oldest in-window call drops out (denied).
--
-- The RPC lives in `public` so it is discoverable through PostgREST without
-- adding `private` to the project's exposed schemas. Execute is restricted
-- to `service_role` so only Edge Functions (which use the service-role key
-- after `verifyAuth`) can invoke it. The append-only log table stays in
-- `private` because it is internal bookkeeping and should never be exposed.

create schema if not exists private;

create table if not exists private.ai_call_log (
    id            bigserial primary key,
    user_id       uuid not null references auth.users(id) on delete cascade,
    function_name text not null,
    called_at     timestamptz not null default now()
);

create index if not exists ai_call_log_user_fn_time_idx
    on private.ai_call_log (user_id, function_name, called_at desc);

create or replace function public.ai_rate_limit(
    p_user_id        uuid,
    p_function_name  text,
    p_max_per_window int,
    p_window_seconds int
)
returns int
language plpgsql
security definer
set search_path = private, pg_temp
as $$
declare
    v_window_start timestamptz := now() - make_interval(secs => p_window_seconds);
    v_count        int;
    v_oldest       timestamptz;
begin
    -- Garbage-collect this user's stale entries to keep the table bounded.
    delete from private.ai_call_log
     where user_id = p_user_id
       and function_name = p_function_name
       and called_at < v_window_start;

    select count(*), min(called_at)
      into v_count, v_oldest
      from private.ai_call_log
     where user_id = p_user_id
       and function_name = p_function_name;

    if v_count >= p_max_per_window then
        -- Seconds until the oldest in-window call expires (min 1).
        return greatest(
            1,
            ceil(extract(epoch from (v_oldest + make_interval(secs => p_window_seconds) - now())))::int
        );
    end if;

    insert into private.ai_call_log (user_id, function_name)
    values (p_user_id, p_function_name);

    return 0;
end;
$$;

revoke all on function public.ai_rate_limit(uuid, text, int, int) from public;
revoke all on function public.ai_rate_limit(uuid, text, int, int) from anon;
revoke all on function public.ai_rate_limit(uuid, text, int, int) from authenticated;
grant  execute on function public.ai_rate_limit(uuid, text, int, int) to service_role;
