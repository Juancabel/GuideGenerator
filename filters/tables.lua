--[[
  tables.lua — captioned tables become numbered, cross-referenceable figures.

  Pandoc's Typst writer renders a table caption as a loose centred paragraph
  under the table: no "Table 1" label, no numbering, nothing to reference.
  This filter wraps captioned tables in a real Typst figure instead.

  Markdown:

      | Type  | Size |
      |-------|------|
      | `i32` | 4    |

      : Integer widths {#tbl:widths}

  Then reference it with [@tbl:widths].

  TWO PANDOC QUIRKS ARE HANDLED HERE, both of which cost real debugging time:

  1. Pandoc does NOT parse `{#tbl:widths}` as a table attribute the way it does
     for images and code blocks. The braces survive as literal text at the end
     of the caption. So we extract the identifier ourselves and strip it.

  2. `pandoc.Caption` does not exist as a constructor before Pandoc 3.2, so
     clearing a caption via `pandoc.Caption({})` crashes with
     "attempt to call a nil value (field 'Caption')". The plain-table form
     `{ long = ... }` works on every version.

  Tables without a caption are left alone.
]]

-- Pull a trailing {#tbl:something} off the caption and return it separately.
local function extract_identifier(blocks)
  if #blocks == 0 then return blocks, "" end

  local last = blocks[#blocks]
  if not last.content then return blocks, "" end

  local inlines = last.content
  if #inlines == 0 then return blocks, "" end

  local tail = inlines[#inlines]
  if tail.t ~= "Str" then return blocks, "" end

  local id = tail.text:match("^{#([%w][%w:_%-%.]*)}$")
  if not id then return blocks, "" end

  -- Drop the {#...} token, and the space that preceded it.
  inlines:remove(#inlines)
  if #inlines > 0 and inlines[#inlines].t == "Space" then
    inlines:remove(#inlines)
  end
  last.content = inlines

  return blocks, id
end

function Table(tbl)
  local caption = tbl.caption
  if not caption or not caption.long or #caption.long == 0 then
    return nil
  end

  local caption_blocks, identifier = extract_identifier(caption.long)

  -- Fall back to a real attribute if the document happens to carry one.
  if identifier == "" and tbl.identifier and tbl.identifier ~= "" then
    identifier = tbl.identifier
  end

  -- Render the table with caption and id removed, so Pandoc emits a bare
  -- #table(...) that we can drop inside our own #figure(...).
  local bare = tbl:clone()
  bare.caption = { long = pandoc.Blocks({}) }
  bare.identifier = ""
  local table_typst = pandoc.write(pandoc.Pandoc({ bare }), "typst")

  local caption_typst = pandoc.write(pandoc.Pandoc(caption_blocks), "typst")

  local label = ""
  if identifier ~= "" then
    label = " <" .. identifier .. ">"
  end

  -- The rendered table starts with `#align(...)`, but inside #figure(...) we
  -- are already in code mode, where a leading `#` is an error. Wrapping it in
  -- [ ] puts it back into content mode.
  return pandoc.RawBlock("typst", table.concat({
    "#figure(",
    "[",
    table_typst,
    "]",
    ", caption: [" .. caption_typst .. "]",
    ", kind: table)" .. label,
  }, "\n"))
end
