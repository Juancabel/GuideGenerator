# =============================================================================
#  Markdown -> Pandoc -> Typst -> PDF
#
#  Architecture adapted from github.com/alexmodrono/typst-pandoc
#  (MIT, (c) 2025 Alex). See CREDITS.md.
#
#    make          build the PDF
#    make watch    rebuild on every save (needs fswatch or inotifywait)
#    make typ      stop after generating the .typ, for debugging the template
#    make clean    remove build artifacts
#    make check    verify pandoc and typst are installed and new enough
# =============================================================================

OUTPUT_DIR   := output
DOC_NAME     := rust-guide

# Chapters, in filename order. The numeric prefixes are what set the order,
# so insert a chapter by numbering it between its neighbours (e.g. 015.).
CONTENTS     := $(shell find contents -type f -name '*.md' | sort)

METADATA     := metadata.yaml
TEMPLATE     := templates/guide.typ
BIBLIOGRAPHY := bibliography.bib
PROJECT_ROOT := $(CURDIR)

TYP_FILE     := $(OUTPUT_DIR)/$(DOC_NAME).typ
PDF_FILE     := $(OUTPUT_DIR)/$(DOC_NAME).pdf

# ORDER MATTERS. listings/tables/callouts each serialise their contents to
# Typst themselves, which takes those contents out of Pandoc's AST — so any
# filter that needs to see inside them must run FIRST. crossrefs therefore
# runs before them, or citations inside a callout escape as #cite("key")
# and Typst rejects them.
FILTERS := \
	--lua-filter=filters/images.lua \
	--lua-filter=filters/crossrefs.lua \
	--lua-filter=filters/listings.lua \
	--lua-filter=filters/tables.lua \
	--lua-filter=filters/callouts.lua

# NOTE: deliberately no --citeproc. Typst formats the bibliography itself
# (see the #bibliography call at the bottom of templates/guide.typ). Adding
# --citeproc here would produce two reference lists.
PANDOC_FLAGS := \
	--from=markdown+fenced_divs+bracketed_spans+implicit_figures+table_captions \
	--to=typst \
	--metadata-file=$(METADATA) \
	--template=$(TEMPLATE) \
	--resource-path=.:img \
	$(FILTERS)

.PHONY: all
all: pdf

.PHONY: pdf
pdf: $(PDF_FILE)
	@echo "PDF ready: $(PDF_FILE)"

$(PDF_FILE): $(TYP_FILE) $(BIBLIOGRAPHY) | $(OUTPUT_DIR)
	@echo "Compiling Typst -> PDF..."
	@typst compile --root="$(PROJECT_ROOT)" "$<" "$@"

.PHONY: typ
typ: $(TYP_FILE)
	@echo "Typst source ready: $(TYP_FILE)"

$(TYP_FILE): $(CONTENTS) $(METADATA) $(TEMPLATE) $(wildcard filters/*.lua) | $(OUTPUT_DIR)
	@echo "Generating Typst source..."
	@pandoc $(CONTENTS) $(PANDOC_FLAGS) --output="$@"

$(OUTPUT_DIR):
	@mkdir -p $(OUTPUT_DIR)

.PHONY: clean
clean:
	@rm -rf $(OUTPUT_DIR)
	@echo "Cleaned."

# -----------------------------------------------------------------------------
#  Watch mode. Uses fswatch (macOS: brew install fswatch) or
#  inotifywait (Linux: apt install inotify-tools), whichever is present.
# -----------------------------------------------------------------------------
.PHONY: watch
watch: pdf
	@echo "Watching for changes. Ctrl-C to stop."
	@if command -v fswatch >/dev/null 2>&1; then \
		fswatch -o contents/ templates/ filters/ $(METADATA) $(BIBLIOGRAPHY) | \
			while read -r _; do $(MAKE) --no-print-directory pdf || true; done; \
	elif command -v inotifywait >/dev/null 2>&1; then \
		while inotifywait -qq -r -e modify,create,delete contents/ templates/ filters/ $(METADATA) $(BIBLIOGRAPHY); do \
			$(MAKE) --no-print-directory pdf || true; \
		done; \
	else \
		echo "Install fswatch or inotify-tools for watch mode."; exit 1; \
	fi

# -----------------------------------------------------------------------------
#  Dependency check
# -----------------------------------------------------------------------------
.PHONY: check
check:
	@command -v pandoc >/dev/null 2>&1 && echo "pandoc: $$(pandoc --version | head -1)" \
		|| echo "MISSING pandoc (need >= 3.0 for --to=typst)"
	@command -v typst  >/dev/null 2>&1 && echo "typst:  $$(typst --version)" \
		|| echo "MISSING typst (need >= 0.13)"
	@command -v fswatch >/dev/null 2>&1 && echo "fswatch: present (make watch available)" \
		|| (command -v inotifywait >/dev/null 2>&1 && echo "inotifywait: present (make watch available)" \
		|| echo "optional: fswatch or inotify-tools, for make watch")
