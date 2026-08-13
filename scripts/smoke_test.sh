#!/bin/bash
set -e

BASE="http://localhost:8080/api/v1"
DATA_DIR=$(mktemp -d)
TEST_IMAGE="$DATA_DIR/test.png"
FAKE_IMAGE="$DATA_DIR/fake.jpg"

# Create a minimal valid PNG file (1x1 pixel)
printf '\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR\x00\x00\x00\x01\x00\x00\x00\x01\x08\x02\x00\x00\x00\x90wS\xde\x00\x00\x00\x0cIDATx\x9cc\xf8\x0f\x00\x00\x01\x01\x00\x05\x18\xd8N\x00\x00\x00\x00IEND\xaeB`\x82' > "$TEST_IMAGE"

# Create a non-image file (shell script) for content-sniffing test
echo '#!/bin/bash\necho "not an image"' > "$FAKE_IMAGE"

echo "=== Lumen Smoke Test ==="

# 1. Setup admin (idempotent)
echo -n "1. Setup admin... "
RESP=$(curl -s -X POST "$BASE/auth/setup" \
  -H "Content-Type: application/json" \
  -d '{"username":"testuser","password":"testpassword123"}')
if echo "$RESP" | grep -q '"error"' && ! echo "$RESP" | grep -q 'already exist'; then
  echo "FAIL: $RESP"; exit 1
fi
echo "OK"

# 2. Login
echo -n "2. Login... "
RESP=$(curl -s -X POST "$BASE/auth/login" \
  -H "Content-Type: application/json" \
  -d '{"username":"testuser","password":"testpassword123"}')
TOKEN=$(echo "$RESP" | python3 -c "import sys,json; print(json.load(sys.stdin)['data']['access_token'])" 2>/dev/null)
[ -z "$TOKEN" ] && { echo "FAIL: no token"; exit 1; }
echo "OK"

AUTH="Authorization: Bearer $TOKEN"

# Record count before upload
BEFORE=$(curl -s -X GET "$BASE/photos" -H "$AUTH" | python3 -c "import sys,json; print(len(json.load(sys.stdin)['data']))" 2>/dev/null)

# 3. Upload photo
echo -n "3. Upload photo... "
RESP=$(curl -s -X POST "$BASE/photos/upload" \
  -H "$AUTH" \
  -F "file=@$TEST_IMAGE;type=image/png" \
  -F "taken_at=2024-06-15T10:30:00Z")
PHOTO_ID=$(echo "$RESP" | python3 -c "import sys,json; print(json.load(sys.stdin)['data']['id'])" 2>/dev/null)
[ -z "$PHOTO_ID" ] && { echo "FAIL: no photo id ($RESP)"; exit 1; }
echo "OK (id=$PHOTO_ID)"

# 4. Timeline listing (verify count increased by 1)
echo -n "4. Timeline listing... "
RESP=$(curl -s -X GET "$BASE/photos" -H "$AUTH")
COUNT=$(echo "$RESP" | python3 -c "import sys,json; print(len(json.load(sys.stdin)['data']))" 2>/dev/null)
EXPECTED=$((BEFORE + 1))
[ "$COUNT" != "$EXPECTED" ] && { echo "FAIL: expected $EXPECTED photos, got $COUNT"; exit 1; }
echo "OK (count=$COUNT)"

# 5. Verify storage path format (human-readable YYYY/YYYY-MM/ structure)
echo -n "5. Storage path check... "
RESP=$(curl -s -X GET "$BASE/photos/$PHOTO_ID" -H "$AUTH")
# The photo should have a filename with date format
FILENAME=$(echo "$RESP" | python3 -c "import sys,json; print(json.load(sys.stdin)['data']['filename'])" 2>/dev/null)
echo "$FILENAME" | grep -qE '^[0-9]{4}-[0-9]{2}-[0-9]{2}_[0-9]{6}_' || { echo "FAIL: filename format wrong: $FILENAME"; exit 1; }
echo "OK ($FILENAME)"

# 6. Create album
echo -n "6. Create album... "
RESP=$(curl -s -X POST "$BASE/albums" \
  -H "$AUTH" \
  -H "Content-Type: application/json" \
  -d '{"name":"Smoke Test Album"}')
ALBUM_ID=$(echo "$RESP" | python3 -c "import sys,json; print(json.load(sys.stdin)['data']['id'])" 2>/dev/null)
[ -z "$ALBUM_ID" ] && { echo "FAIL: no album id"; exit 1; }
echo "OK (id=$ALBUM_ID)"

# 7. Add photo to album
echo -n "7. Add photo to album... "
RESP=$(curl -s -X POST "$BASE/albums/$ALBUM_ID/photos" \
  -H "$AUTH" \
  -H "Content-Type: application/json" \
  -d "{\"photo_ids\":[$PHOTO_ID]}")
echo "$RESP" | grep -q '"error"' && { echo "FAIL: $RESP"; exit 1; }
echo "OK"

# 8. Favorite toggle
echo -n "8. Toggle favorite... "
RESP=$(curl -s -X PATCH "$BASE/photos/$PHOTO_ID/favorite" -H "$AUTH")
FAV=$(echo "$RESP" | python3 -c "import sys,json; print(json.load(sys.stdin)['data']['is_favorite'])" 2>/dev/null)
[ "$FAV" != "True" ] && { echo "FAIL: expected favorite=True, got $FAV"; exit 1; }
echo "OK (fav=$FAV)"

# 9. Content-sniffing: reject non-image upload
echo -n "9. Reject non-image... "
RESP=$(curl -s -X POST "$BASE/photos/upload" \
  -H "$AUTH" \
  -F "file=@$FAKE_IMAGE;type=image/jpeg")
echo "$RESP" | grep -q 'only image' || { echo "FAIL: expected rejection, got $RESP"; exit 1; }
echo "OK"

# 10. Soft delete
echo -n "10. Soft delete... "
RESP=$(curl -s -X DELETE "$BASE/photos/$PHOTO_ID" -H "$AUTH")
echo "$RESP" | grep -q '"error"' && { echo "FAIL: $RESP"; exit 1; }
echo "OK"

# 11. Verify deleted from timeline
echo -n "11. Verify deleted... "
RESP=$(curl -s -X GET "$BASE/photos" -H "$AUTH")
COUNT=$(echo "$RESP" | python3 -c "import sys,json; print(len(json.load(sys.stdin)['data']))" 2>/dev/null)
[ "$COUNT" != "$BEFORE" ] && { echo "FAIL: expected $BEFORE photos after delete, got $COUNT"; exit 1; }
echo "OK (count=$COUNT)"

# 12. Verify in trash
echo -n "12. Check trash... "
RESP=$(curl -s -X GET "$BASE/photos/trash" -H "$AUTH")
TRASH_COUNT=$(echo "$RESP" | python3 -c "import sys,json; print(len(json.load(sys.stdin)['data']))" 2>/dev/null)
[ "$TRASH_COUNT" -lt "1" ] && { echo "FAIL: expected at least 1 in trash, got $TRASH_COUNT"; exit 1; }
echo "OK (trash=$TRASH_COUNT)"

# 13. Restore
echo -n "13. Restore photo... "
RESP=$(curl -s -X POST "$BASE/photos/$PHOTO_ID/restore" -H "$AUTH")
echo "$RESP" | grep -q '"error"' && { echo "FAIL: $RESP"; exit 1; }
echo "OK"

# 14. Verify restored
echo -n "14. Verify restored... "
RESP=$(curl -s -X GET "$BASE/photos" -H "$AUTH")
COUNT=$(echo "$RESP" | python3 -c "import sys,json; print(len(json.load(sys.stdin)['data']))" 2>/dev/null)
[ "$COUNT" != "$EXPECTED" ] && { echo "FAIL: expected $EXPECTED photos after restore, got $COUNT"; exit 1; }
echo "OK (count=$COUNT)"

# Cleanup
rm -rf "$DATA_DIR"

echo ""
echo "=== SMOKE TEST PASSED ==="
