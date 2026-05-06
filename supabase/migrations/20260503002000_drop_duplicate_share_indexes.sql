-- The live database already had unique constraints on these column pairs.
-- Keep the constraint-backed indexes and drop the duplicate migration-created indexes
-- only when another unique index already covers the same columns.
do $$
begin
    if to_regclass('public.idx_trip_shares_unique_member') is not null
       and exists (
           select 1
           from pg_index i
           join pg_class idx on idx.oid = i.indexrelid
           join pg_class t on t.oid = i.indrelid
           join pg_namespace n on n.oid = t.relnamespace
           where n.nspname = 'public'
             and t.relname = 'trip_shares'
             and idx.relname <> 'idx_trip_shares_unique_member'
             and i.indisunique
             and (
                 select array_agg(a.attname order by x.ordinality)
                 from unnest(i.indkey) with ordinality as x(attnum, ordinality)
                 join pg_attribute a on a.attrelid = t.oid and a.attnum = x.attnum
             ) = array['trip_id', 'user_id']
       ) then
        drop index public.idx_trip_shares_unique_member;
    end if;
end $$;

do $$
begin
    if to_regclass('public.idx_event_shares_unique_member') is not null
       and exists (
           select 1
           from pg_index i
           join pg_class idx on idx.oid = i.indexrelid
           join pg_class t on t.oid = i.indrelid
           join pg_namespace n on n.oid = t.relnamespace
           where n.nspname = 'public'
             and t.relname = 'event_shares'
             and idx.relname <> 'idx_event_shares_unique_member'
             and i.indisunique
             and (
                 select array_agg(a.attname order by x.ordinality)
                 from unnest(i.indkey) with ordinality as x(attnum, ordinality)
                 join pg_attribute a on a.attrelid = t.oid and a.attnum = x.attnum
             ) = array['event_id', 'user_id']
       ) then
        drop index public.idx_event_shares_unique_member;
    end if;
end $$;
