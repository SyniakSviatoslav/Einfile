#!/bin/sh
# SPDX-License-Identifier: MIT OR Apache-2.0
# Publish the eight library crates to crates.io in dependency order. IRREVERSIBLE: a published
# version can be yanked but never deleted or re-uploaded. Needs `cargo login` first.
#
#   tools/release/publish.sh            dry run: einfile-crc fully, the rest packaged and built
#                                       against local copies of their einfile dependencies
#   tools/release/publish.sh --publish  the real upload, one crate at a time; cargo waits until
#                                       each is in the index before the next one resolves it
#
# Not published: einfile-reader (the wasm reader, embedded by einstore and pinned by hash),
# einfile-ffi (a cdylib for the C ABI and the Python binding), einfile-log-kani (Kani harnesses).
set -eu
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
CRATES="einfile-crc einfile-image einfile-kv einfile-log einfile-io einstore einfile-sig-mldsa einfile-sync"
MODE="${1:-}"
[ -z "$(git -C "$ROOT" status --porcelain)" ] || [ "$MODE" != --publish ] || { echo "publish: the tree is dirty; commit first"; exit 2; }
patch=""
for c in $CRATES; do
  cd "$ROOT/crates/$c"
  if [ "$MODE" = --publish ]; then
    echo "publish: $c"
    cargo publish
  elif [ "$c" = einfile-crc ]; then
    cargo publish --dry-run --allow-dirty
  else
    # shellcheck disable=SC2086
    cargo package --allow-dirty $patch
    git -C "$ROOT" checkout --quiet -- Cargo.lock 2>/dev/null || true
    git -C "$ROOT" checkout --quiet -- "crates/$c/Cargo.lock" 2>/dev/null || true
  fi
  patch="$patch --config patch.crates-io.$c.path=\"$ROOT/crates/$c\""
done
echo "publish: done ($MODE)"
