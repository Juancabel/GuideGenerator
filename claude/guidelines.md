# CLAUDE.md

Instructions for Claude working in this repository.

## What this project is

A build system that turns Markdown into a typeset PDF: title page, table of
contents, list of listings, running headers, numbered code listings, captioned
figures and tables, callout boxes, cross-references, IEEE bibliography.

Pipeline: `contents/*.md` --pandoc--> `output/*.typ` --typst--> `output/*.pdf`

**Deliberately no LaTeX and no third-party Typst `@preview` packages.** Do not
add either. The no-packages rule exists because pinned package versions are
what make a template stop compiling a year later; the upstream project this
was modelled on broke exactly that way.

Current document: an introduction to Rust. The template is subject-agnostic and
is meant to be reused for other guides — never hardcode Rust-specific content
into `templates/` or `filters/`.

## Build commands

| | Windows (this machine) | macOS / Linux |
|---|---|---|
| Build | `.\build.ps1` | `make` |
| Watch | `.\build.ps1 -Watch` | `make watch` |
| Pandoc stage only | `.\build.ps1 -TypOnly` | `make typ` |
| Clean | `.\build.ps1 -Clean` | `make clean` |
| Check deps | `.\build.ps1 -Check` | `make check` |

**Pinned toolchain: Pandoc 3.10.2 and Typst 0.15.1.** These are exact pins, not
minimums — see gotcha 15 for why. When debugging a rendering problem, build
the intermediate `.typ` first and read it — that isolates whether the fault is
in Pandoc/filters or in the Typst template.

**Three build entry points exist** (`Makefile`, `build.ps1`, `build.sh`) and
they duplicate the same flags. If you change the filter list, the Pandoc flags
or `DOC_NAME`, change all three.

## Layout

```
contents/          chapters; NUMERIC FILENAME PREFIX SETS THE ORDER
templates/guide.typ  the only file containing styling; 8 numbered sections
filters/           Lua filters, one job each
metadata.yaml      title, author, colours, fonts, citation style
bibliography.bib   references
img/               figures
output/            build artifacts (gitignored)
```

## Hard-won gotchas — read before editing

These each cost an hour to find. Do not rediscover them.

1. **`$` in `templates/guide.typ` is a Pandoc placeholder, even inside `//`
   comments.** Pandoc fills the template before Typst sees it and does not know
   Typst has comments. A literal dollar must be written `$$`. Writing `$body$`
   in a comment injects the entire document there.

2. **Never put `#` in a `metadata.yaml` value.** Pandoc escapes it to `\#`,
   producing invalid Typst. This is why `accent-color` takes `b7410e`, not
   `#b7410e`.

   The same trap catches `_`, and it bites hardest in **paths**. Pandoc parses
   metadata values as Markdown and escapes an underscore to `\_`; Typst then
   refuses the path with `error: path must not contain a backslash` and a
   misleading hint about Windows path separators. Keep every filename referenced
   from `metadata.yaml` — `cover-image`, `brand-mark`, `brand-logo` — free of
   underscores. Hyphens are safe.

3. **Filter order matters and is not arbitrary.** `listings.lua`, `tables.lua`
   and `callouts.lua` each serialise their contents to Typst via
   `pandoc.write`, which removes those contents from Pandoc's AST. Any filter
   that must see inside them — `crossrefs.lua` — has to run first. Current
   order: `images, crossrefs, listings, tables, callouts`.

4. **Never add `--citeproc`.** Typst formats the bibliography itself via
   `#bibliography()` in the template. Enabling Pandoc's citation processor as
   well produces two reference lists.

5. **Citation output is version-dependent; `crossrefs.lua` normalises it.**
   Pandoc 3.1.x emitted `#cite("key")` — a string — which Typst 0.13+ rejects
   with `error: expected label, found string`. Pandoc 3.10.2 emits native
   `@key` / `@key[p.~4]` instead. `crossrefs.lua` overrides both and always
   emits `#cite(<key>)`, which is valid on every Typst 0.13+. It also routes
   `lst:` / `fig:` / `tbl:` / `sec:` / `eq:` prefixes to Typst cross-references
   rather than citations. Don't remove that; without it the pinned pair happens
   to work, but any Pandoc downgrade breaks the build.

6. **Content inside `#figure(...)` is in code mode and inherits centre
   alignment.** Raw Typst emitted into a figure must be wrapped in `[ ]`, and
   code blocks need `#set align(left)` or every listing renders centred.

7. **Paths resolve against `--root`, not the `.typ` file.** The generated
   `.typ` lives in `output/`, so bare relative paths break. The template
   prefixes bibliography and cover-image paths with `/`; `filters/images.lua`
   does the same for image paths. Keep paths in `metadata.yaml` relative to the
   project root.

8. **`{#tbl:x}` parsing is version-dependent.** Pandoc 3.1.x did NOT parse it
   as a table attribute — the braces survived as literal caption text — so
   `tables.lua` extracts the identifier by hand. Pandoc 3.10.2 parses it
   correctly and attaches the label itself. Both paths are handled; see
   gotcha 14 for why that matters.

9. **`pandoc.Caption` does not exist before Pandoc 3.2.** It exists in 3.10.2,
   but `tables.lua` still uses the plain-table form `{ long = pandoc.Blocks({}) }`
   when clearing a caption, because that works on every version. Calling
   `pandoc.Caption({})` on old Pandoc dies with "attempt to call a nil value".

10. **"unknown font family" warnings are harmless.** Typst logs one per name it
    cannot find and falls through the stack. Defaults are the fonts Typst
    ships with, so a clean checkout builds warning-free.

11. **`build.ps1` must stay pure ASCII and keep its UTF-8 BOM.** Windows
    PowerShell 5.1 (`powershell.exe`, still the Windows default) reads `.ps1`
    files in the system ANSI codepage unless the file starts with a BOM. An em
    dash stored as UTF-8 (`E2 80 94`) is then decoded as CP1252, where byte
    `0x94` is a smart closing quote — and PowerShell treats smart quotes as
    string delimiters. The failure looks nothing like the cause: "The string is
    missing the terminator" plus cascading "missing closing '}'" errors,
    reported at lines far from the offending character. Write `-`, not `—`, in
    `build.ps1`. Never add a BOM to `build.sh` — it breaks the shebang.

12. **Line endings are pinned by `.gitattributes`.** `build.sh`, `Makefile` and
    `filters/*.lua` are LF; `*.ps1` is CRLF. A Windows checkout with
    `core.autocrlf=true` would otherwise rewrite `build.sh` to CRLF and break
    it under WSL, Git Bash and CI with `bad interpreter: /usr/bin/env bash^M`.

13. **Never call Pandoc's built-in partials from the template.** This template
    used to pull helper definitions in with `$definitions.typst()$`. That
    partial was REMOVED in later Pandoc, and the build then dies at the Pandoc
    stage with `Could not find data file 'templates/definitions.typst'`.
    Section 2 of `templates/guide.typ` now defines every helper itself, because
    which helpers Pandoc emits also changes between versions:

    | Pandoc | block quote | rule | note |
    |--------|-------------|------|------|
    | 3.0 - 3.5 | `#blockquote[...]` | `#horizontalrule` | `#endnote(n, ...)` |
    | 3.6+ | `#quote(block: true)[...]` | `#divider()` | `#footnote[...]` |

    All of them are defined, so the template is version-independent. Verified
    building on the pinned Pandoc 3.10.2 with Typst 0.15.1, and on Pandoc
    3.1.3 for the helper-name coverage specifically (3.1.3 is otherwise
    unusable with Typst 0.15 - see gotcha 15). If you ever add a Pandoc partial call back in, you re-introduce a
    dependency on one specific Pandoc version.

14. **`tables.lua` MUST stay conditional.** Pandoc 3.10.2 already wraps every
    captioned table in `#figure(align(center)[#table(...)], caption: [...],
    kind: table)` with the `<tbl:x>` label attached — exactly what this filter
    was written to produce. Running the filter as well nests a figure inside a
    figure, and Typst then advances the table counter TWICE per table: you get
    Table 1, Table 3, Table 5, and every `[@tbl:x]` reference points at the
    wrong number. The build stays green, so this is only visible by looking at
    the PDF. The filter probes the writer at load time (renders a throwaway
    table and checks for `#figure`) and disables itself when Pandoc already
    does the work. Do not replace that probe with a hardcoded version check —
    the changeover happened somewhere between 3.1 and 3.10 and the exact
    boundary is not documented.

15. **Do not downgrade Pandoc below the pinned version.** Pandoc 3.1.x emits
    Typst symbol names that Typst 0.15 renamed: `\partial` becomes `diff`
    (now `partial`) and `=` becomes `eq`. Display math then fails to compile
    with `error: unknown variable: diff`. Pandoc 3.10.2 emits the current
    names. This is the concrete reason the versions are pinned rather than
    given as minimums.

16. **All three build entry points pass `--wrap=none` to Pandoc — keep it.**
    Without it, Pandoc's default `--wrap=auto` hard-wraps the generated
    `.typ` at ~72 columns. A wrap point can land inside any multi-word value
    interpolated from `metadata.yaml` (a font name like `"Segoe UI"`, a
    `brand-name`, an author name), turning a single Typst string literal into
    two lines and breaking the string. The build fails at the Typst stage
    with a confusing error (or, worse, silently drops half the value if the
    break lands somewhere else). This is why `font-body`/`font-sans`/
    `font-mono` in `metadata.yaml` are YAML lists rather than one
    comma-separated string, too: the template fills them with `$for(...)$`
    (the same pattern used for `author`), so each font name is its own
    interpolation and never depends on where a line-wrap would fall.

## Conventions

- **Adding a chapter:** create `contents/NNN.name.md`. Number in tens so
  chapters can be inserted later without renaming. No index file to update.
- **Code listings:** a `caption=` attribute promotes a code block to a numbered
  Listing. Without one it stays a plain code block.
  ` ```{.rust #lst:name caption="Description"} `
- **Cross-references:** `[@lst:x]`, `[@fig:x]`, `[@tbl:x]` — handled by
  `crossrefs.lua`, which routes known prefixes to Typst refs and everything
  else to citations.
- **Callouts:** fenced divs — `::: note`, `::: tip`, `::: warning`,
  `::: danger`.
- **Prose style in `contents/`:** formal, technical, properly cited throughout.
  The audience is external readers, not internal notes. Every non-obvious
  factual claim gets a citation from `bibliography.bib`.

## Verifying changes

After changing the template or a filter, always rebuild and **look at the
PDF**, not just the exit code. Several of the bugs above produced a clean build
and a wrong-looking page. Rendering pages to images and inspecting them is the
only reliable check.

## Attribution

Architecture adapted from github.com/alexmodrono/typst-pandoc (MIT, (c) 2025
Alex). See `CREDITS.md`. Keep that attribution intact in `README.md`,
`CREDITS.md` and the source file headers.
