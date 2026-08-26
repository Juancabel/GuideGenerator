# Technical Guide Toolchain — Markdown → Typst → PDF

Write your guide in Markdown. Get a typeset PDF with a title page, table of
contents, list of listings, running headers, numbered and syntax-highlighted
code listings, captioned figures and tables, callout boxes, cross-references
and an IEEE bibliography.

**No LaTeX.** No external Typst packages. Everything runs locally and is free.

> **Prior art.** The build architecture used here — numbered chapter files
> concatenated at build time, a two-stage Pandoc → Typst → PDF pipeline, and a
> directory of small Lua filters — comes from
> [alexmodrono/typst-pandoc](https://github.com/alexmodrono/typst-pandoc).
> See [Credits and prior art](#credits-and-prior-art) for what was taken and
> what is original.

The sample content is an introduction to Rust, but the template mentions Rust
nowhere — swap the files in `contents/` and the fields in `metadata.yaml` and
the same pipeline produces a guide about anything.

---

## Table of contents

1. [How it works](#how-it-works)
2. [Installation](#installation)
   - [Windows](#windows)
   - [macOS](#macos)
   - [Linux](#linux)
   - [Verifying](#verifying-the-install)
3. [Building](#building)
4. [Writing content](#writing-content)
5. [Customising the look](#customising-the-look)
6. [Starting a new guide](#starting-a-new-guide)
7. [Making this a git repo](#making-this-a-git-repo)
8. [Things that will bite you](#things-that-will-bite-you)
9. [Project layout](#project-layout)
10. [Credits and prior art](#credits-and-prior-art)

---

## How it works

Three stages, two tools:

```
contents/*.md  ──pandoc──>  output/guide.typ  ──typst──>  output/guide.pdf
                   ▲                                ▲
          templates/guide.typ                   --root=.
          filters/*.lua                    (resolves img/ and .bib)
          metadata.yaml
```

**Pandoc** parses your Markdown, runs the Lua filters over it, pours the result
into the Typst template, and writes a `.typ` file. **Typst** compiles that to
PDF. Typst is a modern typesetting system — the role LaTeX would normally play,
without the 5 GB install or the error messages.

Keeping the two stages separate is what makes this pleasant to debug: if
something looks wrong, `make typ` stops after stage one so you can read the
generated Typst.

---

## Installation

You need exactly two programs: **Pandoc 3.10.2** and **Typst 0.15.1**. Those
are the versions this project is verified against.

### Windows

The `winget` package manager is built into Windows 10 (1809+) and Windows 11.
Open PowerShell and run:

```powershell
winget install --id JohnMacFarlane.Pandoc --version 3.10.2
winget install --id Typst.Typst --version 0.15.1
```

**Close and reopen PowerShell afterwards.** `winget` writes the new `PATH` into
the registry, but a shell that was already open keeps the copy it started with
— so a freshly installed Pandoc looks missing until you restart the terminal.
To reload `PATH` without closing the window:

```powershell
$env:Path = [Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [Environment]::GetEnvironmentVariable('Path','User')
```

`build.ps1` handles this for you: if a tool is not on `PATH` it reloads from the
registry and then probes the usual winget, Scoop, Chocolatey and Cargo install
locations, calling the tool by full path if it finds one. It tells you when it
had to do that, so you know your shell still needs fixing.

If PowerShell reports *"The string is missing the terminator"* in `build.ps1`,
the file has lost its UTF-8 BOM or picked up a non-ASCII character. Windows
PowerShell 5.1 reads `.ps1` in the system ANSI codepage without a BOM, and a
UTF-8 em dash decodes into a smart quote that PowerShell treats as a string
delimiter. Keep `build.ps1` ASCII-only.

<details>
<summary>Alternatives if you don't have or want winget</summary>

**Scoop:**

```powershell
scoop install pandoc@3.10.2 typst@0.15.1
```

**Chocolatey:**

```powershell
choco install pandoc --version=3.10.2
```

Chocolatey has no Typst package; download `typst-x86_64-pc-windows-msvc.zip`
from the [Typst 0.15.1 release](https://github.com/typst/typst/releases/tag/v0.15.1),
extract it, and put `typst.exe` somewhere on your `PATH`.

**Manual:** install Pandoc 3.10.2 from
<https://github.com/jgm/pandoc/releases/tag/3.10.2> and Typst 0.15.1 from
<https://github.com/typst/typst/releases/tag/v0.15.1>.

</details>

#### You do not need `make` on Windows

GNU Make isn't part of Windows, so this project ships `build.ps1`, which does
everything the `Makefile` does. Use that instead.

The first time you run a PowerShell script, Windows may block it. If you see
*"running scripts is disabled on this system"*, allow it for the current
session only:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
```

That lasts until you close the window and changes nothing permanently.

<details>
<summary>If you'd rather use `make` anyway</summary>

Any of these give you a working `make`:

- **Git Bash** (ships with Git for Windows) — then `winget install GnuWin32.Make`
- **WSL** — `wsl --install`, then follow the Linux instructions inside it
- **Scoop** — `scoop install make`

</details>

### macOS

With [Homebrew](https://brew.sh):

```bash
brew install pandoc typst
brew install fswatch      # optional, enables `make watch`
```

Homebrew installs its current formula versions. Confirm they match Pandoc
3.10.2 and Typst 0.15.1 with the verification command below; if they do not,
install those versions from the projects' release pages instead.

`make` is already present on macOS via the Xcode command line tools. If
`make` reports it's missing, run `xcode-select --install`.

### Linux

**Typst** is not in most distribution repositories yet. The reliable route is
the official binary:

```bash
curl -fsSL https://github.com/typst/typst/releases/download/v0.15.1/typst-x86_64-unknown-linux-musl.tar.xz \
  | tar -xJ
sudo mv typst-x86_64-unknown-linux-musl/typst /usr/local/bin/
```

If you have a Rust toolchain, `cargo install --locked --version 0.15.1 typst-cli`
works too.

**Pandoc** — install version 3.10.2. Older LTS releases ship 2.x, which will
fail with an unhelpful error, while newer versions have not been verified here.

<details open>
<summary>Debian / Ubuntu</summary>

Check what your repo has first:

```bash
apt-cache policy pandoc
```

If the repository does not provide 3.10.2, install the official `.deb` instead:

```bash
curl -fsSLO https://github.com/jgm/pandoc/releases/download/3.10.2/pandoc-3.10.2-1-amd64.deb
sudo dpkg -i pandoc-*-amd64.deb
```

For other architectures, use the matching Pandoc 3.10.2 asset from
<https://github.com/jgm/pandoc/releases/tag/3.10.2>.

Optional, for `make watch`: `sudo apt install inotify-tools`

</details>

<details>
<summary>Fedora</summary>

```bash
sudo dnf install pandoc
sudo dnf install inotify-tools      # optional, for make watch
```

Use the Pandoc 3.10.2 and Typst 0.15.1 release assets if the repository
versions do not match the pinned versions above.

</details>

<details>
<summary>Arch</summary>

```bash
sudo pacman -S pandoc-cli typst
sudo pacman -S inotify-tools        # optional, for make watch
```

Arch packages both, but rolling packages may not match the pinned versions;
use the release assets above when they do not.

</details>

### Verifying the install

```bash
make check          # macOS / Linux
.\build.ps1 -Check  # Windows
```

You want to see Pandoc 3.10.2 and Typst 0.15.1. Other versions have not been
verified and may fail in confusing ways.

**No fonts to install.** The template defaults to the two typefaces Typst ships
with, so a fresh clone builds warning-free on any machine.

---

## Building

| | macOS / Linux | Windows |
|---|---|---|
| Build the PDF | `make` | `.\build.ps1` |
| Rebuild on save | `make watch` | `.\build.ps1 -Watch` |
| Stop after the `.typ` | `make typ` | `.\build.ps1 -TypOnly` |
| Delete build output | `make clean` | `.\build.ps1 -Clean` |
| Check dependencies | `make check` | `.\build.ps1 -Check` |

There's also `./build.sh` for macOS/Linux if you'd rather not use Make.

The PDF lands in `output/`. Leave `make watch` (or `.\build.ps1 -Watch`)
running in one window with your PDF viewer open beside it — most viewers reload
automatically and you get a live preview as you type.

---

## Writing content

Standard Markdown, plus four additions.

### Chapters

Drop a `.md` file in `contents/`. **The filename prefix sets the order**, and
nothing else does — there's no index file to maintain.

```
contents/
  010.introduction.md
  015.installation.md     <- inserted later, no renaming needed
  020.ownership.md
  030.error-handling.md
```

Number in tens so you can always slot something in between.

A `#` heading starts a chapter (new page, big numeral). `##` and `###` are
sections and subsections, numbered `1.1`, `1.1.1`.

### Code listings

Give a code block a caption and it becomes a numbered **Listing**, appears in
the List of Listings, and can be cross-referenced. Without a caption you get a
plain styled code block.

````markdown
```{.rust #lst:hello caption="A complete Rust program"}
fn main() {
    println!("Hello, world!");
}
```
````

Reference it with `[@lst:hello]` → renders as "Listing 1".

Syntax highlighting is built into Typst and covers ~170 languages. Set the
class to `.rust`, `.python`, `.go`, `.sql`, `.bash`, `.toml`, `.json` and so on.

Line numbers are on by default — set `line-numbers: false` in `metadata.yaml`
to turn them off.

### Figures

```markdown
![The caption goes here.](img/diagram.svg){#fig:diagram width=88%}
```

Reference with `[@fig:diagram]`. SVG, PNG and JPEG all work. Prefer SVG for
diagrams — it stays sharp at any zoom and prints cleanly.

### Tables

```markdown
| Type    | Size |
|---------|------|
| `i32`   | 4    |

: Integer widths {#tbl:widths}
```

The `:` line is the caption. Reference with `[@tbl:widths]`.

### Callouts

```markdown
::: warning
Never call `unwrap()` on a `Result` in production code.
:::
```

Four kinds: `note`, `tip`, `warning`, `danger`. With a custom heading:

```markdown
::: {.note title="Before you begin"}
Install the toolchain first.
:::
```

### Citations

Add BibTeX entries to `bibliography.bib`, cite them with `[@klabnik2023]`, and
the reference list builds itself in citation order. With a locator:
`[@klabnik2023, p. 84]`.

Change the style in `metadata.yaml` via `csl-style`. Typst ships `ieee`, `apa`,
`mla`, `chicago-author-date`, `chicago-notes`, `council-of-science-editors`,
`harvard-cite-them-right` and more, and also accepts a path to any `.csl` file.

Zotero and Mendeley both export BibTeX directly into `bibliography.bib`.

---

## Customising the look

Most changes are one line in `metadata.yaml`:

| Setting | Effect |
|---------|--------|
| `accent-color` | Headings, links, rules, cover. Hex **without** the `#`. |
| `font-body` / `font-sans` / `font-mono` | Typefaces. Setting `font-sans` to a real sans face is the biggest single visual upgrade. |
| `font-size`, `code-size` | Body and code text size |
| `papersize` | `a4` or `us-letter` |
| `two-sided` | Mirrored margins for duplex printing and binding |
| `toc`, `lol`, `lof` | Contents, List of Listings, List of Figures |
| `line-numbers` | Gutter numbers in code blocks |
| `csl-style` | Citation style |

For deeper changes, `templates/guide.typ` is organised into eight numbered
sections:

| Want to change | Where |
|----------------|-------|
| Colours, fonts, margins | §1 Configuration |
| Callout colours, or a new kind | §2 `callout-styles` |
| Code block appearance | §3 `#show raw.where(block: true)` |
| Chapter opener (the big numeral) | §3 `#show heading.where(level: 1)` |
| Cover page layout | §4 |
| Contents page | §6 |
| Running header content | §7 |
| Bibliography heading | §8 |

The template imports **no** `@preview` packages. That's deliberate:
third-party Typst packages pin versions and go stale, and a template depending
on four of them stops compiling within a year or two. Everything here is Typst
standard library, so it keeps working.

---

## Starting a new guide

To retarget this from Rust to another subject:

1. Replace the files in `contents/`.
2. Edit `metadata.yaml` — title, subtitle, author, version, accent colour.
3. Replace `bibliography.bib`.
4. Delete `img/ownership.svg` and add your own figures.
5. Change `DOC_NAME` in `Makefile`, `build.ps1` and `build.sh` so the output
   file gets a sensible name.

Nothing in `templates/` or `filters/` is subject-specific.

If you want several guides sharing one template, keep `templates/`, `filters/`
and `build.*` in a shared folder and give each guide its own `contents/`,
`metadata.yaml` and `bibliography.bib`.

---

## Making this a git repo

```bash
git init
git add .
git commit -m "Guide toolchain and Rust introduction draft"
```

`.gitignore` already excludes `output/`, so build artifacts stay out of the
repo. To publish with the GitHub CLI:

```bash
gh repo create my-rust-guide --public --source=. --push
```

### Building the PDF in CI

If you want GitHub Actions to publish a PDF on every push, this workflow does
it — save as `.github/workflows/build.yml`:

```yaml
name: Build PDF
on: [push]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Install Pandoc
        uses: pandoc/actions/setup@v1
        with:
          version: 3.10.2

      - name: Install Typst
        uses: typst-community/setup-typst@v4
        with:
          version: 0.15.1

      - run: make

      - uses: actions/upload-artifact@v4
        with:
          name: guide-pdf
          path: output/*.pdf
```

---

## Things that will bite you

Collected because each one costs an hour the first time.

**`$` in the template is a Pandoc placeholder, even inside `//` comments.**
Pandoc fills the template before Typst ever sees it and has no idea Typst has
comments. Write a literal dollar sign as `$$`.

**Don't put `#` in `metadata.yaml` values.** Pandoc escapes it to `\#`, which
produces invalid Typst. That's why `accent-color` takes `b7410e`, not
`#b7410e`.

**Paths in `metadata.yaml` are relative to the project root, not `output/`.**
The template prefixes them with `/`, which Typst resolves against `--root`.
Image paths in Markdown are handled for you by `filters/images.lua`.

**Filter order matters.** `listings`, `tables` and `callouts` each serialise
their contents to Typst directly, which removes those contents from Pandoc's
document tree. Any filter that needs to look inside them — `crossrefs` — must
run first. The filter list in `Makefile`, `build.ps1` and `build.sh` is ordered
accordingly; keep them in sync if you change one.

**Don't add `--citeproc`.** Typst formats the bibliography itself. Turning on
Pandoc's citation processor as well gives you two reference lists.

**Code inside a figure inherits centre alignment.** If you write a new
`#show` rule for code blocks, keep the `#set align(left)` or every listing
will be centred.

**"unknown font family" warnings are harmless.** Typst logs one per name it
can't find and falls through to the next in the stack. Install the font or
remove the name from `metadata.yaml`.

**Pandoc 2.x will not work.** `--to=typst` arrived in Pandoc 3.0. If the build
fails immediately with an unrecognised-format error, check `pandoc --version`.

**Don't call Pandoc's built-in partials from the template.** A template that
uses `$definitions.typst()$` breaks on newer Pandoc with `Could not find data
file 'templates/definitions.typst'`. Section 2 of `templates/guide.typ` defines
those helpers itself so the template works across Pandoc versions — verified on
3.1.3 and 3.10.2.

---

## Project layout

```
├── contents/              your chapters, ordered by filename prefix
│   ├── 010.introduction.md
│   ├── 020.ownership.md
│   └── 030.error-handling.md
├── templates/
│   └── guide.typ          the Typst template — the only file with styling in it
├── filters/
│   ├── images.lua         rewrites image paths to resolve from the project root
│   ├── crossrefs.lua      [@lst:x] cross-refs; normalises citations for Typst 0.15+
│   ├── listings.lua       captioned code blocks become numbered Listings
│   ├── tables.lua         captioned tables become numbered Tables
│   └── callouts.lua       ::: note / tip / warning / danger boxes
├── img/                   figures
├── output/                build artifacts (gitignored)
├── bibliography.bib       references
├── metadata.yaml          title, author, colours, fonts, citation style
├── Makefile               build entry point (macOS / Linux)
├── build.ps1              build entry point (Windows)
├── build.sh               build entry point without Make
└── README.md
```

---

## Credits and prior art

The architecture of this project comes from
**[alexmodrono/typst-pandoc](https://github.com/alexmodrono/typst-pandoc)** by
[@alexmodrono](https://github.com/alexmodrono) — MIT licensed, © 2025 Alex.
That repository is the reason this one is laid out the way it is, and it is
worth reading in its own right, particularly if you want EPUB output, which it
supports and this project does not.

**Taken from it — the design, not the code:**

- Chapters as separate Markdown files in `contents/`, ordered by numeric
  filename prefix and concatenated at build time, with no index file to keep in
  sync.
- The two-stage `Markdown → Pandoc → .typ → Typst → PDF` pipeline rather than
  letting Pandoc drive Typst in one step. Being able to stop and read the
  intermediate `.typ` is what makes the template debuggable.
- A `filters/` directory of small, single-purpose Lua filters patching the gaps
  in Pandoc's Typst writer, instead of one large filter or a `pandoc-crossref`
  dependency.
- `metadata.yaml` holding document metadata separately from the template, so
  retargeting a document never means editing the template.
- The `Makefile` target layout and the `make watch` rebuild loop.

**Original here:** every file was written from scratch and no source is copied
verbatim. `templates/guide.typ` is a new template aimed at technical guides,
where upstream's `layman.typ` is built for literary books — drop caps, margin
sidebars, mirrored duplex margins. All five Lua filters are new, as are
`build.ps1`, `build.sh` and the Windows support generally.

**Why this isn't a fork.** Upstream pins `@preview` packages that have since
moved on, and `layman.typ` calls `locate(loc => ...)`, which Typst removed in
0.13 — so it does not compile against current Typst without repair. That is why
this project deliberately depends on no third-party Typst packages at all. None
of it is a criticism of the original; it is simply what happens to any project
built on a language still moving quickly.

The upstream licence is reproduced in [CREDITS.md](CREDITS.md).

## Licence

This project's template, filters and build system are yours to do anything
with. The sample Rust content is filler — replace it.

The architecture is derived from
[alexmodrono/typst-pandoc](https://github.com/alexmodrono/typst-pandoc)
(MIT, © 2025 Alex); see [CREDITS.md](CREDITS.md).
