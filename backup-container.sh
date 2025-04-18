#!/usr/bin/env sh
#
# runs inside rclone/rclone container
#  • optional bucket versioning via `rclone backend versioning`
#  • optional ACL via s3api (if available)
#  • many rclone flags to tune checksum, modtime, listing, etc.
#  • colored, timestamped logs, per‑volume error handling

set -eu

# ─── colours + log fns ─────────────────────────────────────────────
BLUE="\033[1;34m"; GREEN="\033[1;32m"
YELLOW="\033[1;33m"; RED="\033[1;31m"; NC="\033[0m"

ts()  { date "+%Y-%m-%d %H:%M:%S"; }
info() { printf "[%s] %b%s%b\n" "$(ts)" "$BLUE" "$*" "$NC"; }
ok()   { printf "[%s] %b%s%b\n" "$(ts)" "$GREEN" "$*" "$NC"; }
warn() { printf "[%s] %b%s%b\n" "$(ts)" "$YELLOW" "$*" "$NC"; }
err()  { printf "[%s] %b%s%b\n" "$(ts)" "$RED" "$*" "$NC"; }

# ─── debug? ────────────────────────────────────────────────────────
[ "${DEBUG:-0}" = "1" ] && set -x

info "starting backup-container.sh"
info "REMOTE              = $REMOTE"
info "MAIN_BUCKET         = $MAIN_BUCKET"
info "PROJECT_NAME        = $PROJECT_NAME"
info "BASE RCLONE_OPTS    = $RCLONE_OPTS"
info "SIZE_ONLY           = ${SIZE_ONLY:-0}"
info "CHECKSUM            = ${CHECKSUM:-0}"
info "UPDATE              = ${UPDATE:-0}"
info "USE_SERVER_MODTIME  = ${USE_SERVER_MODTIME:-0}"
info "FAST_LIST           = ${FAST_LIST:-0}"
info "NO_TRAVERSE         = ${NO_TRAVERSE:-0}"
info "S3_NO_HEAD          = ${S3_NO_HEAD:-0}"
info "S3_UPLOAD_CUTOFF    = ${S3_UPLOAD_CUTOFF:-}"
info "S3_CHUNK_SIZE       = ${S3_CHUNK_SIZE:-}"
info "S3_UPLOAD_CONCURRENCY= ${S3_UPLOAD_CONCURRENCY:-}"
info "ENABLE_VERSIONING   = ${ENABLE_VERSIONING:-0}"
info "ENABLE_ACL          = ${ENABLE_ACL:-0}"

# ─── try versioning via backend command ───────────────────────────
if [ "${ENABLE_VERSIONING:-0}" = "1" ]; then
  if rclone help backend versioning >/dev/null 2>&1; then
    info "enabling versioning on bucket"
    if rclone backend versioning "$REMOTE:$MAIN_BUCKET" Enabled; then
      ok "versioning enabled"
    else
      warn "versioning call failed; continuing"
    fi
  else
    warn "`backend versioning` unsupported; skipping versioning"
  fi
fi

# ─── optional ACL via s3api ───────────────────────────────────────
if [ "${ENABLE_ACL:-0}" = "1" ]; then
  if rclone help s3api >/dev/null 2>&1; then
    info "setting bucket ACL to public-read-write"
    if rclone s3api put-bucket-acl \
         --bucket "$MAIN_BUCKET" \
         --acl public-read-write; then
      ok "ACL set"
    else
      warn "ACL call failed; continuing"
    fi
  else
    warn "s3api unsupported; skipping ACL"
  fi
fi

# ─── build sync flags from .env toggles ───────────────────────────
SYNC_FLAGS="$RCLONE_OPTS"
[ "${SIZE_ONLY:-0}" = "1" ]          && SYNC_FLAGS="$SYNC_FLAGS --size-only"
[ "${CHECKSUM:-0}" = "1" ]           && SYNC_FLAGS="$SYNC_FLAGS --checksum"
[ "${UPDATE:-0}" = "1" ]             && SYNC_FLAGS="$SYNC_FLAGS --update"
[ "${USE_SERVER_MODTIME:-0}" = "1" ] && SYNC_FLAGS="$SYNC_FLAGS --use-server-modtime"
[ "${FAST_LIST:-0}" = "1" ]          && SYNC_FLAGS="$SYNC_FLAGS --fast-list"
[ "${NO_TRAVERSE:-0}" = "1" ]        && SYNC_FLAGS="$SYNC_FLAGS --no-traverse"
[ "${S3_NO_HEAD:-0}" = "1" ]         && SYNC_FLAGS="$SYNC_FLAGS --s3-no-head"

# multipart tuning if set
[ -n "${S3_UPLOAD_CUTOFF:-}" ]    && SYNC_FLAGS="$SYNC_FLAGS --s3-upload-cutoff ${S3_UPLOAD_CUTOFF}"
[ -n "${S3_CHUNK_SIZE:-}" ]       && SYNC_FLAGS="$SYNC_FLAGS --s3-chunk-size ${S3_CHUNK_SIZE}"
[ -n "${S3_UPLOAD_CONCURRENCY:-}" ] && SYNC_FLAGS="$SYNC_FLAGS --s3-upload-concurrency ${S3_UPLOAD_CONCURRENCY}"

info "final sync flags: $SYNC_FLAGS"

# ─── sync each volume ─────────────────────────────────────────────
failed=""
for path in /data/*; do
  name=$(basename "$path")
  dest="$REMOTE:$MAIN_BUCKET/$PROJECT_NAME/$name/"
  info "syncing '$name' → '$dest'"
  rclone sync \
    "$path" \
    "$dest" \
    $SYNC_FLAGS \
    --stats 5s \
    --stats-one-line

  rc=$?
  if [ $rc -ne 0 ]; then
    err "sync '$name' failed (code $rc)"
    failed="$failed $name"
  else
    ok "synced '$name'"
  fi
done

# ─── final result ─────────────────────────────────────────────────
if [ -n "$failed" ]; then
  err "volumes failed:$failed"
  exit 1
else
  ok "all sync operations completed successfully"
  exit 0
fi