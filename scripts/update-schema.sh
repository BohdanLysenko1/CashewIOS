#!/bin/bash
set -e

REPO_ROOT="$(git rev-parse --show-toplevel)"
OUTPUT="$REPO_ROOT/supabase/schema.sql"

echo "Regenerating $OUTPUT ..."
supabase db dump -f "$OUTPUT"
echo "Done."
