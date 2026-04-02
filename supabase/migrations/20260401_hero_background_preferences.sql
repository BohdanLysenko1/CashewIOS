-- Hero background preferences for trip/event detail hero cards.
-- Color token syncs across devices; photo selection stores attachment id reference.

alter table public.trips
    add column if not exists hero_mode text,
    add column if not exists hero_color_token text,
    add column if not exists hero_photo_attachment_id uuid;

alter table public.events
    add column if not exists hero_mode text,
    add column if not exists hero_color_token text,
    add column if not exists hero_photo_attachment_id uuid;
