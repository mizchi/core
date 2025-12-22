#!/bin/bash
# Measure JS bundle sizes for each benchmark package

set -e

cd "$(dirname "$0")/.."

echo "=== Building and measuring JS bundle sizes ==="
echo ""

measure_package() {
    local pkg=$1
    local name=$2

    echo "Building $name..."
    moon build --target js --package "benches_js/$pkg" 2>/dev/null || {
        echo "  Failed to build $name"
        return 1
    }

    local js_file="target/js/release/build/benches_js/$pkg/$pkg.js"
    if [ -f "$js_file" ]; then
        local size=$(wc -c < "$js_file" | tr -d ' ')
        local size_kb=$(echo "scale=2; $size / 1024" | bc)
        local gzip_size=$(gzip -c "$js_file" | wc -c | tr -d ' ')
        local gzip_kb=$(echo "scale=2; $gzip_size / 1024" | bc)
        echo "  $name: ${size_kb} KB (gzip: ${gzip_kb} KB)"
    else
        echo "  $name: JS file not found at $js_file"
    fi
}

echo "| Package | Raw Size | Gzip Size |"
echo "|---------|----------|-----------|"

for pkg in map json double regex; do
    measure_package "$pkg" "$pkg"
done

echo ""
echo "=== Running benchmarks ==="
echo ""

for pkg in map json double regex; do
    echo "--- $pkg ---"
    js_file="target/js/release/build/benches_js/$pkg/$pkg.js"
    if [ -f "$js_file" ]; then
        node "$js_file" 2>/dev/null || echo "Failed to run $pkg"
    fi
    echo ""
done
