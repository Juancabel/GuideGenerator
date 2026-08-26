#!/usr/bin/env bash
#
# build.sh — builds the PDF without GNU Make.
#
# Equivalent to the Makefile; use whichever you prefer.
#
# Architecture adapted from github.com/alexmodrono/typst-pandoc
# (MIT, (c) 2025 Alex). See CREDITS.md.
#
#   ./build.sh          build the PDF
#   ./build.sh check    verify dependencies
#   ./build.sh typ      stop after generating output/*.typ
#   ./build.sh clean    remove output/
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT_DIR="$ROOT/output"
DOC_NAME="rust-guide"

TYP_FILE="$OUTPUT_DIR/$DOC_NAME.typ"
PDF_FILE="$OUTPUT_DIR/$DOC_NAME.pdf"

# ORDER MATTERS — see the note in the Makefile. crossrefs must run before the
# filters that serialise their own contents to Typst.
FILTERS=(
  "filters/images.lua"
  "filters/crossrefs.lua"
  "filters/listings.lua"
  "filters/tables.lua"
  "filters/callouts.lua"
)

check_deps() {
  local ok=0

  if command -v pandoc >/dev/null 2>&1; then
    echo "pandoc: $(pandoc --version | head -1)"
  else
    echo "MISSING pandoc (need >= 3.0 for --to=typst)"; ok=1
  fi

  if command -v typst >/dev/null 2>&1; then
    echo "typst:  $(typst --version)"
  else
    echo "MISSING typst (need >= 0.13)"; ok=1
  fi

  return $ok
}

build() {
  mkdir -p "$OUTPUT_DIR"

  # Chapters in filename order — the numeric prefixes set the order.
  mapfile -t CONTENTS < <(find "$ROOT/contents" -type f -name '*.md' | sort)
  if [ ${#CONTENTS[@]} -eq 0 ]; then
    echo "No .md files found in contents/" >&2
    exit 1
  fi

  local filter_args=()
  for f in "${FILTERS[@]}"; do
    filter_args+=("--lua-filter=$ROOT/$f")
  done

  echo "Generating Typst source..."
  pandoc "${CONTENTS[@]}" \
    --from=markdown+fenced_divs+bracketed_spans+implicit_figures+table_captions \
    --to=typst \
    --metadata-file="$ROOT/metadata.yaml" \
    --template="$ROOT/templates/guide.typ" \
    --resource-path=".:$ROOT/img" \
    "${filter_args[@]}" \
    --output="$TYP_FILE"

  if [ "${1:-}" = "typ" ]; then
    echo "Typst source ready: $TYP_FILE"
    return
  fi

  echo "Compiling Typst -> PDF..."
  typst compile --root="$ROOT" "$TYP_FILE" "$PDF_FILE"
  echo "PDF ready: $PDF_FILE"
}

case "${1:-build}" in
  check) check_deps && echo "All dependencies present." ;;
  clean) rm -rf "$OUTPUT_DIR"; echo "Cleaned." ;;
  typ)   check_deps >/dev/null && build typ ;;
  build) check_deps >/dev/null || { check_deps; exit 1; }; build ;;
  *)     echo "Usage: ./build.sh [build|check|typ|clean]"; exit 1 ;;
esac
