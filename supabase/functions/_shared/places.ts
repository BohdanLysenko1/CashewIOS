import { SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2";

// ── Configuration ───────────────────────────────────────────────────

const PLACES_SEARCH_URL = "https://places.googleapis.com/v1/places:searchText";
const PLACES_MEDIA_BASE = "https://places.googleapis.com/v1";
const PHOTO_BUCKET = "itinerary-photos";
const PHOTO_MAX_HEIGHT_PX = 800;
/// Bias Places search to within this radius of the activity coordinate.
/// Five kilometers covers typical urban POI clusters without dropping
/// venues that share a name across nearby neighborhoods.
const LOCATION_BIAS_RADIUS_M = 5000;
const PLACES_FIELD_MASK =
  "places.id,places.displayName,places.websiteUri,places.photos";
const WIKI_SUMMARY_BASE =
  "https://en.wikipedia.org/api/rest_v1/page/summary/";

// ── Public types ────────────────────────────────────────────────────

export interface EnrichInput {
  title: string;
  address: string;
  latitude?: number | null;
  longitude?: number | null;
}

export interface EnrichResult {
  imageURL: string | null;
  websiteURL: string | null;
}

// ── Public API ──────────────────────────────────────────────────────

/// Looks up a venue via Google Places (New) for the given activity and returns
/// a public Storage URL for the first photo (uploaded into the
/// `itinerary-photos` bucket and cached by Place ID) plus the official website.
///
/// Falls back to a Wikipedia article URL for `websiteURL` when Places either
/// finds no match or returns no `websiteUri`. All failures degrade to nulls —
/// the function never throws — so callers can bound it with `withTimeout` and
/// treat the result as best-effort enrichment.
export async function enrichWithPlace(
  activity: EnrichInput,
  supabase: SupabaseClient,
): Promise<EnrichResult> {
  const apiKey = Deno.env.get("GOOGLE_PLACES_API_KEY");
  if (!apiKey) {
    return { imageURL: null, websiteURL: await wikipediaArticleURL(activity.title) };
  }

  const place = await searchPlace(activity, apiKey);
  if (!place) {
    return { imageURL: null, websiteURL: await wikipediaArticleURL(activity.title) };
  }

  const websiteURL = place.websiteUri ?? (await wikipediaArticleURL(activity.title));
  const photoName = place.photos?.[0]?.name ?? null;
  const imageURL = photoName
    ? await resolvePhoto(supabase, place.id, photoName, apiKey)
    : null;

  return { imageURL, websiteURL };
}

// ── Internal ────────────────────────────────────────────────────────

interface PlaceResult {
  id: string;
  websiteUri?: string;
  photos?: { name: string }[];
}

async function searchPlace(
  activity: EnrichInput,
  apiKey: string,
): Promise<PlaceResult | null> {
  const textQuery = [activity.title, activity.address]
    .filter((s) => s && s.trim().length > 0)
    .join(", ");
  if (!textQuery) return null;

  const body: Record<string, unknown> = {
    textQuery,
    maxResultCount: 1,
  };
  if (activity.latitude != null && activity.longitude != null) {
    body.locationBias = {
      circle: {
        center: { latitude: activity.latitude, longitude: activity.longitude },
        radius: LOCATION_BIAS_RADIUS_M,
      },
    };
  }

  try {
    const res = await fetch(PLACES_SEARCH_URL, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "X-Goog-Api-Key": apiKey,
        "X-Goog-FieldMask": PLACES_FIELD_MASK,
      },
      body: JSON.stringify(body),
    });
    if (!res.ok) {
      console.error(`[places] searchText failed ${res.status}: ${await res.text()}`);
      return null;
    }
    const json = await res.json();
    const place = json?.places?.[0] as PlaceResult | undefined;
    return place ?? null;
  } catch (err) {
    console.error(`[places] searchText threw: ${errorMessage(err)}`);
    return null;
  }
}

async function resolvePhoto(
  supabase: SupabaseClient,
  placeId: string,
  photoName: string,
  apiKey: string,
): Promise<string | null> {
  const objectPath = `${placeId}.jpg`;

  // Cache check — return existing public URL without re-downloading.
  if (await storageHasObject(supabase, objectPath)) {
    return publicURL(supabase, objectPath);
  }

  const bytes = await downloadPhotoBytes(photoName, apiKey);
  if (!bytes) return null;

  const uploaded = await uploadPhoto(supabase, objectPath, bytes);
  return uploaded ? publicURL(supabase, objectPath) : null;
}

async function storageHasObject(
  supabase: SupabaseClient,
  objectPath: string,
): Promise<boolean> {
  try {
    const { data } = await supabase.storage
      .from(PHOTO_BUCKET)
      .list("", { search: objectPath, limit: 1 });
    return !!data && data.some((o) => o.name === objectPath);
  } catch (err) {
    console.error(`[places] storage list failed: ${errorMessage(err)}`);
    return false;
  }
}

async function downloadPhotoBytes(
  photoName: string,
  apiKey: string,
): Promise<Uint8Array | null> {
  const mediaURL = `${PLACES_MEDIA_BASE}/${photoName}/media?maxHeightPx=${PHOTO_MAX_HEIGHT_PX}&key=${apiKey}`;
  try {
    const res = await fetch(mediaURL);
    if (!res.ok) {
      console.error(`[places] photo fetch failed ${res.status}`);
      return null;
    }
    return new Uint8Array(await res.arrayBuffer());
  } catch (err) {
    console.error(`[places] photo fetch threw: ${errorMessage(err)}`);
    return null;
  }
}

async function uploadPhoto(
  supabase: SupabaseClient,
  objectPath: string,
  bytes: Uint8Array,
): Promise<boolean> {
  try {
    const { error } = await supabase.storage
      .from(PHOTO_BUCKET)
      .upload(objectPath, bytes, {
        contentType: "image/jpeg",
        upsert: true,
      });
    if (error) {
      console.error(`[places] photo upload failed: ${error.message}`);
      return false;
    }
    return true;
  } catch (err) {
    console.error(`[places] photo upload threw: ${errorMessage(err)}`);
    return false;
  }
}

function publicURL(supabase: SupabaseClient, objectPath: string): string {
  const { data } = supabase.storage.from(PHOTO_BUCKET).getPublicUrl(objectPath);
  return data.publicUrl;
}

async function wikipediaArticleURL(title: string): Promise<string | null> {
  const trimmed = title.trim();
  if (!trimmed) return null;
  try {
    const res = await fetch(
      `${WIKI_SUMMARY_BASE}${encodeURIComponent(trimmed)}`,
      { headers: { Accept: "application/json" } },
    );
    if (!res.ok) return null;
    const json = await res.json();
    const url = json?.content_urls?.desktop?.page;
    return typeof url === "string" ? url : null;
  } catch {
    return null;
  }
}

function errorMessage(err: unknown): string {
  return err instanceof Error ? err.message : String(err);
}
