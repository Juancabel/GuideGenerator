# Credits

## Architectural basis

This project's build architecture is adapted from
**[alexmodrono/typst-pandoc](https://github.com/alexmodrono/typst-pandoc)**
by [@alexmodrono](https://github.com/alexmodrono).

That project demonstrated the approach this one is built on:

- chapters as numbered Markdown files, concatenated at build time
- a two-stage `Markdown → Pandoc → .typ → Typst → PDF` pipeline
- a directory of small Lua filters covering the gaps in Pandoc's Typst writer
- document metadata kept in `metadata.yaml`, outside the template
- a `Makefile` with a `watch` rebuild loop

If you want EPUB output alongside PDF, or a book-style template with drop caps
and margin sidebars, go and use the original — it does both, and this project
does neither.

## What is original to this project

No source from the upstream project is reproduced here. Every file was written
from scratch:

| File | Status |
|------|--------|
| `templates/guide.typ` | Original. Aimed at technical guides; upstream's `layman.typ` targets literary books. |
| `filters/images.lua` | Original |
| `filters/crossrefs.lua` | Original |
| `filters/listings.lua` | Original |
| `filters/tables.lua` | Original |
| `filters/callouts.lua` | Original |
| `build.ps1`, `build.sh` | Original — Windows support and a Make-free path |
| `Makefile` | Original, but modelled on upstream's target layout |
| `contents/`, `bibliography.bib`, `img/` | Original sample content |

This project also depends on no third-party Typst `@preview` packages, where
upstream depends on `drafting`, `ctheorems` and `droplet`. That is a deliberate
divergence: pinned package versions are what make a template stop compiling a
year later.

## Upstream licence

The MIT licence of alexmodrono/typst-pandoc, reproduced in full as
acknowledgement:

```
MIT License

Copyright (c) 2025 Alex

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

## Other tools this depends on

- **[Pandoc](https://pandoc.org)** — John MacFarlane and contributors (GPL-2.0-or-later)
- **[Typst](https://typst.app)** — Typst GmbH and contributors (Apache-2.0)

Bibliography styles are the CSL styles bundled with Typst via
[Hayagriva](https://github.com/typst/hayagriva).
