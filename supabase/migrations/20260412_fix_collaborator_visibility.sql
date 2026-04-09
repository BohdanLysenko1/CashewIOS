-- Fix: Collaborator visibility in Manage Access view
--
-- Two bugs fixed:
-- 1. Owner can't see invited collaborators:
--    The users RLS policy "Users can read own profile" blocked reading
--    other users' profiles when trip_shares joins to users!user_id.
--
-- 2. Collaborator only sees themselves:
--    "trip_shares: member manages" only grants non-owners access to rows
--    where user_id = auth.uid() — no policy allowed reading peer shares.
--
-- Fix A: Allow accepted collaborators to read all accepted shares for their trips/events.
-- Uses SECURITY DEFINER helpers to avoid RLS recursion.

CREATE POLICY "trip_shares: collaborators can read peer shares"
  ON public.trip_shares FOR SELECT TO authenticated
  USING (public.is_trip_collaborator(trip_shares.trip_id));

CREATE POLICY "event_shares: collaborators can read peer shares"
  ON public.event_shares FOR SELECT TO authenticated
  USING (public.is_event_collaborator(event_shares.event_id));

-- Fix B: Allow reading profiles of other members on shared resources.

-- Collaborator or owner can read profiles of accepted collaborators on their trips.
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

-- Same for events.
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

-- Collaborators can read the profile of the trip owner (for the Owner row in CollaboratorsView).
CREATE POLICY "users: read trip owner profiles"
  ON public.users FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.trips t
      WHERE t.owner_id = users.id
        AND public.is_trip_collaborator(t.id)
    )
  );

-- Collaborators can read the profile of the event owner.
CREATE POLICY "users: read event owner profiles"
  ON public.users FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.events e
      WHERE e.owner_id = users.id
        AND public.is_event_collaborator(e.id)
    )
  );
