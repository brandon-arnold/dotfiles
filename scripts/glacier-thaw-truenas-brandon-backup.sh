#!/usr/bin/env bash
set -euo pipefail

# Thaw and download everything from s3://truenas-brandon-backup (Glacier Deep Archive)
# Files are rclone-crypt encrypted (filenames + content). After download, decrypt with rclone.
#
# Usage:
#   Phase 1 (initiate restore):  ./glacier-thaw-truenas-brandon-backup.sh restore
#   Phase 2 (check status):      ./glacier-thaw-truenas-brandon-backup.sh status
#   Phase 3 (download):          ./glacier-thaw-truenas-brandon-backup.sh download
#   Phase 4 (decrypt):           ./glacier-thaw-truenas-brandon-backup.sh decrypt
#
# Deep Archive Bulk restore takes 5-12 hours. Run 'status' to check before downloading.

BUCKET="truenas-brandon-backup"
REGION="us-west-2"
RESTORE_DAYS=7
RESTORE_TIER="Bulk"
DOWNLOAD_DIR="$HOME/glacier-restore/${BUCKET}"
DECRYPT_DIR="$HOME/glacier-restore/${BUCKET}-decrypted"
MANIFEST="/tmp/${BUCKET}-manifest.txt"

phase_restore() {
    echo "=== Phase 1: Initiating Glacier restore for s3://${BUCKET} ==="
    echo "Tier: ${RESTORE_TIER} | Days: ${RESTORE_DAYS}"
    echo ""

    # Build manifest of all object keys (paginated — may take a few minutes for large buckets)
    echo "Listing all objects (this may take a few minutes)..."
    > "${MANIFEST}"
    local page=0
    local token=""
    while true; do
        page=$((page + 1))
        local args=(
            s3api list-objects-v2
            --bucket "${BUCKET}"
            --region "${REGION}"
            --output json
            --max-items 1000
        )
        [[ -n "$token" ]] && args+=(--starting-token "${token}")

        local result
        result=$(aws "${args[@]}")

        echo "$result" | python3 -c "
import sys, json
data = json.load(sys.stdin)
for obj in data.get('Contents', []):
    print(obj['Key'])
" >> "${MANIFEST}"

        token=$(echo "$result" | python3 -c "
import sys, json
data = json.load(sys.stdin)
print(data.get('NextToken', ''))
" 2>/dev/null)

        local count
        count=$(wc -l < "${MANIFEST}")
        echo -ne "  Listed ${count} objects (page ${page})...\r"

        if [[ -z "$token" ]]; then
            echo ""
            break
        fi
    done

    local total
    total=$(wc -l < "${MANIFEST}")
    echo "Found ${total} objects."
    echo ""

    local restored=0 skipped=0 failed=0
    while IFS= read -r key; do
        [[ -z "$key" ]] && continue
        if aws s3api restore-object \
            --bucket "${BUCKET}" \
            --region "${REGION}" \
            --key "${key}" \
            --restore-request "{\"Days\":${RESTORE_DAYS},\"GlacierJobParameters\":{\"Tier\":\"${RESTORE_TIER}\"}}" \
            2>/dev/null; then
            restored=$((restored + 1))
        else
            # Already restored or restore in progress
            skipped=$((skipped + 1))
        fi
        local count
        count=$((restored + skipped + failed))
        if (( count % 100 == 0 )); then
            echo "  Progress: ${count}/${total} (restored: ${restored}, skipped: ${skipped})"
        fi
    done < "${MANIFEST}"

    echo ""
    echo "=== Restore initiated ==="
    echo "  New restores: ${restored}"
    echo "  Already restoring/restored: ${skipped}"
    echo "  Failed: ${failed}"
    echo ""
    echo "Bulk restore takes 5-12 hours. Run '$0 status' to check progress."
}

phase_status() {
    echo "=== Checking restore status for s3://${BUCKET} ==="

    if [[ ! -f "${MANIFEST}" ]]; then
        echo "No manifest found. Rebuilding..."
        aws s3api list-objects-v2 \
            --bucket "${BUCKET}" \
            --region "${REGION}" \
            --query 'Contents[].Key' \
            --output text \
        | tr '\t' '\n' > "${MANIFEST}"
    fi

    local total pending ready not_started
    total=$(wc -l < "${MANIFEST}")
    pending=0; ready=0; not_started=0

    # Sample first 50 objects to estimate status
    local sample_size=50
    local checked=0
    while IFS= read -r key; do
        [[ -z "$key" ]] && continue
        ((checked++))
        (( checked > sample_size )) && break

        local head
        head=$(aws s3api head-object \
            --bucket "${BUCKET}" \
            --region "${REGION}" \
            --key "${key}" \
            2>/dev/null) || continue

        local restore
        restore=$(echo "$head" | python3 -c "import sys,json; print(json.load(sys.stdin).get('Restore',''))" 2>/dev/null)

        if [[ -z "$restore" ]]; then
            ((not_started++))
        elif echo "$restore" | grep -q 'ongoing-request="true"'; then
            ((pending++))
        elif echo "$restore" | grep -q 'ongoing-request="false"'; then
            ((ready++))
        fi
    done < "${MANIFEST}"

    echo "Sampled ${checked} of ${total} objects:"
    echo "  Ready to download: ${ready}"
    echo "  Restore in progress: ${pending}"
    echo "  Not started: ${not_started}"
    echo ""
    if (( ready == checked )); then
        echo "✅ All sampled objects are ready! Run '$0 download' to fetch them."
    elif (( not_started == checked )); then
        echo "❌ No restores initiated. Run '$0 restore' first."
    else
        echo "⏳ Still thawing. Check back in a bit."
    fi
}

phase_download() {
    echo "=== Phase 3: Downloading restored objects from s3://${BUCKET} ==="
    echo "Destination: ${DOWNLOAD_DIR}"
    mkdir -p "${DOWNLOAD_DIR}"

    # aws s3 sync handles the download; objects not yet restored will fail gracefully
    aws s3 sync \
        "s3://${BUCKET}/" \
        "${DOWNLOAD_DIR}/" \
        --region "${REGION}" \
        --force-glacier-transfer

    echo ""
    echo "=== Download complete ==="
    echo "Files in: ${DOWNLOAD_DIR}"
    echo ""
    echo "These files are rclone-crypt encrypted."
    echo "Run '$0 decrypt' to decrypt (you'll need your rclone crypt password)."
}

phase_decrypt() {
    echo "=== Phase 4: Decrypt with rclone ==="
    echo ""
    echo "You need an rclone remote configured with your crypt password."
    echo "If you don't have one set up, create one:"
    echo ""
    echo "  rclone config"
    echo "    > New remote → name: glacier-crypt"
    echo "    > Type: crypt"
    echo "    > Remote: ${DOWNLOAD_DIR}"
    echo "    > Filename encryption: standard (or whatever was used)"
    echo "    > Enter your password/password2"
    echo ""
    echo "Then run:"
    echo "  mkdir -p '${DECRYPT_DIR}'"
    echo "  rclone copy glacier-crypt: '${DECRYPT_DIR}/' --progress"
    echo ""

    # If there's already a matching rclone remote, try to detect it
    if command -v rclone &>/dev/null; then
        echo "Detected rclone remotes:"
        rclone listremotes 2>/dev/null || echo "  (none)"
        echo ""
        read -rp "Enter rclone crypt remote name (or 'skip' to do it manually): " remote
        if [[ "$remote" != "skip" && -n "$remote" ]]; then
            remote="${remote%:}"
            mkdir -p "${DECRYPT_DIR}"
            echo "Decrypting..."
            rclone copy "${remote}:" "${DECRYPT_DIR}/" --progress
            echo ""
            echo "=== Decryption complete ==="
            echo "Decrypted files in: ${DECRYPT_DIR}"
        fi
    fi
}

case "${1:-}" in
    restore)  phase_restore ;;
    status)   phase_status ;;
    download) phase_download ;;
    decrypt)  phase_decrypt ;;
    *)
        echo "Usage: $0 {restore|status|download|decrypt}"
        echo ""
        echo "  restore  - Initiate Glacier Bulk restore (5-12 hours)"
        echo "  status   - Check how many objects are thawed"
        echo "  download - Download all restored objects"
        echo "  decrypt  - Decrypt rclone-crypt files"
        exit 1
        ;;
esac
