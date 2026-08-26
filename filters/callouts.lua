--[[
  callouts.lua — note / tip / warning / danger boxes.

  Markdown:

      ::: warning
      Never call `unwrap()` on a `Result` in production code.
      :::

  Optional custom heading:

      ::: {.note title="Before you begin"}
      Install the toolchain first.
      :::

  Rendered by the `callout()` function defined in templates/guide.typ.
  To add a new kind, add it to KINDS here and to `callout-styles` there.
]]

local KINDS = {
  note = true,
  tip = true,
  warning = true,
  danger = true,
}

function Div(el)
  local kind = nil
  for _, class in ipairs(el.classes) do
    if KINDS[class] then
      kind = class
      break
    end
  end
  if not kind then return nil end

  local inner = pandoc.write(pandoc.Pandoc(el.content), "typst")

  local title_arg = ""
  local title = el.attributes.title
  if title and title ~= "" then
    title_arg = ', title: "' .. title:gsub('\\', '\\\\'):gsub('"', '\\"') .. '"'
  end

  local label = ""
  if el.identifier and el.identifier ~= "" then
    label = " <" .. el.identifier .. ">"
  end

  return pandoc.RawBlock("typst",
    '#callout(kind: "' .. kind .. '"' .. title_arg .. ")[\n" .. inner .. "\n]" .. label)
end
