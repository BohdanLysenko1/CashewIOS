-- ============================================================
-- 1. Consolidate event_shares SELECT policies
-- ============================================================

-- Drop existing permissive SELECT + ALL policies
DROP POLICY IF EXISTS "event_shares: member manages" ON event_shares;
DROP POLICY IF EXISTS "event_shares: collaborators can read peer shares" ON event_shares;
DROP POLICY IF EXISTS "event_shares: inviter can read own invites" ON event_shares;

-- Single consolidated SELECT policy
CREATE POLICY "event_shares: select"
  ON event_shares FOR SELECT TO authenticated
  USING (
    user_id = (SELECT auth.uid())
    OR invited_by = (SELECT auth.uid())
    OR is_event_collaborator(event_id)
    OR EXISTS (
      SELECT 1 FROM events
      WHERE events.id = event_shares.event_id
        AND events.owner_id = (SELECT auth.uid())
    )
  );

-- Restore write policies (previously covered by ALL)
CREATE POLICY "event_shares: insert"
  ON event_shares FOR INSERT TO authenticated
  WITH CHECK (
    user_id = (SELECT auth.uid())
    OR EXISTS (
      SELECT 1 FROM events
      WHERE events.id = event_shares.event_id
        AND events.owner_id = (SELECT auth.uid())
    )
  );

CREATE POLICY "event_shares: update"
  ON event_shares FOR UPDATE TO authenticated
  USING (
    user_id = (SELECT auth.uid())
    OR EXISTS (
      SELECT 1 FROM events
      WHERE events.id = event_shares.event_id
        AND events.owner_id = (SELECT auth.uid())
    )
  );

CREATE POLICY "event_shares: delete"
  ON event_shares FOR DELETE TO authenticated
  USING (
    user_id = (SELECT auth.uid())
    OR EXISTS (
      SELECT 1 FROM events
      WHERE events.id = event_shares.event_id
        AND events.owner_id = (SELECT auth.uid())
    )
  );

-- ============================================================
-- 2. Consolidate trip_shares SELECT policies
-- ============================================================

DROP POLICY IF EXISTS "trip_shares: member manages" ON trip_shares;
DROP POLICY IF EXISTS "trip_shares: collaborators can read peer shares" ON trip_shares;
DROP POLICY IF EXISTS "trip_shares: inviter can read own invites" ON trip_shares;

-- Single consolidated SELECT policy
CREATE POLICY "trip_shares: select"
  ON trip_shares FOR SELECT TO authenticated
  USING (
    user_id = (SELECT auth.uid())
    OR invited_by = (SELECT auth.uid())
    OR is_trip_collaborator(trip_id)
    OR EXISTS (
      SELECT 1 FROM trips
      WHERE trips.id = trip_shares.trip_id
        AND trips.owner_id = (SELECT auth.uid())
    )
  );

-- Restore write policies
CREATE POLICY "trip_shares: insert"
  ON trip_shares FOR INSERT TO authenticated
  WITH CHECK (
    user_id = (SELECT auth.uid())
    OR EXISTS (
      SELECT 1 FROM trips
      WHERE trips.id = trip_shares.trip_id
        AND trips.owner_id = (SELECT auth.uid())
    )
  );

CREATE POLICY "trip_shares: update"
  ON trip_shares FOR UPDATE TO authenticated
  USING (
    user_id = (SELECT auth.uid())
    OR EXISTS (
      SELECT 1 FROM trips
      WHERE trips.id = trip_shares.trip_id
        AND trips.owner_id = (SELECT auth.uid())
    )
  );

CREATE POLICY "trip_shares: delete"
  ON trip_shares FOR DELETE TO authenticated
  USING (
    user_id = (SELECT auth.uid())
    OR EXISTS (
      SELECT 1 FROM trips
      WHERE trips.id = trip_shares.trip_id
        AND trips.owner_id = (SELECT auth.uid())
    )
  );

-- ============================================================
-- 3. Consolidate users SELECT policies
-- ============================================================

DROP POLICY IF EXISTS "Users can read own profile" ON users;
DROP POLICY IF EXISTS "users: read event member profiles" ON users;
DROP POLICY IF EXISTS "users: read event owner profiles" ON users;
DROP POLICY IF EXISTS "users: read trip member profiles" ON users;
DROP POLICY IF EXISTS "users: read trip owner profiles" ON users;

-- Single consolidated SELECT policy
CREATE POLICY "users: select"
  ON users FOR SELECT TO authenticated
  USING (
    -- Own profile
    id = (SELECT auth.uid())
    -- Event member profiles (accepted collaborators on shared events)
    OR EXISTS (
      SELECT 1 FROM event_shares es
      WHERE es.user_id = users.id
        AND es.accepted_at IS NOT NULL
        AND (
          is_event_collaborator(es.event_id)
          OR EXISTS (
            SELECT 1 FROM events e
            WHERE e.id = es.event_id
              AND e.owner_id = (SELECT auth.uid())
          )
        )
    )
    -- Event owner profiles (owners of events you collaborate on)
    OR EXISTS (
      SELECT 1 FROM events e
      WHERE e.owner_id = users.id
        AND is_event_collaborator(e.id)
    )
    -- Trip member profiles (accepted collaborators on shared trips)
    OR EXISTS (
      SELECT 1 FROM trip_shares ts
      WHERE ts.user_id = users.id
        AND ts.accepted_at IS NOT NULL
        AND (
          is_trip_collaborator(ts.trip_id)
          OR EXISTS (
            SELECT 1 FROM trips t
            WHERE t.id = ts.trip_id
              AND t.owner_id = (SELECT auth.uid())
          )
        )
    )
    -- Trip owner profiles (owners of trips you collaborate on)
    OR EXISTS (
      SELECT 1 FROM trips t
      WHERE t.owner_id = users.id
        AND is_trip_collaborator(t.id)
    )
  );
