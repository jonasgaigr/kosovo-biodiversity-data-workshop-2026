--[[---------------------------------------------------------------------------
  aopk-slides.lua — the AOPK ČR footer bar

  Manual p. 18 shows the content-slide bar carrying two pieces of text:
      left   "Název prezentace | 28. července 2025"
      right  "AOPK ČR | aopk.gov.cz"
  and the closing slide carrying an empty bar.

  WHY THIS IS NOT reveal.js's OWN `footer:` OPTION
  Two reasons, both fatal for fidelity:

  1. `footer` is a Quarto *format option*. It is resolved from the document
     YAML long before any Lua filter runs, so a filter cannot compose it from
     `title` + `date`.
  2. Quarto renders that footer as a `position: fixed` element that is a
     sibling of `.slides`, so it is measured in viewport pixels and does NOT
     scale with the slide. The manual specifies the bar as 9.07 % of slide
     HEIGHT; on any window that is not exactly 16:9 a viewport-fixed bar drifts
     away from the slide edge.

  So we inject our own bar *inside* each slide section, where reveal.js's
  transform scales it with everything else and percentages mean what the manual
  says they mean.

  Metadata:
      footer-left    defaults to "<title> | <date>"
      footer-right   defaults to "AOPK ČR | aopk.gov.cz"
      footer: false  suppresses the bar on content slides entirely

  Per-slide: a heading carrying .aopk-closing, .aopk-section or .no-footer gets
  an empty bar instead of the text one.
-----------------------------------------------------------------------------]]

local footer_left, footer_right, footers_enabled = nil, nil, true
local slide_level = 2

local function stringify(v)
  if v == nil then return nil end
  local s = pandoc.utils.stringify(v)
  if s == "" then return nil end
  return s
end

-- Quarto renders an unparseable `date:` as the literal string "Invalid Date".
-- Treat that as "no date" rather than stamping it on every slide.
local function usable(s)
  if s == nil or s == "Invalid Date" then return nil end
  return s
end

local function esc(s)
  return (s:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"):gsub('"', "&quot;"))
end

function Meta(meta)
  if meta.footer == false then footers_enabled = false end

  if meta["slide-level"] ~= nil then
    slide_level = tonumber(stringify(meta["slide-level"])) or 2
  end

  footer_left = stringify(meta["footer-left"])
  if footer_left == nil then
    local title = usable(stringify(meta.title))
    local date  = usable(stringify(meta.date))
    if title and date then
      footer_left = title .. " | " .. date
    else
      footer_left = title or date or ""
    end
  end

  footer_right = stringify(meta["footer-right"]) or "AOPK ČR | aopk.gov.cz"
  return nil
end

-- Headings that should get a blank bar rather than the running one.
local BLANK = { ["aopk-closing"] = true, ["aopk-section"] = true, ["no-footer"] = true }

local function bar_for(header)
  for _, cls in ipairs(header.classes) do
    if BLANK[cls] then
      return pandoc.RawBlock("html", '<div class="aopk-bar aopk-bar-empty"></div>')
    end
  end
  return pandoc.RawBlock("html", table.concat({
    '<div class="aopk-bar">',
      '<span class="aopk-bar-left">',  esc(footer_left),  '</span>',
      '<span class="aopk-bar-right">', esc(footer_right), '</span>',
    '</div>',
  }))
end

function Pandoc(doc)
  if not footers_enabled then return nil end

  -- Pandoc's reveal.js writer opens a <section> at each slide-level heading and
  -- closes it at the next heading of that level or higher, so we append the bar
  -- as the LAST block of each slide.
  --
  -- It must go last, not straight after the heading: the theme offsets a
  -- slide's body with `h2 + *`, and a bar sitting between the heading and the
  -- content would absorb that offset itself (it would gain a `top` that
  -- over-constrains its `bottom: 0`, parking the bar in mid-slide) while the
  -- real content lost it.
  local out = pandoc.List()
  local open_header = nil

  for _, block in ipairs(doc.blocks) do
    if block.t == "Header" and block.level <= slide_level then
      if open_header then out:insert(bar_for(open_header)) end
      open_header = (block.level == slide_level) and block or nil
    end
    out:insert(block)
  end
  if open_header then out:insert(bar_for(open_header)) end

  doc.blocks = out
  return doc
end
