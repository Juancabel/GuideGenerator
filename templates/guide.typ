// =============================================================================
//  guide.typ — a Pandoc → Typst template for formal technical guides
//
//  Project architecture adapted from github.com/alexmodrono/typst-pandoc
//  (MIT, (c) 2025 Alex). This template itself is original. See CREDITS.md.
// =============================================================================
//
//  This file is a PANDOC template, not a plain Typst file. The $$if(x)$$ and
//  $$x$$ markers are placeholders Pandoc fills in from metadata.yaml before
//  Typst ever sees the file. Everything else is ordinary Typst.
//
//  (A literal dollar sign in this file must be written twice, as $$ — Pandoc
//  strips one. That is why the comments above look doubled.)
//
//  Deliberate design choice: this template imports NO @preview packages.
//  Every feature below is built from Typst's standard library, so the template
//  cannot break when a third-party package changes its API, and it compiles
//  with no network access.
//
//  Written against Typst 0.13+ (uses `context`, not the removed `locate`).
//
//  Layout of this file:
//    1. Configuration      — colours, fonts, sizes. Edit these first.
//    2. Helper functions   — callout boxes.
//    3. Global styles      — page, text, headings, links, code, figures.
//    4. Cover page
//    5. Colophon
//    6. Front matter       — table of contents, list of listings/figures.
//    7. Body               — your Markdown lands at $$body$$.
//    8. Bibliography
// =============================================================================


// -----------------------------------------------------------------------------
//  1. CONFIGURATION
//     Most visual tweaks you'll want to make live in this block.
// -----------------------------------------------------------------------------

// Accent colour, used for headings, links, rules and the cover.
// NOTE: give the hex WITHOUT a leading '#' in metadata.yaml — Pandoc escapes
// '#' inside metadata values, which would produce rgb("\#b7410e") and fail.
// The '#' below is literal template text, so it is safe.
//   metadata.yaml:  accent-color: "1e5f8f"
#let accent = rgb("#$if(accent-color)$$accent-color$$else$b7410e$endif$")

// Font stacks. Typst tries each name in turn and uses the first one installed.
//
// The defaults below are the fonts Typst SHIPS WITH, so a fresh checkout
// builds with zero warnings on any machine. Naming a font you don't have
// produces a harmless "unknown font family" warning and falls through to the
// next entry — which is why any font you set in metadata.yaml is tried first
// and these remain as the backstop.
#let font-body = ($if(font-body)$"$font-body$", $endif$"Libertinus Serif")
#let font-sans = ($if(font-sans)$"$font-sans$", $endif$"Libertinus Serif")
#let font-mono = ($if(font-mono)$"$font-mono$", $endif$"DejaVu Sans Mono")

#let size-body = $if(font-size)$$font-size$$else$10.5pt$endif$
#let size-code = $if(code-size)$$code-size$$else$8.5pt$endif$

// Page geometry. Set `two-sided: true` in metadata.yaml for mirrored margins
// suitable for duplex printing and binding.
#let page-margin = $if(two-sided)$(inside: 3cm, outside: 2.4cm, top: 2.6cm, bottom: 2.4cm)$else$(x: 2.6cm, top: 2.6cm, bottom: 2.4cm)$endif$

// Derived tints. Adjust the percentages to make code blocks louder or quieter.
#let code-bg     = luma(250)
#let code-border = luma(225)
#let muted       = luma(110)


// -----------------------------------------------------------------------------
//  2. HELPER FUNCTIONS
// -----------------------------------------------------------------------------

// Pandoc's Typst writer emits calls to helpers it expects the template to
// provide — #blockquote[...], #horizontalrule, #endnote(...) and friends.
// This partial ships with Pandoc and defines them. Without it you get:
//     error: unknown variable: blockquote
// Anything defined below this line overrides the partial's version.
$definitions.typst()$

// Block quotes, restyled with an accent rule instead of Pandoc's default.
#let blockquote(body) = block(
  width: 100%,
  inset: (left: 1.2em, y: 0.4em),
  above: 1.2em,
  below: 1.2em,
  stroke: (left: 2pt + accent.lighten(55%)),
)[
  #set text(style: "italic", fill: luma(70))
  #set par(justify: true)
  #body
]

// Horizontal rules.
#let horizontalrule = align(center, block(
  above: 1.6em, below: 1.6em,
  line(length: 32%, stroke: 0.6pt + luma(180)),
))

// Callout boxes. Written in Markdown as a fenced div:
//
//     ::: note
//     Text of the note.
//     :::
//
// Supported kinds: note, tip, warning, danger. Add your own by extending the
// dictionary below — the Lua filter passes the div's class straight through.
#let callout-styles = (
  note:    (label: "Note",    color: rgb("#2b6cb0")),
  tip:     (label: "Tip",     color: rgb("#2f855a")),
  warning: (label: "Warning", color: rgb("#b7791f")),
  danger:  (label: "Danger",  color: rgb("#c53030")),
)

#let callout(kind: "note", title: none, body) = {
  let style = callout-styles.at(kind, default: callout-styles.note)
  block(
    width: 100%,
    fill: style.color.lighten(94%),
    stroke: (left: 2.5pt + style.color),
    radius: (right: 3pt),
    inset: (x: 11pt, y: 9pt),
    above: 1.2em,
    below: 1.2em,
    breakable: true,
  )[
    #text(
      font: font-sans,
      size: 8.5pt,
      weight: "bold",
      fill: style.color,
      tracking: 0.4pt,
      upper(if title != none { title } else { style.label }),
    )
    #v(-0.35em)
    #set text(size: size-body * 0.95)
    #body
  ]
}


// -----------------------------------------------------------------------------
//  3. GLOBAL STYLES
// -----------------------------------------------------------------------------

#set document(
  title: "$title$",
  author: ($for(author)$"$author$"$sep$, $endfor$),
)

#set text(
  font: font-body,
  size: size-body,
  lang: "$if(lang)$$lang$$else$en$endif$",
  hyphenate: true,
)

#set par(justify: true, leading: 0.72em, first-line-indent: 0em, spacing: 1.1em)

// Headings: numbered "1", "1.1", "1.1.1"; level 1 starts a new page.
#set heading(numbering: "1.1")

#show heading: it => {
  set text(font: font-sans, fill: if it.level == 1 { accent } else { black })
  set block(above: 1.6em, below: 0.9em)
  it
}

#show heading.where(level: 1): it => {
  pagebreak(weak: true)
  block(above: 0em, below: 1.4em)[
    #set text(font: font-sans, size: 22pt, weight: "bold", fill: accent)
    #if it.numbering != none {
      // Big muted chapter number above the title.
      text(size: 42pt, fill: accent.lighten(70%), weight: "bold", counter(heading).display("1"))
      v(-0.7em)
    }
    #it.body
    #v(0.3em)
    #line(length: 100%, stroke: 0.8pt + accent.lighten(55%))
  ]
}

// Links: accent-coloured, no underline noise.
#show link: it => text(fill: accent.darken(10%), it)

// Inline code.
#show raw.where(block: false): it => box(
  fill: code-bg,
  stroke: 0.5pt + code-border,
  radius: 2pt,
  outset: (y: 3pt),
  inset: (x: 3pt),
  text(font: font-mono, size: size-code * 1.02, it),
)

// Block code. Syntax highlighting is native to Typst — no extra tooling.
// Set `line-numbers: false` in metadata.yaml to turn off the gutter.
#show raw.where(block: true): it => block(
  width: 100%,
  fill: code-bg,
  stroke: 0.6pt + code-border,
  radius: 3pt,
  inset: (x: 10pt, y: 9pt),
  above: 1.1em,
  below: 1.1em,
  breakable: true,
)[
  // align(left) is essential: when a listing sits inside #figure(...) it
  // inherits the figure's centre alignment, and every line of code ends up
  // centred. This resets it.
  #set align(left)
  #set text(font: font-mono, size: size-code)
  #set par(justify: false, leading: 0.62em)
  $if(line-numbers)$
  #show raw.line: l => {
    box(width: 1.7em, align(right, text(fill: muted, size: size-code * 0.9, str(l.number))))
    h(0.9em)
    l.body
  }
  $endif$
  #it
]

// Figures: separate counters and supplements for images, tables and listings,
// each numbered independently and cross-referenceable.
#set figure(gap: 0.9em)
#show figure.caption: it => {
  set text(size: size-body * 0.88, fill: luma(60))
  set par(justify: false)
  block(width: 92%)[
    #text(font: font-sans, weight: "bold", fill: accent.darken(5%))[
      #it.supplement #context it.counter.display(it.numbering)
    ]
    #h(0.4em)
    #it.body
  ]
}

// Listings put their caption above the code, like a title bar.
#show figure.where(kind: "listing"): set figure.caption(position: top)
#show figure.where(kind: table): set figure.caption(position: top)

#set table(stroke: (x, y) => if y == 0 { (bottom: 0.8pt + luma(40)) } else { (bottom: 0.4pt + luma(200)) }, inset: 7pt)
#show table.cell.where(y: 0): set text(font: font-sans, weight: "bold", size: size-body * 0.92)

// Quotes.
#show quote.where(block: true): it => block(
  inset: (left: 1.2em),
  stroke: (left: 2pt + accent.lighten(60%)),
)[#set text(style: "italic", fill: luma(60)); #it.body]


// -----------------------------------------------------------------------------
//  4. COVER PAGE
// -----------------------------------------------------------------------------

#set page(paper: "$if(papersize)$$papersize$$else$a4$endif$", margin: page-margin, numbering: none)

#page(margin: (x: 2.6cm, top: 4.5cm, bottom: 2.6cm))[
  #set text(font: font-sans)

  #block(width: 100%, height: 4pt, fill: accent)
  #v(1.6em)

  #text(size: 34pt, weight: "bold", fill: accent)[$title$]

  $if(subtitle)$
  #v(0.4em)
  #text(size: 16pt, weight: "regular", fill: luma(80))[$subtitle$]
  $endif$

  #v(2.2em)
  #line(length: 38%, stroke: 1pt + luma(190))
  #v(1.4em)

  $if(author)$
  #text(size: 12pt, weight: "medium")[
    $for(author)$$author$$sep$ #linebreak() $endfor$
  ]
  $endif$

  $if(version)$
  #v(0.8em)
  #text(size: 10pt, fill: muted)[Version $version$]
  $endif$

  $if(date)$
  #v(0.3em)
  #text(size: 10pt, fill: muted)[$date$]
  $endif$

  // Everything after this pushes to the bottom of the cover.
  #v(1fr)

  $if(cover-image)$
  #align(center, image("/$cover-image$", width: 62%))
  #v(1fr)
  $endif$

  $if(publisher)$
  #text(size: 10pt, fill: muted, weight: "medium")[$publisher$]
  $endif$
]


// -----------------------------------------------------------------------------
//  5. COLOPHON
//     Delete this whole block if you don't want a rights page.
// -----------------------------------------------------------------------------

$if(rights)$
#page(numbering: none)[
  #v(1fr)
  #set text(size: 9pt, fill: muted)
  #set par(justify: false, leading: 0.65em)
  $if(description)$$description$ #parbreak()$endif$
  $rights$
  $if(identifier)$ #parbreak() $identifier$ $endif$
  #parbreak()
  Typeset with Typst and Pandoc.
]
$endif$


// -----------------------------------------------------------------------------
//  6. FRONT MATTER — roman numerals, then the counter resets for the body.
// -----------------------------------------------------------------------------

#set page(numbering: "i", number-align: center)
#counter(page).update(1)

$if(toc)$
#[
  // Chapter-style page breaks are suppressed inside the outline.
  #show heading.where(level: 1): it => block(above: 0em, below: 1.2em)[
    #set text(font: font-sans, size: 20pt, weight: "bold", fill: accent)
    #it.body
    #v(0.25em)
    #line(length: 100%, stroke: 0.8pt + accent.lighten(55%))
  ]
  #outline(title: [Contents], depth: $if(toc-depth)$$toc-depth$$else$3$endif$, indent: 1.2em)

  $if(lol)$
  #v(2em)
  #outline(title: [Listings], target: figure.where(kind: "listing"))
  $endif$

  $if(lof)$
  #v(2em)
  #outline(title: [Figures], target: figure.where(kind: image))
  $endif$
]
$endif$


// -----------------------------------------------------------------------------
//  7. BODY
//     Running headers and arabic page numbers start here.
// -----------------------------------------------------------------------------

#set page(
  numbering: "1",
  number-align: center,
  header: context {
    // No header on a page that opens a chapter.
    let here-page = here().page()
    let chapter-starts = query(heading.where(level: 1))
      .map(h => h.location().page())
    if chapter-starts.contains(here-page) { return }

    // Nearest level-1 heading at or before this point.
    let before = query(heading.where(level: 1).before(here()))
    if before.len() == 0 { return }
    let ch = before.last()

    set text(font: font-sans, size: 8.5pt, fill: muted)
    grid(
      columns: (1fr, auto),
      align(left)[$title$],
      align(right)[
        #if ch.numbering != none {
          [#counter(heading).at(ch.location()).first(). ]
        }
        #ch.body
      ],
    )
    v(-0.5em)
    line(length: 100%, stroke: 0.4pt + luma(210))
  },
)
#counter(page).update(1)

$body$


// -----------------------------------------------------------------------------
//  8. BIBLIOGRAPHY
//     Style is IEEE by default. Typst ships apa, chicago-author-date,
//     chicago-notes, mla, ieee, council-of-science-editors and more; you can
//     also point `style:` at any .csl file path.
// -----------------------------------------------------------------------------

// Paths are written "/name.bib" — root-absolute for Typst, which resolves
// them against --root (the project directory). A bare "bibliography.bib"
// would be looked up next to the generated .typ, i.e. in output/, and fail.
// So: list bibliography paths in metadata.yaml relative to the PROJECT ROOT.
$if(bibliography)$
#pagebreak(weak: true)
#bibliography(
  $for(bibliography)$"/$bibliography$"$sep$, $endfor$,
  title: [$if(reference-section-title)$$reference-section-title$$else$References$endif$],
  style: "$if(csl-style)$$csl-style$$else$ieee$endif$",
)
$endif$
