-- =============================================================================
-- Cashew iOS – Full Database Schema
-- Generated: 2026-04-09
-- Source: Supabase project sjmeicdvnzismnmvjnro (us-east-1)
--
-- Regenerate after migrations:
--   ./scripts/update-schema.sh
-- =============================================================================

-- =============================================================================
-- TABLES
-- =============================================================================

CREATE TABLE public.users (
  id uuid NOT NULL,
  email text NOT NULL,
  display_name text NOT NULL,
  avatar_url text,
  created_at timestamp with time zone DEFAULT now(),
  total_xp integer DEFAULT 0 NOT NULL,
  xp_updated_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE public.trips (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  owner_id uuid NOT NULL,
  name text NOT NULL,
  destination text DEFAULT ''::text NOT NULL,
  destination_latitude double precision,
  destination_longitude double precision,
  start_date timestamp with time zone NOT NULL,
  end_date timestamp with time zone NOT NULL,
  notes text,
  cover_image_url text,
  status text DEFAULT 'planning'::text NOT NULL,
  budget numeric,
  currency text DEFAULT 'USD'::text NOT NULL,
  accommodation_name text,
  accommodation_address text,
  accommodation_check_in timestamp with time zone,
  accommodation_check_out timestamp with time zone,
  accommodation_confirmation text,
  transportation_type text,
  transportation_details text,
  transportation_confirmation text,
  expenses jsonb DEFAULT '[]'::jsonb NOT NULL,
  activities jsonb DEFAULT '[]'::jsonb NOT NULL,
  packing_items jsonb DEFAULT '[]'::jsonb NOT NULL,
  checklist_items jsonb DEFAULT '[]'::jsonb NOT NULL,
  attachments jsonb DEFAULT '[]'::jsonb NOT NULL,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  hero_mode text,
  hero_color_token text,
  hero_photo_attachment_id uuid
);

CREATE TABLE public.events (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  owner_id uuid NOT NULL,
  title text NOT NULL,
  date timestamp with time zone NOT NULL,
  end_date timestamp with time zone,
  location text,
  location_latitude double precision,
  location_longitude double precision,
  address text,
  notes text,
  category text DEFAULT 'other'::text NOT NULL,
  is_all_day boolean DEFAULT false NOT NULL,
  priority text DEFAULT 'medium'::text NOT NULL,
  url text,
  cost numeric,
  currency text DEFAULT 'USD'::text,
  custom_category_name text,
  trip_id uuid,
  reminders jsonb DEFAULT '[]'::jsonb NOT NULL,
  attachments jsonb DEFAULT '[]'::jsonb NOT NULL,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  hero_mode text,
  hero_color_token text,
  hero_photo_attachment_id uuid,
  exception_dates timestamp with time zone[] DEFAULT '{}'::timestamp with time zone[],
  timezone_identifier text
);

CREATE TABLE public.trip_shares (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  trip_id uuid NOT NULL,
  user_id uuid NOT NULL,
  invited_by uuid NOT NULL,
  accepted_at timestamp with time zone,
  created_at timestamp with time zone DEFAULT now()
);

CREATE TABLE public.event_shares (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  event_id uuid NOT NULL,
  user_id uuid NOT NULL,
  invited_by uuid NOT NULL,
  accepted_at timestamp with time zone,
  created_at timestamp with time zone DEFAULT now()
);

CREATE TABLE public.invite_links (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  token text DEFAULT encode(gen_random_bytes(16), 'hex'::text) NOT NULL,
  resource_type text NOT NULL,
  resource_id uuid NOT NULL,
  created_by uuid NOT NULL,
  expires_at timestamp with time zone DEFAULT (now() + '7 days'::interval),
  created_at timestamp with time zone DEFAULT now()
);

CREATE TABLE public.trip_activity_log (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  trip_id uuid NOT NULL,
  user_id uuid NOT NULL,
  summary text NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE public.device_push_tokens (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  user_id uuid NOT NULL,
  token text NOT NULL,
  platform text DEFAULT 'ios'::text NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE public.daily_routines (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  owner_id uuid NOT NULL,
  title text NOT NULL,
  start_time timestamp with time zone,
  end_time timestamp with time zone,
  category text DEFAULT 'personal'::text NOT NULL,
  repeat_pattern text DEFAULT 'daily'::text NOT NULL,
  selected_days jsonb DEFAULT '[]'::jsonb NOT NULL,
  is_enabled boolean DEFAULT true NOT NULL,
  notes text DEFAULT ''::text NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  updated_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE public.daily_tasks (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  owner_id uuid NOT NULL,
  title text NOT NULL,
  date timestamp with time zone NOT NULL,
  start_time timestamp with time zone,
  end_time timestamp with time zone,
  is_completed boolean DEFAULT false NOT NULL,
  category text DEFAULT 'personal'::text NOT NULL,
  custom_category_name text,
  notes text DEFAULT ''::text NOT NULL,
  routine_id uuid,
  trip_id uuid,
  event_id uuid,
  subtasks jsonb DEFAULT '[]'::jsonb NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  updated_at timestamp with time zone DEFAULT now() NOT NULL
);

-- =============================================================================
-- PRIMARY KEYS
-- =============================================================================

ALTER TABLE public.users ADD CONSTRAINT users_pkey PRIMARY KEY (id);
ALTER TABLE public.trips ADD CONSTRAINT trips_pkey PRIMARY KEY (id);
ALTER TABLE public.events ADD CONSTRAINT events_pkey PRIMARY KEY (id);
ALTER TABLE public.trip_shares ADD CONSTRAINT trip_shares_pkey PRIMARY KEY (id);
ALTER TABLE public.event_shares ADD CONSTRAINT event_shares_pkey PRIMARY KEY (id);
ALTER TABLE public.invite_links ADD CONSTRAINT invite_links_pkey PRIMARY KEY (id);
ALTER TABLE public.trip_activity_log ADD CONSTRAINT trip_activity_log_pkey PRIMARY KEY (id);
ALTER TABLE public.device_push_tokens ADD CONSTRAINT device_push_tokens_pkey PRIMARY KEY (id);
ALTER TABLE public.daily_routines ADD CONSTRAINT daily_routines_pkey PRIMARY KEY (id);
ALTER TABLE public.daily_tasks ADD CONSTRAINT daily_tasks_pkey PRIMARY KEY (id);

-- =============================================================================
-- UNIQUE CONSTRAINTS
-- =============================================================================

ALTER TABLE public.users ADD CONSTRAINT users_email_key UNIQUE (email);
ALTER TABLE public.trip_shares ADD CONSTRAINT trip_shares_trip_id_user_id_key UNIQUE (trip_id, user_id);
ALTER TABLE public.event_shares ADD CONSTRAINT event_shares_event_id_user_id_key UNIQUE (event_id, user_id);
ALTER TABLE public.invite_links ADD CONSTRAINT invite_links_token_key UNIQUE (token);
ALTER TABLE public.device_push_tokens ADD CONSTRAINT device_push_tokens_user_id_token_key UNIQUE (user_id, token);

-- =============================================================================
-- FOREIGN KEYS
-- =============================================================================

ALTER TABLE public.trips ADD CONSTRAINT trips_owner_id_fkey
  FOREIGN KEY (owner_id) REFERENCES public.users (id) ON DELETE CASCADE;

ALTER TABLE public.events ADD CONSTRAINT events_owner_id_fkey
  FOREIGN KEY (owner_id) REFERENCES public.users (id) ON DELETE CASCADE;

ALTER TABLE public.events ADD CONSTRAINT events_trip_id_fkey
  FOREIGN KEY (trip_id) REFERENCES public.trips (id) ON DELETE SET NULL;

ALTER TABLE public.trip_shares ADD CONSTRAINT trip_shares_trip_id_fkey
  FOREIGN KEY (trip_id) REFERENCES public.trips (id) ON DELETE CASCADE;

ALTER TABLE public.trip_shares ADD CONSTRAINT trip_shares_user_id_fkey
  FOREIGN KEY (user_id) REFERENCES public.users (id) ON DELETE CASCADE;

ALTER TABLE public.trip_shares ADD CONSTRAINT trip_shares_invited_by_fkey
  FOREIGN KEY (invited_by) REFERENCES public.users (id) ON DELETE CASCADE;

ALTER TABLE public.event_shares ADD CONSTRAINT event_shares_event_id_fkey
  FOREIGN KEY (event_id) REFERENCES public.events (id) ON DELETE CASCADE;

ALTER TABLE public.event_shares ADD CONSTRAINT event_shares_user_id_fkey
  FOREIGN KEY (user_id) REFERENCES public.users (id) ON DELETE CASCADE;

ALTER TABLE public.event_shares ADD CONSTRAINT event_shares_invited_by_fkey
  FOREIGN KEY (invited_by) REFERENCES public.users (id) ON DELETE CASCADE;

ALTER TABLE public.invite_links ADD CONSTRAINT invite_links_created_by_fkey
  FOREIGN KEY (created_by) REFERENCES public.users (id) ON DELETE CASCADE;

ALTER TABLE public.trip_activity_log ADD CONSTRAINT trip_activity_log_trip_id_fkey
  FOREIGN KEY (trip_id) REFERENCES public.trips (id) ON DELETE CASCADE;

ALTER TABLE public.trip_activity_log ADD CONSTRAINT trip_activity_log_user_id_fkey
  FOREIGN KEY (user_id) REFERENCES public.users (id) ON DELETE CASCADE;

ALTER TABLE public.device_push_tokens ADD CONSTRAINT device_push_tokens_user_id_fkey
  FOREIGN KEY (user_id) REFERENCES public.users (id) ON DELETE CASCADE;

-- =============================================================================
-- INDEXES
-- =============================================================================

CREATE INDEX idx_trips_owner_id ON public.trips USING btree (owner_id);
CREATE INDEX idx_events_owner_id ON public.events USING btree (owner_id);
CREATE INDEX idx_events_trip_id ON public.events USING btree (trip_id);
CREATE INDEX idx_trip_shares_user_id ON public.trip_shares USING btree (user_id);
CREATE INDEX idx_trip_shares_invited_by ON public.trip_shares USING btree (invited_by);
CREATE INDEX idx_event_shares_user_id ON public.event_shares USING btree (user_id);
CREATE INDEX idx_event_shares_invited_by ON public.event_shares USING btree (invited_by);
CREATE INDEX idx_invite_links_created_by ON public.invite_links USING btree (created_by);
CREATE INDEX idx_trip_activity_log_trip_id ON public.trip_activity_log USING btree (trip_id, created_at DESC);
CREATE INDEX idx_trip_activity_log_user_id ON public.trip_activity_log USING btree (user_id);
CREATE INDEX idx_device_push_tokens_user_id ON public.device_push_tokens USING btree (user_id);
CREATE INDEX idx_daily_routines_owner ON public.daily_routines USING btree (owner_id);
CREATE INDEX idx_daily_tasks_owner ON public.daily_tasks USING btree (owner_id);
CREATE INDEX idx_daily_tasks_date ON public.daily_tasks USING btree (owner_id, date);

-- =============================================================================
-- FUNCTIONS
-- =============================================================================

-- Auto-sets updated_at on trips and events
CREATE OR REPLACE FUNCTION public.touch_updated_at()
  RETURNS trigger
  LANGUAGE plpgsql
  SET search_path TO 'public', 'pg_temp'
AS $$
  begin new.updated_at = now(); return new; end;
$$;

-- Auto-sets updated_at on daily_routines
CREATE OR REPLACE FUNCTION public.update_daily_routines_updated_at()
  RETURNS trigger
  LANGUAGE plpgsql
  SET search_path TO 'public', 'pg_temp'
AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$;

-- Auto-sets updated_at on daily_tasks
CREATE OR REPLACE FUNCTION public.update_daily_tasks_updated_at()
  RETURNS trigger
  LANGUAGE plpgsql
  SET search_path TO 'public', 'pg_temp'
AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$;

-- Bumps xp_updated_at when total_xp changes
CREATE OR REPLACE FUNCTION public.bump_users_xp_updated_at()
  RETURNS trigger
  LANGUAGE plpgsql
  SET search_path TO 'public'
AS $$
begin
    if new.total_xp is distinct from old.total_xp then
        new.xp_updated_at := now();
    end if;
    return new;
end;
$$;

-- SECURITY DEFINER helpers (prevent RLS recursion)
CREATE OR REPLACE FUNCTION public.get_trip_owner_id(p_trip_id uuid)
  RETURNS uuid
  LANGUAGE sql
  STABLE SECURITY DEFINER
  SET search_path TO 'public', 'auth', 'pg_temp'
AS $$
    select owner_id from public.trips where id = p_trip_id;
$$;

CREATE OR REPLACE FUNCTION public.get_event_owner_id(p_event_id uuid)
  RETURNS uuid
  LANGUAGE sql
  STABLE SECURITY DEFINER
  SET search_path TO 'public', 'auth', 'pg_temp'
AS $$
    select owner_id from public.events where id = p_event_id;
$$;

CREATE OR REPLACE FUNCTION public.is_trip_collaborator(trip_id uuid)
  RETURNS boolean
  LANGUAGE sql
  SECURITY DEFINER
  SET search_path TO 'public', 'auth', 'pg_temp'
AS $$
    select exists (
      select 1 from public.trip_shares
      where trip_shares.trip_id = $1
        and trip_shares.user_id = auth.uid()
        and trip_shares.accepted_at is not null
    );
$$;

CREATE OR REPLACE FUNCTION public.is_event_collaborator(event_id uuid)
  RETURNS boolean
  LANGUAGE sql
  SECURITY DEFINER
  SET search_path TO 'public', 'auth', 'pg_temp'
AS $$
    select exists (
      select 1 from public.event_shares
      where event_shares.event_id = $1
        and event_shares.user_id = auth.uid()
        and event_shares.accepted_at is not null
    );
$$;

-- Auto-creates public.users row on auth.users insert
CREATE OR REPLACE FUNCTION public.handle_new_user()
  RETURNS trigger
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public', 'auth', 'pg_temp'
AS $$
  BEGIN
    INSERT INTO public.users (id, email, display_name)
    VALUES (
      NEW.id,
      NEW.email,
      COALESCE(NEW.raw_user_meta_data->>'display_name', split_part(NEW.email, '@', 1))
    );
    RETURN NEW;
  END;
$$;

-- Auto-enables RLS on any new table created in public schema
CREATE OR REPLACE FUNCTION public.rls_auto_enable()
  RETURNS event_trigger
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'pg_catalog'
AS $$
DECLARE
  cmd record;
BEGIN
  FOR cmd IN
    SELECT *
    FROM pg_event_trigger_ddl_commands()
    WHERE command_tag IN ('CREATE TABLE', 'CREATE TABLE AS', 'SELECT INTO')
      AND object_type IN ('table','partitioned table')
  LOOP
    IF cmd.schema_name IS NOT NULL AND cmd.schema_name IN ('public')
      AND cmd.schema_name NOT IN ('pg_catalog','information_schema')
      AND cmd.schema_name NOT LIKE 'pg_toast%'
      AND cmd.schema_name NOT LIKE 'pg_temp%' THEN
      BEGIN
        EXECUTE format('alter table if exists %s enable row level security', cmd.object_identity);
        RAISE LOG 'rls_auto_enable: enabled RLS on %', cmd.object_identity;
      EXCEPTION
        WHEN OTHERS THEN
          RAISE LOG 'rls_auto_enable: failed to enable RLS on %', cmd.object_identity;
      END;
    ELSE
      RAISE LOG 'rls_auto_enable: skip % (either system schema or not in enforced list: %.)', cmd.object_identity, cmd.schema_name;
    END IF;
  END LOOP;
END;
$$;

-- =============================================================================
-- TRIGGERS (row-level)
-- =============================================================================

CREATE TRIGGER trips_updated_at
  BEFORE UPDATE ON public.trips
  FOR EACH ROW EXECUTE FUNCTION public.touch_updated_at();

CREATE TRIGGER events_updated_at
  BEFORE UPDATE ON public.events
  FOR EACH ROW EXECUTE FUNCTION public.touch_updated_at();

CREATE TRIGGER trg_daily_routines_updated_at
  BEFORE UPDATE ON public.daily_routines
  FOR EACH ROW EXECUTE FUNCTION public.update_daily_routines_updated_at();

CREATE TRIGGER trg_daily_tasks_updated_at
  BEFORE UPDATE ON public.daily_tasks
  FOR EACH ROW EXECUTE FUNCTION public.update_daily_tasks_updated_at();

CREATE TRIGGER users_bump_xp_updated_at
  BEFORE UPDATE ON public.users
  FOR EACH ROW EXECUTE FUNCTION public.bump_users_xp_updated_at();

-- Note: handle_new_user() is triggered on auth.users (Supabase-managed):
-- CREATE TRIGGER on_auth_user_created AFTER INSERT ON auth.users
--   FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- =============================================================================
-- EVENT TRIGGER (DDL-level)
-- =============================================================================

CREATE EVENT TRIGGER ensure_rls
  ON ddl_command_end
  EXECUTE FUNCTION public.rls_auto_enable();

-- =============================================================================
-- ROW LEVEL SECURITY
-- =============================================================================

ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.trips ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.trip_shares ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.event_shares ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.invite_links ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.trip_activity_log ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.device_push_tokens ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.daily_routines ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.daily_tasks ENABLE ROW LEVEL SECURITY;

-- users
CREATE POLICY "Users can read own profile"
  ON public.users FOR SELECT TO authenticated
  USING ((SELECT auth.uid()) = id);

CREATE POLICY "Users can insert own profile"
  ON public.users FOR INSERT TO authenticated
  WITH CHECK ((SELECT auth.uid()) = id);

CREATE POLICY "Users can update own profile"
  ON public.users FOR UPDATE TO authenticated
  USING ((SELECT auth.uid()) = id)
  WITH CHECK ((SELECT auth.uid()) = id);

CREATE POLICY "users: read trip member profiles"
  ON public.users FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.trip_shares ts
      WHERE ts.user_id = users.id
        AND ts.accepted_at IS NOT NULL
        AND (
          public.is_trip_collaborator(ts.trip_id)
          OR EXISTS (SELECT 1 FROM public.trips t WHERE t.id = ts.trip_id AND t.owner_id = (SELECT auth.uid()))
        )
    )
  );

CREATE POLICY "users: read event member profiles"
  ON public.users FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.event_shares es
      WHERE es.user_id = users.id
        AND es.accepted_at IS NOT NULL
        AND (
          public.is_event_collaborator(es.event_id)
          OR EXISTS (SELECT 1 FROM public.events e WHERE e.id = es.event_id AND e.owner_id = (SELECT auth.uid()))
        )
    )
  );

CREATE POLICY "users: read trip owner profiles"
  ON public.users FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.trips t
      WHERE t.owner_id = users.id
        AND public.is_trip_collaborator(t.id)
    )
  );

CREATE POLICY "users: read event owner profiles"
  ON public.users FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.events e
      WHERE e.owner_id = users.id
        AND public.is_event_collaborator(e.id)
    )
  );

-- trips
CREATE POLICY "trips: member read"
  ON public.trips FOR SELECT TO authenticated
  USING ((owner_id = (SELECT auth.uid())) OR is_trip_collaborator(id));

CREATE POLICY "trips: owner insert"
  ON public.trips FOR INSERT TO authenticated
  WITH CHECK (owner_id = (SELECT auth.uid()));

CREATE POLICY "trips: member update"
  ON public.trips FOR UPDATE TO authenticated
  USING ((owner_id = (SELECT auth.uid())) OR is_trip_collaborator(id))
  WITH CHECK (owner_id = get_trip_owner_id(id));

CREATE POLICY "trips: owner delete"
  ON public.trips FOR DELETE TO authenticated
  USING (owner_id = (SELECT auth.uid()));

-- events
CREATE POLICY "events: member read"
  ON public.events FOR SELECT TO authenticated
  USING ((owner_id = (SELECT auth.uid())) OR is_event_collaborator(id));

CREATE POLICY "events: owner insert"
  ON public.events FOR INSERT TO authenticated
  WITH CHECK (owner_id = (SELECT auth.uid()));

CREATE POLICY "events: member update"
  ON public.events FOR UPDATE TO authenticated
  USING ((owner_id = (SELECT auth.uid())) OR is_event_collaborator(id))
  WITH CHECK (owner_id = get_event_owner_id(id));

CREATE POLICY "events: owner delete"
  ON public.events FOR DELETE TO authenticated
  USING (owner_id = (SELECT auth.uid()));

-- trip_shares
CREATE POLICY "trip_shares: member manages"
  ON public.trip_shares FOR ALL TO authenticated
  USING (
    (user_id = (SELECT auth.uid())) OR
    (EXISTS (SELECT 1 FROM trips WHERE trips.id = trip_shares.trip_id AND trips.owner_id = (SELECT auth.uid())))
  )
  WITH CHECK (
    (user_id = (SELECT auth.uid())) OR
    (EXISTS (SELECT 1 FROM trips WHERE trips.id = trip_shares.trip_id AND trips.owner_id = (SELECT auth.uid())))
  );

CREATE POLICY "trip_shares: inviter can read own invites"
  ON public.trip_shares FOR SELECT TO authenticated
  USING (invited_by = (SELECT auth.uid()));

CREATE POLICY "trip_shares: collaborators can read peer shares"
  ON public.trip_shares FOR SELECT TO authenticated
  USING (public.is_trip_collaborator(trip_shares.trip_id));

-- event_shares
CREATE POLICY "event_shares: member manages"
  ON public.event_shares FOR ALL TO authenticated
  USING (
    (user_id = (SELECT auth.uid())) OR
    (EXISTS (SELECT 1 FROM events WHERE events.id = event_shares.event_id AND events.owner_id = (SELECT auth.uid())))
  )
  WITH CHECK (
    (user_id = (SELECT auth.uid())) OR
    (EXISTS (SELECT 1 FROM events WHERE events.id = event_shares.event_id AND events.owner_id = (SELECT auth.uid())))
  );

CREATE POLICY "event_shares: inviter can read own invites"
  ON public.event_shares FOR SELECT TO authenticated
  USING (invited_by = (SELECT auth.uid()));

CREATE POLICY "event_shares: collaborators can read peer shares"
  ON public.event_shares FOR SELECT TO authenticated
  USING (public.is_event_collaborator(event_shares.event_id));

-- invite_links
CREATE POLICY "invite_links: token lookup"
  ON public.invite_links FOR SELECT TO authenticated
  USING (true);

CREATE POLICY "invite_links: creator insert"
  ON public.invite_links FOR INSERT TO authenticated
  WITH CHECK (created_by = (SELECT auth.uid()));

CREATE POLICY "invite_links: creator update"
  ON public.invite_links FOR UPDATE TO authenticated
  USING (created_by = (SELECT auth.uid()))
  WITH CHECK (created_by = (SELECT auth.uid()));

CREATE POLICY "invite_links: creator delete"
  ON public.invite_links FOR DELETE TO authenticated
  USING (created_by = (SELECT auth.uid()));

-- trip_activity_log
CREATE POLICY "trip_activity_log: members can view"
  ON public.trip_activity_log FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM trips
      WHERE trips.id = trip_activity_log.trip_id
        AND ((trips.owner_id = (SELECT auth.uid())) OR is_trip_collaborator(trips.id))
    )
  );

CREATE POLICY "trip_activity_log: members can insert"
  ON public.trip_activity_log FOR INSERT TO authenticated
  WITH CHECK (
    (user_id = (SELECT auth.uid())) AND
    EXISTS (
      SELECT 1 FROM trips
      WHERE trips.id = trip_activity_log.trip_id
        AND ((trips.owner_id = (SELECT auth.uid())) OR is_trip_collaborator(trips.id))
    )
  );

-- device_push_tokens
CREATE POLICY "device_push_tokens: owner manages"
  ON public.device_push_tokens FOR ALL TO authenticated
  USING (user_id = (SELECT auth.uid()))
  WITH CHECK (user_id = (SELECT auth.uid()));

-- daily_routines
CREATE POLICY "Users can view own daily routines"
  ON public.daily_routines FOR SELECT TO authenticated
  USING ((SELECT auth.uid()) = owner_id);

CREATE POLICY "Users can insert own daily routines"
  ON public.daily_routines FOR INSERT TO authenticated
  WITH CHECK ((SELECT auth.uid()) = owner_id);

CREATE POLICY "Users can update own daily routines"
  ON public.daily_routines FOR UPDATE TO authenticated
  USING ((SELECT auth.uid()) = owner_id)
  WITH CHECK ((SELECT auth.uid()) = owner_id);

CREATE POLICY "Users can delete own daily routines"
  ON public.daily_routines FOR DELETE TO authenticated
  USING ((SELECT auth.uid()) = owner_id);

-- daily_tasks
CREATE POLICY "Users can view own daily tasks"
  ON public.daily_tasks FOR SELECT TO authenticated
  USING ((SELECT auth.uid()) = owner_id);

CREATE POLICY "Users can insert own daily tasks"
  ON public.daily_tasks FOR INSERT TO authenticated
  WITH CHECK ((SELECT auth.uid()) = owner_id);

CREATE POLICY "Users can update own daily tasks"
  ON public.daily_tasks FOR UPDATE TO authenticated
  USING ((SELECT auth.uid()) = owner_id)
  WITH CHECK ((SELECT auth.uid()) = owner_id);

CREATE POLICY "Users can delete own daily tasks"
  ON public.daily_tasks FOR DELETE TO authenticated
  USING ((SELECT auth.uid()) = owner_id);
