-- Recreate indexes that cover foreign keys (dropped as "unused" but needed for FK performance)
CREATE INDEX IF NOT EXISTS idx_events_trip_id ON events(trip_id);
CREATE INDEX IF NOT EXISTS idx_trip_shares_user_id ON trip_shares(user_id);
CREATE INDEX IF NOT EXISTS idx_trip_shares_invited_by ON trip_shares(invited_by);
CREATE INDEX IF NOT EXISTS idx_invite_links_created_by ON invite_links(created_by);
