create or replace function public.delete_user_account()
returns void
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
begin
    delete from auth.users where id = auth.uid();
end;
$$;

revoke all on function public.delete_user_account() from public;
grant execute on function public.delete_user_account() to authenticated;
