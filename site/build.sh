#!/usr/bin/env bash
# Build the Ahamkara static site: TS client → JS, then the Rust generator → dist/
set -euo pipefail
cd "$(dirname "$0")"

echo "[1/3] compiling client (typescript)"
npx -y -p typescript@5 tsc -p ts/tsconfig.json

echo "[2/3] building generator (rust)"
cargo build --release --quiet

echo "[3/3] generating site"
./target/release/sitegen
