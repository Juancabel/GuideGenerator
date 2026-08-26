--[[
  listings.lua — captioned, numbered, cross-referenceable code listings.

  Markdown:

      ```{.rust #lst:hello caption="A minimal Rust program"}
      fn main() {
          println!("Hello, world!");
      }
      ```

  Becomes a Typst figure with kind "listing", so it is numbered
  independently of images and tables, appears in the List of Listings,
  and can be referenced with [@lst:hello].

  Code blocks WITHOUT a caption= attribute are left completely alone.
]]

local function to_typst(blocks)
  return pandoc.write(pandoc.Pandoc(blocks), "typst")
end

function CodeBlock(el)
  local caption = el.attributes.caption
  if not caption or caption == "" then return nil end

  -- Re-render the code alone, so Pandoc handles fencing and escaping for us.
  local bare = pandoc.CodeBlock(el.text, pandoc.Attr("", el.classes, {}))
  local code_typst = to_typst({ bare })

  -- The caption may contain inline Markdown: `code`, *emphasis*, links.
  local parsed = pandoc.read(caption, "markdown").blocks
  local cap_typst = ""
  if #parsed > 0 and parsed[1].content then
    cap_typst = to_typst({ pandoc.Plain(parsed[1].content) })
  else
    cap_typst = caption
  end

  local label = ""
  if el.identifier and el.identifier ~= "" then
    label = " <" .. el.identifier .. ">"
  end

  -- Wrap the code in [ ] so it is content, not code: inside #figure(...) we
  -- are already in code mode. Typst lexes a raw block atomically, so stray
  -- brackets inside your source code cannot unbalance this.
  return pandoc.RawBlock("typst", table.concat({
    "#figure(",
    "[",
    code_typst,
    "]",
    ", caption: [" .. cap_typst .. "]",
    ', kind: "listing", supplement: [Listing])' .. label,
  }, "\n"))
end
