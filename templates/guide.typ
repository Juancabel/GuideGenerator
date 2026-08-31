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
// font-body/font-sans/font-mono in metadata.yaml accept either a single bare
// name or a YAML list of names to try in order — $$for(...)$$ handles both
// the same way it already does for `author`, and emits nothing when unset.
#let font-body = ($for(font-body)$"$font-body$", $endfor$"Libertinus Serif")
#let font-sans = ($for(font-sans)$"$font-sans$", $endfor$"Libertinus Serif")
#let font-mono = ($for(font-mono)$"$font-mono$", $endfor$"DejaVu Sans Mono")

#let size-body = $if(font-size)$$font-size$$else$10.5pt$endif$
#let size-code = $if(code-size)$$code-size$$else$8.5pt$endif$

// Page geometry. Set `two-sided: true` in metadata.yaml for mirrored margins
// suitable for duplex printing and binding.
// The top margin has to clear the running header, which carries a logo.
#let page-margin = $if(two-sided)$(inside: 3cm, outside: 2.4cm, top: 3cm, bottom: 2.4cm)$else$(x: 2.6cm, top: 3cm, bottom: 2.4cm)$endif$

// Derived tints. Adjust the percentages to make code blocks louder or quieter.
#let code-bg     = luma(250)
#let code-border = luma(225)
#let muted       = luma(110)

// Branding. All three are optional and come from metadata.yaml; leave them
// unset and the cover and headers fall back to the plain typographic layout.
//
//   brand-name       short organisation or programme name, shown top-right of
//                    every body page header and on the title page
//   brand-mark       compact logo for the page header (a crest or symbol —
//                    something that still reads at 8mm tall)
//   brand-logo       full logo with wordmark, shown on the title page
//
// Paths are relative to the PROJECT ROOT, like every other path in
// metadata.yaml; the leading '/' added below makes Typst resolve them against
// --root rather than against the generated .typ in output/.
#let brand-mark-height = 8.5mm
#let brand-logo-width  = 5.2cm
#let brand-grey        = luma(90)

// Brand name, one word per line, right-aligned — used on the title page.
// A single-word brand name just renders as one line.
#let brand-name-str = "$if(brand-name)$$brand-name$$endif$"
#let brand-name-title(size: 13pt) = align(right, stack(
  dir: ttb, spacing: 0.15em,
  ..brand-name-str.split(" ").map(w => align(right,
    text(font: font-sans, size: size, weight: "bold", fill: brand-grey, w)
  ))
))


// -----------------------------------------------------------------------------
//  2. HELPER FUNCTIONS
// -----------------------------------------------------------------------------

// ---- Helpers that Pandoc's Typst writer calls -------------------------------
//
//  Pandoc emits calls to helper functions it expects the template to provide,
//  and WHICH ones it emits changed between Pandoc versions:
//
//    Pandoc 3.0 - 3.5   #blockquote[...]          #horizontalrule   #endnote(n, ...)
//    Pandoc 3.6+        #quote(block: true)[...]  #divider()        #footnote[...]
//
//  Older Pandoc supplied these through a built-in partial pulled in with
//  $$definitions.typst()$$. THAT PARTIAL WAS REMOVED in later Pandoc, so a
//  template still referencing it dies at the Pandoc stage with:
//
//      Could not find data file 'templates/definitions.typst'
//
//  Defining them here instead makes this template work on every Pandoc 3.x.
//  Unused definitions cost nothing, so define them all and stop worrying about
//  which Pandoc is installed.
// -----------------------------------------------------------------------------

#let horizontalRule = align(center, block(
  above: 1.6em, below: 1.6em,
  line(length: 32%, stroke: 0.6pt + luma(180)),
))
#let horizontalrule = horizontalRule    // Pandoc <= 3.5 spelling
#let divider() = horizontalRule         // Pandoc 3.6+, called WITH parentheses

// Pandoc <= 3.5 wrapped block quotes in #blockquote[...]. Pandoc 3.6+ emits a
// native #quote(block: true), which the show rule in section 3 styles instead.
// Both routes land on the same look.
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

// Pandoc <= 3.5 emitted #endnote(...); 3.6+ uses Typst's native #footnote.
#let endnote(num, contents) = stack(dir: ltr, spacing: 3pt, super[#num], contents)

// Definition lists.
#set terms(hanging-indent: 1.5em)

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
    breakable: false,
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

#page(margin: (x: 2.6cm, top: 3cm, bottom: $if(cover-image)$0cm$else$2.6cm$endif$))[
  #set text(font: font-sans)

  // Institutional lockup: full logo on the left, programme name on the right.
  $if(brand-logo)$
  #grid(
    columns: (auto, 1fr),
    align: (left + horizon, right + horizon),
    image("/$brand-logo$", width: brand-logo-width),
    $if(brand-name)$
    brand-name-title(),
    $else$
    [],
    $endif$
  )
  #v(0.8em)
  $else$
  $if(brand-name)$
  #brand-name-title()
  #v(1.2em)
  $endif$
  $endif$

  #block(width: 100%, height: 4pt, fill: accent)
  #v(1.6em)

  #text(size: 34pt, weight: "bold", fill: accent)[$title$]

  $if(subtitle)$
  #v(0.4em)
  #text(size: 16pt, weight: "regular", fill: luma(80))[$subtitle$]
  $endif$

  #v(2.2em)
  #line(length: 38%, stroke: 1pt + luma(190))

  $if(cover-image)$
  // The photo is a full-bleed backdrop for the rest of the cover; the
  // negative pad cancels the page's x-margin so the image reaches both
  // edges, and the 0cm bottom margin set above lets it run to the foot of
  // the page. Author, version and date sit near the top of the photo (same
  // left column, spacing and sizing as the no-image layout below), and
  // publisher sits at its foot — both overlaid in white over a scrim so
  // they stay legible regardless of the photo's own colours.
  #v(1.4em)
  #pad(x: -2.6cm)[
    #block(width: 100%, height: 1fr, clip: true)[
        #place(top + left, image("/$cover-image$", width: 100%, height: 100%, fit: "cover"))
        #place(top + left, rect(
          width: 100%, height: 35%, stroke: none,
          fill: gradient.linear(rgb(0, 0, 0, 75%), rgb(0, 0, 0, 0%), dir: ttb),
        ))
        #place(bottom + left, rect(
          width: 100%, height: 25%, stroke: none,
          fill: gradient.linear(rgb(0, 0, 0, 0%), rgb(0, 0, 0, 70%), dir: ttb),
        ))
        #place(top + left, dx: 2.6cm, dy: 1.2cm)[
          $if(author)$
          #text(size: 12pt, weight: "medium", fill: white)[
            $for(author)$$author$$sep$ #linebreak() $endfor$
          ]
          $endif$
          $if(version)$
          #v(0.8em)
          #text(size: 10pt, fill: luma(220))[Version $version$]
          $endif$
          $if(date)$
          #v(0.3em)
          #text(size: 10pt, fill: luma(220))[$date$]
          $endif$
        ]
        $if(publisher)$
        #place(bottom + right, dx: -2.6cm, dy: -1.2cm)[
          #text(size: 10pt, fill: luma(220), weight: "medium")[$publisher$]
        ]
        $endif$
    ]
  ]
  $else$
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

  $if(publisher)$
  #text(size: 10pt, fill: muted, weight: "medium")[$publisher$]
  $endif$
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
    // The branding runs on every body page. The chapter reference in the
    // middle is dropped on a page that opens a chapter, where the chapter
    // title is already set in 22pt directly below.
    let here-page = here().page()
    let chapter-starts = query(heading.where(level: 1))
      .map(h => h.location().page())
    let opens-chapter = chapter-starts.contains(here-page)

    let running = {
      if opens-chapter { [] } else {
        let before = query(heading.where(level: 1).before(here()))
        if before.len() == 0 { [] } else {
          let ch = before.last()
          if ch.numbering != none {
            [#counter(heading).at(ch.location()).first(). #ch.body]
          } else {
            ch.body
          }
        }
      }
    }

    set text(font: font-sans, size: 8.5pt, fill: muted)
    grid(
      columns: (auto, 1fr, auto),
      align: (left + horizon, center + horizon, right + horizon),
      column-gutter: 0.8em,
      $if(brand-mark)$
      image("/$brand-mark$", height: brand-mark-height),
      $else$
      [],
      $endif$
      running,
      $if(brand-name)$
      text(font: font-sans, weight: "bold", fill: brand-grey)[$brand-name$],
      $else$
      [],
      $endif$
    )
    v(-0.4em)
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
