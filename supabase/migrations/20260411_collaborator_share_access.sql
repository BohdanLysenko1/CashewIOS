-- Allow collaborators who created invites to read back those share rows.
-- The existing "member manages" policy only covers user_id = auth.uid() (invitee)
-- and trip/event owner. A collaborator who sent an invite (invited_by = auth.uid())
-- needs SELECT access to their own invite rows for fetchSharedByMeTripIds to work.

create policy "trip_shares: inviter can read own invites"
on public.trip_shares
as permissive
for select
to authenticated
using (invited_by = (select auth.uid()));

create policy "event_shares: inviter can read own invites"
on public.event_shares
as permissive
for select
to authenticated
using (invited_by = (select auth.uid()));
