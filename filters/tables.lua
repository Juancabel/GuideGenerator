--[[
  tables.lua — captioned tables become numbered, cross-referenceable figures,
  on Pandoc versions that don't already do it themselves.

  WHY THIS FILTER IS CONDITIONAL
  ------------------------------
  Older Pandoc (3.1.x) rendered a table caption as a loose centred paragraph
  under the table: no "Table 1" label, no numbering, nothing to reference. It
  also did not parse `{#tbl:x}` as a table attribute. This filter existed to
  fix both.

  Newer Pandoc (3.10.x, and somewhere before it) does all of that natively: it
  emits `#figure(align(center)[#table(...)], caption: [...], kind: table)` with
  a `<tbl:x>` label attached, and it parses the identifier properly.

  Running this filter on top of that nests a figure inside a figure. Typst then
  advances the table counter TWICE per table, so numbering comes out 1, 3, 5
  and every cross-reference points at the wrong number.

  So: ask the installed writer what it actually does, rather than hardcoding a
  version boundary that would be wrong for versions in between.

  Markdown (unchanged either way):

      | Type  | Size |
      |-------|------|
      | `i32` | 4    |

      : Integer widths {#tbl:widths}

      Then reference it with [@tbl:widths].
]]

-- Ask the writer directly: does it already wrap a captioned table in a figure?
local function writer_makes_table_figures()
  local ok, out = pcall(function()
    local doc = pandoc.read("| a |\n|---|\n| 1 |\n\n: probe\n", "markdown")
    return pandoc.write(doc, "typst")
  end)
  if not ok or not out then
    return false  -- if the probe fails, fall back to doing the work ourselves
  end
  return out:find("#figure", 1, true) ~= nil
end

local WRITER_HANDLES_TABLES = writer_makes_table_figures()

-- Pull a trailing {#tbl:something} off the caption and return it separately.
-- Only older Pandoc needs this; newer Pandoc parses the attribute itself.
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

  inlines:remove(#inlines)
  if #inlines > 0 and inlines[#inlines].t == "Space" then
    inlines:remove(#inlines)
  end
  last.content = inlines

  return blocks, id
end

function Table(tbl)
  -- Newer Pandoc already produces exactly what this filter would build.
  if WRITER_HANDLES_TABLES then return nil end

  local caption = tbl.caption
  if not caption or not caption.long or #caption.long == 0 then
    return nil
  end

  local caption_blocks, identifier = extract_identifier(caption.long)

  if identifier == "" and tbl.identifier and tbl.identifier ~= "" then
    identifier = tbl.identifier
  end

  -- Render the table with caption and id removed, so Pandoc emits a bare
  -- #table(...) that we can drop inside our own #figure(...).
  --
  -- NOTE: `pandoc.Caption` does not exist as a constructor before Pandoc 3.2
  -- (it crashes with "attempt to call a nil value"). The plain-table form
  -- below works on every version.
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
