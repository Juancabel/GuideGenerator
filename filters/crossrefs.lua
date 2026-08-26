--[[
  crossrefs.lua — cross-references AND citation normalisation.

  Two jobs, both about Pandoc's `[@key]` syntax:

  1. CROSS-REFERENCES. A key with a known prefix is a pointer to something
     in this document, not a bibliography entry:

         See [@lst:hello] and [@fig:ownership].
         -> See @lst:hello and @fig:ownership.

     Typst resolves those to "Listing 1", "Figure 3" automatically, using
     each figure's supplement. No pandoc-crossref dependency.

  2. CITATIONS. Everything else is a real citation. Pandoc's Typst writer
     emits `#cite("key")` (a string) on older versions, but Typst 0.13+
     requires `#cite(<key>)` (a label) and errors out otherwise:

         error: expected label, found string

     Emitting the label form ourselves makes the pipeline work across
     Pandoc versions instead of depending on which one you installed.

  NOTE: run this WITHOUT --citeproc. Typst formats the bibliography itself
  (see the #bibliography call in templates/guide.typ). Using both would
  give you two reference lists.

  ORDERING: this filter must run BEFORE listings.lua, tables.lua and
  callouts.lua. Those three serialise their contents to Typst themselves,
  which removes those contents from Pandoc's AST — so a citation inside a
  callout would never reach this filter and would escape as #cite("key"),
  which Typst rejects.
]]

local REF_PREFIXES = {
  lst = true,  -- listings
  fig = true,  -- figures
  tbl = true,  -- tables
  sec = true,  -- sections
  eq  = true,  -- equations
}

local function inlines_to_typst(inlines)
  if not inlines or #inlines == 0 then return nil end
  local s = pandoc.write(pandoc.Pandoc({ pandoc.Plain(inlines) }), "typst")
  -- Trim whitespace and a leading comma ("[@smith, p. 4]" -> "p. 4").
  s = s:gsub("^%s+", ""):gsub("%s+$", ""):gsub("^,%s*", "")
  if s == "" then return nil end
  return s
end

function Cite(el)
  local parts = {}

  for _, c in ipairs(el.citations) do
    local prefix = c.id:match("^(%a+):")

    if prefix and REF_PREFIXES[prefix] then
      -- A cross-reference.
      table.insert(parts, "@" .. c.id)
    else
      -- A bibliography citation.
      local supplement = inlines_to_typst(c.suffix)
      if supplement then
        table.insert(parts, "#cite(<" .. c.id .. ">, supplement: [" .. supplement .. "])")
      else
        table.insert(parts, "#cite(<" .. c.id .. ">)")
      end
    end
  end

  if #parts == 0 then return nil end
  return pandoc.RawInline("typst", table.concat(parts, " "))
end
