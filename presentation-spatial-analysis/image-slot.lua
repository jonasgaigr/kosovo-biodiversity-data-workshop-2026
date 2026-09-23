--[[---------------------------------------------------------------------------
  image-slot.lua – a visible placeholder for a picture not yet supplied

  Most of the figures in this deck are screenshots and satellite scenes that
  have to be captured by hand (see the README, "Figures"). Until they exist,
  `embed-resources: true` would stop the render on the first missing file, and
  a deck that will not build cannot be rehearsed.

  So every picture is written into the .qmd as the real thing –

      ![](images/uncg-viewer-map.png){slot="16/10" want="The viewer with..."}

  – and this filter checks, at render time, whether the file is there. If it
  is, the image passes through untouched and the two attributes are harmless.
  If it is not, the image is replaced by a dashed box of the same aspect ratio
  that names the file and says what it should show. Dropping the file into
  `images/` and re-rendering is then the whole of the work: no slide is edited.

  `slot` is the aspect ratio the box reserves, written as CSS expects it
  ("16/10"). `want` is the one-line brief for whoever takes the screenshot.

  The box is loud on purpose, like the [VERIFY] marker: a deck carrying one
  has not been finished, and that should be impossible to miss on a rehearsal.
-----------------------------------------------------------------------------]]

local base = nil
if quarto and quarto.doc and quarto.doc.input_file then
  base = pandoc.path.directory(quarto.doc.input_file)
end

local function exists(path)
  local f = io.open(path, "rb")
  if f then f:close(); return true end
  return false
end

local function esc(s)
  return (s:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"):gsub('"', "&quot;"))
end

function Image(el)
  -- URLs and data URIs are somebody else's problem.
  if el.src:match("^%a[%w+.-]*:") then return nil end

  if exists(el.src) then return nil end
  if base and exists(pandoc.path.join({ base, el.src })) then return nil end

  local ratio = el.attributes["slot"] or "16/10"
  local want  = el.attributes["want"] or ""

  return pandoc.RawInline("html", string.format(
    '<span class="img-slot" style="aspect-ratio: %s">' ..
      '<span class="img-slot-file">%s</span>' ..
      '<span class="img-slot-want">%s</span>' ..
    '</span>',
    esc(ratio), esc(el.src), esc(want)))
end
