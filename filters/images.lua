--[[
  images.lua — make image paths resolve from the project root.

  The generated .typ lives in output/, but image paths in your Markdown are
  written relative to the project root (img/diagram.svg). Typst resolves
  relative paths against the .typ file's own directory, so it would look for
  output/img/diagram.svg and fail with:

      error: file not found (searched at .../output/img/ownership.svg)

  Typst treats a leading "/" as "relative to --root", and the Makefile passes
  --root="$(CURDIR)". So prefixing the path with "/" makes it resolve from the
  project root no matter where the .typ is written.

  URLs, data: URIs and already-absolute paths are left alone.
]]

function Image(el)
  local src = el.src

  if src:match("^%a[%w+.%-]*://")   -- http://, https://, file://
    or src:match("^/")              -- already root-absolute
    or src:match("^data:") then     -- inline data URI
    return nil
  end

  el.src = "/" .. src
  return el
end
