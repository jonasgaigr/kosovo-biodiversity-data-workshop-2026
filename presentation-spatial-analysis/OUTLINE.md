<!-- GENERATED FILE - DO NOT EDIT.
     Built by build-outline.R from spatial-analysis.qmd (titles, speaker notes)
     and data/slide-plan.csv (timings, key messages, visuals).
     Edit one of those and re-run: Rscript build-outline.R -->

# Analysing Spatial Data for Biodiversity Conservation

**Slide-by-slide outline, visual plan and speaker notes.**

TAIEX Expert Mission on GIS and biodiversity data management, Pristina, case ID ETT IND/EXP 82606. Day 1, Monday 28 September 2026, 14:00-14:45. **35 min of delivery**, leaving the balance of the 45-minute slot for questions.

Speaker: Jonáš Gaigr, Biodiversity Monitoring Specialist, Nature Conservation Agency of the Czech Republic (AOPK ČR).

Kosovo\* - this designation is without prejudice to positions on status, and is in line with UNSCR 1244/1999 and the ICJ Opinion on the Kosovo declaration of independence.

---

## At a glance

| # | Slide | Time | Visual |
|---|---|---|---|
| 1 | What this session covers | 1 min | n/a |
| 2 | No baseline is not a reason to wait | 0.5 min | n/a |
| 3 | Kosovo's published record: thin, and concentrated | 2.5 min | exists |
| 4 | A missing baseline is not a reason for inaction | 2 min | n/a |
| 5 | Land-cover change from Copernicus | 2 min | to produce |
| 6 | Fragmentation: connection, not just cover | 2 min | to produce |
| 7 | Why project data dies on hard drives | 2 min | n/a |
| 8 | One central Biodiversity Information System | 2 min | exists |
| 9 | Interoperability: one record, across borders | 2.5 min | exists |
| 10 | Three systems that work | 0.5 min | n/a |
| 11 | The open-data dilemma | 1.5 min | n/a |
| 12 | NDOP: open by default, precise by permission | 2 min | to produce |
| 13 | What the planner sees: the full-precision record | 1.5 min | exists |
| 14 | Raw data is not an answer | 2 min | partly exists |
| 15 | The UNCG Biodiversity Viewer: GBIF, filtered by law | 2.5 min | to produce |
| 16 | Newt surveys on the critical path | 2.5 min | exists |
| 17 | District level licensing: map once, pay once | 3 min | to produce |
| 18 | Next steps: governance that attracts funding | 3 min | n/a |

`exists` = ready to drop in. `partly exists` = a figure in this repository 
needs annotating or extending. `to produce` = must be made. `optional` = the 
slide works as text. `n/a` = deliberately no figure.

---

## Slide 1 - What this session covers

**Time:** 1 min

**Key message:** Five parts, one argument: Kosovo can act on spatial data now, and doing so is what makes it fundable. Each audience group is told what it will get.

**Visual:** No figure. A five-line contents list, plus the TAIEX status designation footnote.

**Source:** TAIEX agenda, case ID ETT IND/EXP 82606 &nbsp;&middot;&nbsp; **Status:** `n/a`

**Speaker notes:**

Good afternoon. This morning Karel and Martin covered how a monitoring scheme is
designed and how the database behind it is modelled. I take the layer above
that: what spatial data does for decisions – and for money.

There are three groups in this room, and each needs something different from
the next thirty-five minutes. For the ministry: what alignment with European
practice asks of you, and the cheapest first step towards it. For policymakers:
how data reduces risk and cost in permitting and investment. For the academics:
standards rigorous enough that your data survives outside your own
spreadsheet, and keeps your name on it. I will say when a point is aimed at
one of you.

Five parts, ending on what makes Kosovo's nature data fundable. Let me start
with the uncomfortable part.

---

## Slide 2 - No baseline is not a reason to wait

**Time:** 0.5 min

**Key message:** Decisions are being taken this week regardless; data makes them checkable, it does not add them.

**Visual:** Section divider, plain dark-green field.

**Source:** – &nbsp;&middot;&nbsp; **Status:** `n/a`

**Speaker notes:**

One idea before any evidence, because everything else hangs from it. Somewhere
in this country this week a permit is being signed, and in that file there is a
biodiversity question. It is being answered today – from data, or from memory.
The question is only whether the answer can be checked.

---

## Slide 3 - Kosovo's published record: thin, and concentrated

**Time:** 2.5 min

**Key message:** Kosovo's published record is thin and extremely concentrated, and most protected sites have no boundary to analyse at all.

**Visual:** Choropleth of GBIF records per km² by municipality, protected-area boundaries and point-only sites over it, Ligatina e Hencit ringed and labelled with its 28 % share.

**Source:** images/kosovo-record-density.png, built by make-figures.R from this repository's pipeline outputs. &nbsp;&middot;&nbsp; **Status:** `exists`

**Speaker notes:**

These numbers do not come from a policy document. They come from an analysis of
this country's own published record, and the code is in a public repository,
so every one of them can be checked.

Forty-six thousand records for almost eleven thousand square kilometres. That is
thin, and I will not pretend otherwise. But the shape matters more than the
size. Look at the red ring. Twenty-eight per cent of everything ever published
for Kosovo comes from a single wetland of just over one square kilometre,
Ligatina e Hencit. That is not a statement about Kosovo's nature. It is a
statement about where birdwatchers go.

Then the protected areas – and this is the point for the ministry. Of the
forty-eight sites with a mapped boundary, twenty-eight have no record inside
them at all. And a hundred and eighty-nine more exist in the European register
only as a single coordinate, the small circles on the map. A protected area
without a polygon cannot be intersected with anything. You cannot ask what is
inside it, you cannot report on it, and you cannot defend it when a
development is proposed next to it.

For the academics: forty-six thousand is what has been *published*, not what
is *known*. There are theses, expedition reports and consultants' surveys in
this country that hold far more. Not missing – just invisible, which for a
planner is the same thing.

And for everyone: this is a normal starting point, not a failure. The Czech
database I will show you later began as card indexes and project reports in
filing cabinets. Almost every European country has been here. What changed
things was not money or talent. It was a decision about where the data would
live.

So the field gap is real. The question is whether it is a reason to wait.

---

## Slide 4 - A missing baseline is not a reason for inaction

**Time:** 2 min

**Key message:** A missing baseline is not a reason for inaction: decisions happen anyway, the burden of proof sits with the project, and the satellite archive is a baseline that can still be collected retrospectively.

**Visual:** No figure. Three-column argument.

**Source:** – &nbsp;&middot;&nbsp; **Status:** `n/a`

**Speaker notes:**

I hear one argument in every country at this stage: we cannot act until we have
a proper baseline. I want to take it apart, because it sounds responsible and
it is the most expensive position available.

First: decisions are being taken anyway. Every impact assessment and every
permit already answers the biodiversity question. Waiting for a baseline does
not postpone those decisions. It only means they are taken on evidence nobody
can check.

Second – and this is for the ministry. Under the Habitats Directive, the burden
of proof does not sit with nature. A plan affecting a protected site has to
show, beyond reasonable scientific doubt, that the site's integrity will not be
harmed. The European Court of Justice set that test in the Waddenzee case. In
that framework, a blank map does not mean "go ahead". It means the developer
cannot discharge the burden, and the decision becomes contestable. Missing data
is a legal and financial risk – for the investor and for the ministry that
signed.

Third, and this is the practical point. You cannot go back and survey 2016. But
the Sentinel satellites did. Since 2015, every few days, at ten-metre
resolution, over every hectare of this country. That archive is the one
baseline that can still be collected after the fact – and it is free.

The same logic answers the ministry's question on network sufficiency without
national totals: give the total as a range, judge on the less favourable end,
and where research is still needed, use the EU's own code for it – scientific
reserve.

So the answer to "we have no baseline" is: you have more of one than you think.

---

## Slide 5 - Land-cover change from Copernicus

**Time:** 2 min

**Key message:** Copernicus gives Kosovo a free, harmonised land-cover change baseline today, in the same classes its neighbours use.

**Visual:** A before/after pair of Sentinel-2 true-colour scenes, 2016 and 2025, over one Kosovo extent with visible land-take.

**Source:** Copernicus Browser (Copernicus Data Space Ecosystem). Author to capture. &nbsp;&middot;&nbsp; **Status:** `to produce`

**Speaker notes:**

Here is what that archive looks like in practice. The same piece of Kosovo, the
same season, nine years apart. You do not need to be a remote-sensing
specialist to read this slide – and that is the point. A minister can read it.

Two products carry most of the value. Sentinel-2 gives ten-metre optical imagery
of the whole country every few days, free and openly licensed, back to 2015.
It is the raw evidence. CORINE Land Cover is the interpreted layer: a
harmonised land-cover map, with change layers between reference years, produced
by the European Environment Agency for thirty-nine countries – and Kosovo is
inside that extent. That matters: your land-cover classes are the same classes
your neighbours and the EU use, so a comparison across a border needs no
translation.

What does this buy the ministry? A land-cover change map for the whole
territory: where forest, grassland or wetland became something else, how much,
and when. That is the baseline the next impact assessment can be measured
against. Today, when an assessment says the site is unchanged, you take the
assessor's word for it. With this, you can check.

For the academics, a word on rigour. Change detection from satellite imagery
has error, and it must be validated against ground reference points – a
classification without an accuracy assessment is a picture, not evidence. But
that validation is a normal, publishable piece of work, and a good thesis
topic.

Land cover tells you how much habitat there is. The next question is whether it
still functions as habitat – and that is about its shape.

---

## Slide 6 - Fragmentation: connection, not just cover

**Time:** 2 min

**Key message:** Fragmentation – patch size, isolation, effective mesh size, barriers – is what decides whether habitat still functions; EO shows it, but cannot see species or condition.

**Visual:** Habitat patches from a Copernicus layer with motorways and main roads over them, for one Kosovo landscape.

**Source:** Copernicus Land Monitoring Service (Tree Cover Density or CLC+ Backbone) and the road network. Author to produce. &nbsp;&middot;&nbsp; **Status:** `to produce`

**Speaker notes:**

Fragmentation is the harder concept and the more important one for species. A
forest can keep its total area and still fail as habitat, if a motorway cuts it
into pieces too small or too isolated for the animals that need it. Bears, lynx
and amphibians care less about hectares than about getting from one piece to the
next.

Three measures do most of the work. Patch size and isolation: how much habitat,
in how many pieces, how far apart. Effective mesh size: one number for how
connected a landscape still is. The European Environment Agency uses it across
Europe, so Kosovo's figure can sit in the same table as its neighbours'. And
barriers: roads, fences, reservoirs.

For policymakers: this is how you see, before a motorway is built, which
alignment cuts a corridor and which runs along an existing one. That is cheaper
to learn on a map than in a court.

Now the limit, bluntly: satellites cannot replace the field programme. There is
no spectral signature for a yellow-bellied toad, and no band combination that
finds a bat roost. Earth observation answers *where* and *how much*. Field survey
answers *what* and *in what condition*. The first tells you where to spend the
second – that is what makes a small field budget behave like a larger one.

And when a Natura 2000 boundary comes to be drawn, these are the edges it should
follow – a habitat patch, a watershed, a road – never the edge of a screening
grid cell. The grid says where to look; the boundary comes from the ground.

Which raises the next question: where does the field data go once collected?

---

## Slide 7 - Why project data dies on hard drives

**Time:** 2 min

**Key message:** Project data dies on hard drives because there is nowhere to put it – a missing destination, not a discipline problem.

**Visual:** No figure. Two-column text: the pattern and its costs.

**Source:** – &nbsp;&middot;&nbsp; **Status:** `n/a`

**Speaker notes:**

I want to describe a pattern and ask you afterwards how much of it you
recognise. In my experience it is nearly universal – I am describing my own
institution thirty years ago.

A project is funded. Good people do good fieldwork. The contract says the
deliverable is a report, so a report is what is delivered, and the data sits in
an annex or on a hard drive. The project closes, the laptop is replaced, and
five years later somebody commissions a survey of the same valley, because
there is no way to discover that the first one ever happened.

Look at the costs, because they are specific and they are budgetable. You pay
twice – a direct fiscal loss. You get no trend: every reporting framework in
this field asks how things are changing, and two surveys with different methods
and no shared records cannot answer that. You cannot defend a decision: when an
impact assessment is challenged, the defence is the underlying record, and a
conclusion with no data behind it loses. And nobody gets credit, so the
researcher has no reason to hand anything over.

The line at the bottom is the one I came to say. This is not solved by telling
people to be tidier. A researcher with nowhere to deposit data who keeps it on a
personal drive is behaving rationally. There is no destination. Build one that
is easy to use and gives credit, and the behaviour changes without anyone being
instructed.

So what does the destination look like?

---

## Slide 8 - One central Biodiversity Information System

**Time:** 2 min

**Key message:** One authoritative copy of each record, fed by ministry, universities and EIA consultants, serves publication, permitting and reporting at once.

**Visual:** Left-to-right flowchart: three sources to Darwin Core to a national biodiversity information system, fanning out to GBIF, EIA screening and reporting.

**Source:** Generated by Mermaid from the .qmd itself &nbsp;&middot;&nbsp; **Status:** `exists`

**Speaker notes:**

The whole architecture on one slide, deliberately boring: the important property
is that there is exactly one box in the middle.

On the left, the three places biodiversity data is produced in Kosovo today: the
ministry and the environmental protection agency's own monitoring; the
universities' theses and field seasons; and – the one usually forgotten – the
consultants who survey for impact assessments. Public money or a public permit
pays for all of those surveys, so require the data, not only the report. That is a clause in a contract, not a law.

Each source is mapped to Darwin Core once – for a spreadsheet, an afternoon –
and deposited in one national system that keeps one
authoritative, versioned copy. The ministry asked what that copy needs: a
permanent identifier on every record, so a correction can be traced; its source
stored as fields; and duplicates linked, not deleted. Kosovo's published record
already holds seventy-seven observations published twice.

What comes out: the same record doing three jobs. It is published
to GBIF with a DOI, and the citation returns to the person who collected it –
the academics' return. It becomes a screening layer for impact assessment, at
full precision, for named users – the ministry's return. And it
feeds reporting, *built* from the system rather than re-collected every few
years – that is where the saving appears on a budget.

The failure to avoid: three outputs, three databases, because the EIA layer was
thought to need separate handling. They diverge within a year, and you have
three answers to one question and no way to say which is right.

What makes one system possible is a shared language.

---

## Slide 9 - Interoperability: one record, across borders

**Time:** 2.5 min

**Key message:** Darwin Core and INSPIRE make a record readable by strangers and across borders – into the neighbours' Emerald Network work – and Kosovo's geoportal already runs INSPIRE-based services.

**Visual:** A real Kosovo record (yellow-bellied toad, Sharri NP) set as a Darwin Core term/value table.

**Source:** GBIF occurrence 5897424625, from this repository's export. Set as text in the slide. &nbsp;&middot;&nbsp; **Status:** `exists`

**Speaker notes:**

Three standards, usually presented as bureaucratic burden. I want to present
them as what makes a record usable by somebody who has never met you.

On the right is a real record from this country, as GBIF holds it: a
yellow-bellied toad in Sharri National Park, last June. Darwin Core is simply
the agreed name for each of those fields. Because the names mean the same thing
in Pristina, Prague and Skopje, a record can be merged with anyone else's
without a telephone call.

For the academics, two fields that do more work than the rest.
Coordinate uncertainty – here, two hundred metres – because a record without a
stated precision cannot be used safely: people either discard it or, worse,
trust it. And occurrence status, because it lets you record an *absence*. A
dataset with no absences shows species arriving and never declining, which is
the opposite of what monitoring is for.

INSPIRE is the services layer – how spatial data is found, viewed and
downloaded. Martin covered the policy frame this morning and returns to data
flows tomorrow, so only the strategic point, for the ministry. Kosovo does not
start from zero: the Kosovo Cadastral Agency's geoportal has run services built
on INSPIRE standards since 2013. The biodiversity layers – protected sites,
species distribution, habitats – should be published *through* that
infrastructure, not beside it.

And transboundary. Sharri continues into North Macedonia and Albania;
Bjeshkët e Nemuna into Albania and Montenegro. Those neighbours are Parties to
the Bern Convention and are building the Emerald Network, the European network
of Areas of Special Conservation Interest. A bear or a lynx population does not
stop at a border, and neither should its assessment. If Kosovo's records follow
the same standards, they join the neighbours' work without translation – and a
joint, cross-border proposal is exactly what international funders like to
see.

That is the architecture. Now three systems that make it work.

---

## Slide 10 - Three systems that work

**Time:** 0.5 min

**Key message:** Three systems, each solving one problem Kosovo has.

**Visual:** Section divider, plain dark-green field.

**Source:** – &nbsp;&middot;&nbsp; **Status:** `n/a`

**Speaker notes:**

Three examples, each chosen because it solves one problem Kosovo has today. The
first addresses the question I am asked in every country, usually in the first
ten minutes: is it safe to publish any of this?

---

## Slide 11 - The open-data dilemma

**Time:** 1.5 min

**Key message:** The poaching fear is legitimate, but closing data disarms the planner rather than the collector – the question is who sees what, at what precision.

**Visual:** No figure. Deliberately a text slide: this is an argument.

**Source:** – &nbsp;&middot;&nbsp; **Status:** `n/a`

**Speaker notes:**

The objection: if you publish exact coordinates for rare species, you help the
people who collect them. And sometimes that is simply true. Orchids have been
dug up, raptor nests robbed, tortoises taken for the pet trade, cave
invertebrates collected to local extinction. In Czechia there are species whose
precise localities I would not publish under any circumstances.

But the usual conclusion – therefore publish nothing – fails on its own terms.
Consider who is actually kept in the dark. The specialist collector already
knows the site; they have been going there for fifteen years and do not need
your database. The person who does not know is the engineer routing a road, or
the official processing a quarry extension. Closing the data works very well –
against exactly the wrong audience.

And for the ministry, the sentence that matters most. To a planner, a site with
no record in the system looks exactly like an empty field. That is how most
sites are actually lost: not to a man with a spade, but to a bulldozer and a
blank map, entirely lawfully, because nothing in the file said anything was
there.

So the real question is not open versus closed. It is governance: who sees what,
at what precision, under what agreement. The Czech answer is a working example.

---

## Slide 12 - NDOP: open by default, precise by permission

**Time:** 2 min

**Key message:** NDOP: 42 million published records, open by default, sensitive species generalised in public and precise for named users under agreement – governance, not software.

**Visual:** NDOP public view of a sensitive species shown generalised to a grid square.

**Source:** AOPK ČR NDOP. Author to capture. &nbsp;&middot;&nbsp; **Status:** `to produce`

**Speaker notes:**

This is the Czech national species occurrence database, NDOP, run by my agency.
It holds over forty-two million published records, and the great majority are
public. The transferable part is not the software – it is how access is
structured.

There is one database. Every record is stored once, at the precision it was
collected. What differs is the view.

The public view is open, and for most species it shows the record at full
precision. For species on the sensitive list – and this is the key design
choice – the location is *generalised*, not *withheld*. On the right you see
what the public sees: the species is present in this square, but not where
exactly. That matters, because a generalised record still tells a planner "look
here before you proceed", while a withheld record tells them nothing at all.

The professional view gives full precision, including the sensitive species, to
public administration and to named users under a data-use agreement. Note the
two conditions: a *named* account, and access that is *logged*. The log is not
there to catch people. It is there so the institution can afford to say yes to
a request, because it can show afterwards exactly what was released and to
whom. An institution that cannot account for what it released will eventually
refuse everything.

And the governance. The sensitive list has an owner, is reviewed on a schedule,
and species come off it as well as going on. A list nobody reviews grows until
everything is restricted and the system is useless.

For the ministry: every piece of this is a written policy decision. None of it
needs to wait for software.

---

## Slide 13 - What the planner sees: the full-precision record

**Time:** 1.5 min

**Key message:** The professional view carries pond-level precision and recorded absences – what makes screening, trends and the English model possible.

**Visual:** NDOP logged-in record list for Triturus cristatus at one site, NEG (absence) records visible.

**Source:** images/ndop-full-precision.png, cropped from presentation-n2k-condition/images/ndop-record-list.png. &nbsp;&middot;&nbsp; **Status:** `exists`

**Speaker notes:**

And this is the other side: what a professional user sees for the same kind of
species. These are records of the great crested newt at one site in the Czech
Republic – a protected amphibian, and you will meet it again in ten minutes.

Look at the detail. Each record names the pond, not the district. There is a
date, often photographs, and a reliability score. And look at the black NEG
labels. Those are negative records: a named surveyor went to that pond, on that
date, looked properly, and did not find the newt.

For the academics, this is the most valuable column on the slide. A database of
presences only can show a species appearing but never disappearing. Recorded
absences are what turn a pile of observations into a monitoring series – and a
monitoring series is what reporting, and funders, ask for.

For the ministry: this is the layer an impact assessor needs. Pond-level
precision, for a named user, under an agreement. The public never sees it; the
planner always can.

---

## Slide 14 - Raw data is not an answer

**Time:** 2 min

**Key message:** Open data is not used data: a developer needs one question answered – what is here and what does the law say – not a forty-column CSV.

**Visual:** Pair: the raw Kosovo CSV as text, clipped at the right; beside it the UNCG viewer's legal-status report for one area.

**Source:** CSV from data_exports/kosovo_overall_biodiversity.csv (exists, set as text); viewer report screenshot to capture. &nbsp;&middot;&nbsp; **Status:** `partly exists`

**Speaker notes:**

The Czech system solves who may see the data. The next problem is whether
anyone can *use* it, and here I have watched national systems do everything
right and then fail.

You build the database. You publish to GBIF. Someone writes a press release
about open data. Two years later a sceptical finance official asks how often it
was used in a planning decision, and the answer is: almost never.

Here is why. Look at the left. This is what an open data download actually is –
the Kosovo extract from this repository. Forty columns, scientific names, no
indication of which species matter. For a researcher, a magnificent resource.
For a municipal planner, a developer's consultant or an investor's project
manager, it is useless – none of them will write code, and several will not
open a GIS. Worse, it looks like an obstruction.

What they need is one question answered: what is at this location, and what
does the law say about it? That question has two halves. The occurrence record
is the first half, and you have it. The second half is the legal status: is
this species strictly protected, on an annex of the Habitats Directive, in the
national Red Book? Joining the two is technically trivial – a lookup table
between a species name and a legal category. And it is the difference between
a dataset and a service.

On the right is somebody who built exactly that.

---

## Slide 15 - The UNCG Biodiversity Viewer: GBIF, filtered by law

**Time:** 2.5 min

**Key message:** The UNCG Biodiversity Viewer joins GBIF records to national and EU legal status per area and writes an EIA-ready report; it transfers to Kosovo by replacing one table.

**Visual:** Screenshot of the viewer with an area selected, filtered records on the map and the conservation-list filter panel.

**Source:** Biodiversity Viewer (UNCG / The Habitat Foundation). Author to capture. &nbsp;&middot;&nbsp; **Status:** `to produce`

**Speaker notes:**

The Ukrainian Nature Conservation Group, with the Dutch Habitat Foundation and
funding from the Netherlands Biodiversity Information Facility, built an open
tool over GBIF data. It is called the Biodiversity Viewer, and it does four
things.

You choose an area: an administrative unit, a polygon you draw, or a boundary
file you upload – a project footprint, say – plus a buffer around it. It pulls
the GBIF records inside that area. Then it does the thing that matters: it
filters them by legal status. The Ukrainian Red Data Book, the Bern Convention
appendices, the annexes of the Habitats and Birds Directives, the IUCN Red
List, regional lists. And it produces a table and a Word report that can go
straight into an impact assessment file.

So a developer's consultant gets, in minutes, the protected species recorded in
and around their site, with the legal instrument that protects each one. That
is the join from the previous slide, made into a web page.

Three reasons this transfers to Kosovo.

The data source is GBIF, which already holds forty-six thousand records for this
country. Nothing has to be collected first.

The legal overlay is a table. The developers write, in their own documentation,
that the tool can be adapted for any other country. Replace the Ukrainian lists
with Kosovo's protected-species list; the EU annexes and the Bern appendices are
already in it. The code does not change. The law is data, not code.

And it is open source, under the MIT licence. No licence fee, no vendor, no
procurement – and it was built by a non-governmental organisation in a country
at war. Whenever I show a Czech system, someone reasonably points out that we
have a large agency and a long budget. This one cannot be answered that way.

For policymakers: this is how the EIA process becomes faster without becoming
weaker. The screening step that took a consultant weeks of enquiries now takes
minutes, and every answer is traceable to a published record.

So far: achievable, and cheap. My last example argues something stronger.

---

## Slide 16 - Newt surveys on the critical path

**Time:** 2.5 min

**Key message:** A four-month survey season on the critical path puts up to a year's unpredictable delay on development and still delivers poor conservation.

**Visual:** Thirteen-month calendar strip: the survey season, and a project that misses it. Drawn in HTML on the slide.

**Source:** Author-drawn (HTML/CSS in the slide) &nbsp;&middot;&nbsp; **Status:** `exists`

**Speaker notes:**

My third example is from England, and it is aimed squarely at the policymakers.
I spend two minutes on the problem first, because the problem is the part that
will sound familiar.

The great crested newt is a European protected species – on the Habitats
Directive annexes, like the yellow-bellied toad I showed you from Sharri. In
England, a development that affects it needs a licence, and a licence needs
evidence of whether newts are present, and how many.

Here is the catch, in the strip across the top. Newts are surveyed in their
breeding ponds, and the breeding season is about three months, from March to
June. Surveys need several visits inside that window. Now follow the second
row. A developer discovers in July that a survey is needed. They cannot have
one. Not for any amount of money. The season has gone, and the project waits
until the next spring. That is up to a year's delay on a financed development,
arriving late, and unknowable at the point the land was bought.

So look at who lost – everyone.

The developers lost time and money, and gained a strong incentive to argue that
the newts were not there. When a system gives people a reason to want a negative
survey, no amount of enforcement fixes it.

The newts lost too. Because mitigation was negotiated project by project, what
got built was small, scattered ponds, often on the development site itself,
rarely monitored beyond a couple of years, and often failing. Dozens of tiny
ponds in the wrong places do not sustain a population.

And the regulator processed applications one at a time, with no view of the
population it was charged with protecting.

A real legal protection that produced delay for developers and very little
conservation. That is common in species licensing, not a peculiarly English
failure. Here is what they did about it.

---

## Slide 17 - District level licensing: map once, pay once

**Time:** 3 min

**Key message:** Mapping risk across a district in advance and pooling developer payments made permitting faster and predictable and delivered more habitat – impossible without the data.

**Visual:** A published great crested newt impact risk zone map for one English district.

**Source:** Natural England or NatureSpace. Licence for reuse to be checked; redraw schematically if it cannot be cleared. &nbsp;&middot;&nbsp; **Status:** `to produce`

**Speaker notes:**

The English answer was to invert the order of operations.

Instead of surveying each site when a development is proposed, the regulator
modelled newt presence across a whole district in advance, from existing survey
data, pond inventories and habitat. The result is published as impact risk
zones – red, amber and green – and the very highest-risk areas are left out of
the scheme altogether and still go through the traditional route.

A developer now checks which zone the site falls in, instead of commissioning a
seasonal survey. They pay a conservation charge, set by the impact of the
development, and receive a certificate that goes in with the planning
application. No waiting for spring.

The money is pooled and spent where the model says the population needs it: at
least four ponds created or restored for every occupied pond lost, with half of
the direct costs set aside so that every pond is managed for twenty-five years.
Natural England runs schemes itself, and a partnership called NatureSpace runs
them for a number of councils.

Now the part for the policymakers, and I want to be precise about the claim.

Permitting becomes fast and predictable – and the second word matters more.
A developer can know what the biodiversity obligation will cost *before buying
the land*. Investors do not mind paying for protection nearly as much as they
mind not being able to price it. It is the unpredictability that deters
investment, not the obligation.

Conservation improves at the same time. This is not a trade in which nature
lost. The compensation is delivered at landscape scale, in places chosen
ecologically rather than wherever the development happened to be, it is
delivered at a ratio of four to one, and it is maintained for a generation.

And the sentence I want to leave in the room: none of this is possible without
the data. The model *is* the scheme. It needs enough spatial data on newts and
ponds to build a defensible prediction – the kind of data NDOP holds, absences
included. Spatial data turned an unpredictable legal risk into a priced, mapped
and scheduled one. That is a de-risking instrument, and it turns developer
payments into a conservation fund.

Let me bring this back to Kosovo.

---

## Slide 18 - Next steps: governance that attracts funding

**Time:** 3 min

**Key message:** Govern, build, fund: twelve months of no-cost governance work creates the baseline, owner and data series that international funders back.

**Visual:** No figure. Three-column roadmap and one closing line.

**Source:** – &nbsp;&middot;&nbsp; **Status:** `n/a`

**Speaker notes:**

Three columns, and the first needs no new law, no procurement and no external
consultant.

Govern, in the first twelve months. Name one owner for biodiversity data – a
person whose job description includes it, not a committee. Write the access and
sensitive-species policy on paper; it is a document, not a system, and writing
it first means any software you buy later is specified correctly. Give the one
hundred and eighty-nine point-only protected sites real boundaries: it is
digitising work from the designation documents, and until it is done those
sites cannot be analysed, reported on or defended. Publish three datasets – not
thirty, three – to GBIF in Darwin Core. And build the Copernicus change
baseline.

Build, over one to three years. Start with a pilot: Sharri and the Henci
wetland taken through the whole workflow to a draft Standard Data Form, so the
method is tested on two sites before it meets all of them. The central
information system, with tiered access designed in from the start rather than
retrofitted. An area-screening
tool for impact assessment: the Ukrainian model with Kosovo's lists. Protected
sites published as INSPIRE services through the national geoportal. And
repeat monitoring, with absences recorded, so that what you hold is a trend and
not a snapshot.

And fund. International funding is competitive. The Instrument for Pre-accession
Assistance and the Green Agenda for the Western Balkans both carry nature
among their priorities, and the institutions that win such money are the ones
that can show a baseline, a named owner and a data series – a system that will
still exist in five years. Funders do not fund intentions. The first column is
twelve months of ordinary work towards that track record. And the English
example adds a domestic source: a licensing charge that grows with development
itself.

One request to each group. To the ministry: name the owner and write the access
policy – it costs nothing and unblocks everything else. To the policymakers:
fund this as infrastructure, with a budget line and a successor, not as a
project that ends; and use the newt case when you argue it to a finance
ministry – faster permits and better conservation, not traded against each
other. To the academics: publish one dataset through GBIF this year, with your
name on it. You keep the credit, and your data starts to appear in decisions.

You do not need a complete picture to start. You need a place to put the picture
as it arrives. Thank you.

---


## Likely questions, and how to answer them

Ordered roughly by how likely they are to be asked. The audience group each one
tends to come from is named, because the same question needs a different answer
depending on who is asking.

**"We do not have the staff for this. Who is supposed to run it?"**
*(Ministry)* – The honest answer is that you need one person, not a unit, and
that naming them is the decision rather than hiring them. Everything in the
"Govern" column is within the reach of one competent GIS officer with a clear
mandate. What kills these systems is not headcount; it is that the
responsibility is split across three institutions and therefore held by none.
Resist the temptation to wait until you can staff the end state.

**"Kosovo is not bound by INSPIRE. Why build to it?"**
*(Ministry, policymakers)* – Because the cost of alignment is asymmetric in
time. Mapping three datasets to a standard now is days of work; retrofitting two
hundred later is a funded project. And you are not starting from zero: the
Kosovo Cadastral Agency's geoportal has run INSPIRE-based services since 2013.
You are not doing it for Brussels – you are doing it so your own ministry,
agency and universities can read each other's data. Do not assert that any
obligation currently applies.

**"What does it actually cost?"**
*(Policymakers)* – Refuse to give a single number and give the structure
instead. The software is the cheapest component and can be zero – the Ukrainian
viewer is open source under the MIT licence. The real costs are one named post,
a modest server or a hosted equivalent, and the one-off digitising of the
protected-area boundaries. The recurring cost that matters is monitoring, and
that is a cost you already carry in fragments through repeated consultant
surveys. Point at "you pay twice": some of this is not new money, it is money
already being spent badly.

**"If I publish my data, will somebody else publish the paper first?"**
*(Academics)* – This is the real objection and it deserves respect rather than a
lecture about openness. Three answers. A DOI timestamps and attributes the
dataset to you, which is a stronger claim than an unpublished spreadsheet.
Publication can be delayed – deposit now, release later. And the dataset itself
is a citable output that increasingly counts in evaluation. If the questioner is
unconvinced, do not push; suggest they start with an older dataset they have
finished with.

**"GBIF data is full of errors and sampling bias. How can it support decisions?"**
*(Academics, and the sharpest question in the room)* – Concede the premise
immediately, because it is correct, and this deck's own Kosovo map is the proof:
one wetland holds 28 % of the records. Then draw the distinction that matters.
Biased presence data cannot estimate abundance or trend; it is entirely usable
for screening – a record is evidence of presence, and presence is what a permit
decision needs to know. The Ukrainian viewer's own documentation says the same:
absence of a record is not evidence of absence, and it drops low-precision
records altogether. Never present a coverage map as a distribution map.

**"Your slide says 42 million NDOP records. I have seen 24 million quoted."**
*(Anyone who has read about NDOP)* – Both were true at the time. The database
passed 35 million records in June 2024, and the public search page gave
42,116,850 published records on 22 September 2026; the 24.7 million figure is
from several years earlier. It grows by roughly a million records a year, so
quote the date with the number.

**"Who decides the sensitive-species list, and what if we get it wrong?"**
*(Ministry)* – Say plainly that in Czechia this is a documented decision taken by
named specialists and reviewed on a cycle, and offer to send the current
procedure rather than describe it from memory. The transferable points: write
down who decides, write down the review interval, and make it possible for
species to come *off* the list. A list that only grows ends with everything
restricted and the system unused.

**"Won't risk-zone mapping just tell developers where they can build, and we lose everything outside the red zones?"**
*(Policymakers, academics – and a fair challenge)* – The strongest objection to
the licensing case, and it should not be brushed aside. Two points. The zones
govern a licensing requirement for one species, not planning permission, so the
rest of the environmental assessment still applies; and the highest-risk areas
are excluded from the scheme and still go through the traditional route. And
the comparison is not with perfect protection – it is with project-by-project
mitigation that delivered scattered, unmonitored compensation. Then concede the
real risk: it only works if the model is maintained and the pooled money is
genuinely spent on habitat. [VERIFY] the published evidence on delivery before
claiming it has been.

**"Do the Copernicus land products actually cover Kosovo?"**
*(Ministry, GIS staff)* – Yes for the extent: CORINE Land Cover is produced for
the EEA39, which includes Kosovo. [VERIFY] which reference years carry Kosovo
data before quoting a change period – do not bluff a year. And the Sentinel
imagery itself is global and free, so the capability does not depend on the
answer: if a thematic layer is missing for a year, it can be derived from
Sentinel-2.

**"Is Kosovo part of the Emerald Network?"**
*(Ministry, academics)* – Do not answer on Kosovo's formal position; it is a
question for the ministry, not for this talk. Say what is certain: the
neighbours sharing Sharri and Bjeshkët e Nemuna are Bern Convention Parties
building the network, and the data standards are open to anyone. Records that
follow them join the neighbours' assessments without translation, whatever the
formal position.

**"We already have a geoportal and a cadastral agency. Does this duplicate them?"**
*(Ministry)* – No, and the distinction is worth drawing carefully. The national
spatial data infrastructure provides the plumbing – discovery, services,
metadata. It does not hold biodiversity content, which has requirements the
cadastre does not: taxonomy, observation events, effort, absence and
sensitivity. The biodiversity system should publish *through* the Kosovo
Cadastral Agency's geoportal, not beside it.

**"Can GBIF records be used to draw Natura 2000 boundaries?"**
*(Ministry, GIS staff – the ministry sent this in advance)* – For screening,
yes; for boundaries, rarely. About six per cent of Kosovo's GBIF records state
an uncertainty of 100 m or better, are recent and name an observer, and even
those need a specialist's check. Four in five Annex I bird records are eBird
checklists with no stated uncertainty at all. Point to the three evidence tiers
on the project site's Natura 2000 page – screening, delineation, Standard Data
Form – and say the thresholds are proposals for national agreement.

**"How do we get from the 5 × 5 km grid to site boundaries?"**
*(Ministry, GIS staff – sent in advance)* – The grid says where to look; the
boundary comes from the ground. Merge priority cells into a search area, then
forget the cell edges: draw along habitat polygons, watersheds and features
visible on the orthophoto at 1:10,000, and record why each stretch of boundary
is where it is. A simple automated test – how much of a boundary runs along
grid lines – catches grid-shaped sites before a reviewer does. Karel's case
study after the break shows how the Czech sites were drawn.

**"Should we test the method somewhere before rolling it out?"**
*(Ministry – sent in advance)* – Yes: two contrasting sites, one field season.
Sharri for the habitat route, Ligatina e Hencit for the bird route, each taken
to a draft Standard Data Form. The lessons log is the real product. The Day 3
reporting session shows the evidence packs for both, built from this
repository.

**"We have one person and no budget. What do we do on Monday?"**
*(Anyone – and the best question to finish on)* – Pick one dataset that already
exists in a spreadsheet, map it to Darwin Core, and publish it. It will take a
week and teach the whole workflow, including everything that is harder than
expected. In parallel, write the access policy, because it needs no software.
Do not begin by specifying a system.

---

## References

Generated from `references.bib`, which is what the deck cites. An entry marked **Checked** was opened and the claim the deck takes from it verified on that date; the rest are standing references (a directive, a standard) - see the head of the .bib and the register in the README.

- **Darwin Core** – Biodiversity Information Standards (TDWG)
  <https://dwc.tdwg.org/>
  *The term vocabulary and the Darwin Core Archive packaging*
- **Convention on the Conservation of European Wildlife and Natural Habitats** – Council of Europe, 1979
  <https://www.coe.int/en/web/bern-convention/emerald-network>
  *ETS No. 104, Bern. The Emerald Network is established under it. The deck names Kosovo's neighbours as Parties building the network and asserts nothing about Kosovo's own position*
- **Council Directive 92/43/EEC on the conservation of natural habitats and of wild fauna and flora** – Council of the European Communities, 1992
  <https://eur-lex.europa.eu/eli/dir/1992/43/oj>
  *Article 6(3). The "no reasonable scientific doubt" test is from the Court of Justice, Case C-127/02 (Waddenzee), 2004*
- **TAIEX Expert Mission on Geographic Information Systems (GIS) and biodiversity data management** – European Commission, Directorate-General for Neighbourhood and Enlargement Negotiations, 2026
  Case ID ETT IND/EXP 82606, Pristina, 28–30 September 2026.
  *The agenda carries the status designation footnote reproduced on the first slide of this deck*
- **CORINE Land Cover** – European Environment Agency
  Copernicus Land Monitoring Service.
  <https://land.copernicus.eu/en/products/corine-land-cover>
  **Checked** 2026-09-22.
  *Produced for the EEA39 – the 33 EEA member countries and six cooperating countries, Kosovo under UNSCR 1244/99 among them. [VERIFY] which reference years actually carry Kosovo data before quoting a change period*
- **Nationally designated areas (NatDA, formerly CDDA)** – European Environment Agency, 2026
  DOI: <https://doi.org/10.2909/028003e7-7585-4d69-92fc-7f81e0cc2340>
  *Version 24, July 2026. CC-BY 4.0. The source of the Kosovo protected-area boundaries and of the 237 sites / 1,261 km² / 11.6 % figures*
- **Landscape fragmentation in Europe** – European Environment Agency and Swiss Federal Office for the Environment, 2011
  <https://www.eea.europa.eu/publications/landscape-fragmentation-in-europe>
  *The effective mesh size and effective mesh density measures*
- **Directive 2007/2/EC establishing an Infrastructure for Spatial Information in the European Community (INSPIRE)** – European Parliament and Council of the European Union, 2007
  <https://eur-lex.europa.eu/eli/dir/2007/2/oj>
  *Annex I Protected sites; Annex III Species distribution and Habitats and biotopes*
- **Regulation (EU) 2021/1529 establishing the Instrument for Pre-Accession assistance (IPA III)** – European Parliament and Council of the European Union, 2021
  <https://eur-lex.europa.eu/eli/reg/2021/1529/oj>
- **Sentinel-2 mission guide** – European Space Agency
  <https://sentiwiki.copernicus.eu/web/sentinel-2>
  *Multispectral Instrument; 10 m, 20 m and 60 m bands. Data from 2015. The deck says "every few days" and quotes no revisit interval*
- **Copernicus Data Space Ecosystem** – European Union and European Space Agency
  <https://dataspace.copernicus.eu/>
  *The current free access route to Sentinel data, and the successor to the Copernicus Open Access Hub*
- **Biodiversity of Kosovo – GBIF data analysis** – Gaigr, Jonáš, 2026
  Quarto website and reproducible R workflow.
  <https://jonasgaigr.github.io/kosovo-biodiversity-data-workshop-2026/>
- **GBIF Occurrence Download: Kosovo** – Global Biodiversity Information Facility, 2026
  <https://www.gbif.org/occurrence/download/0003504-260903145123482>
  *Download key 0003504-260903145123482: the extract behind every Kosovo figure in this deck, taken by the pipeline in this repository. [VERIFY] the minted DOI is recorded in data/run_metadata.rds and printed in the published report; quote the DOI, not the download key*
- **Integrated Publishing Toolkit (IPT)** – Global Biodiversity Information Facility
  <https://www.gbif.org/ipt>
- **Sofia Declaration on the Green Agenda for the Western Balkans** – Leaders of the Western Balkans, 2020
  *10 November 2020. Biodiversity is one of its five pillars. [VERIFY] a stable URL for the declaration text*
- **Implementing a National Spatial Data Infrastructure for a Modern Kosovo** – Meha, Murat and Crompvoets, Joep and Çaka, Muzafer and Pitarka, Denis, 2015
  <http://www.fig.net/resources/proceedings/fig_proceedings/fig2015/papers/ts04d/TS04D_meha_crompvoets_et_al_7451.pdf>
  **Checked** 2026-09-22.
  *The Kosovo Cadastral Agency launched the national geoportal in June 2013, "developed in accordance to INSPIRE standards", with network services for search, view and download*
- **Great crested newts: district level licensing schemes for developers, ecologists and landowners** – Natural England
  <https://www.gov.uk/government/publications/great-crested-newts-district-level-licensing-schemes-for-developers>
  **Checked** 2026-09-22.
  *Where the Natural England and NatureSpace schemes operate*
- **Nálezová databáze ochrany přírody (NDOP) – Species Occurrence Database** – Nature Conservation Agency of the Czech Republic
  <https://portal23.nature.cz/nd/>
  **Checked** 2026-09-22.
  *"Hledejte v 42 116 850 zveřejněných záznamech" on the search page on the access date. The great majority of records public; data provided under contract for other uses. [VERIFY] the precision sensitive species are generalised to in the public view*
- **Great crested newt district licensing scheme: FAQs** – NatureSpace Partnership
  <https://naturespaceuk.com/district-licensing/faqs/>
  **Checked** 2026-09-22.
  *Red and amber impact risk zones; no seasonal survey in the 3-month breeding season (March–June); at least four ponds created or restored for each occupied pond lost; half of direct costs endowed for 25 years of management*
- **Biodiversity Viewer** – The Habitat Foundation and Ukrainian Nature Conservation Group
  Open-source R Shiny application, MIT licence.
  <https://github.com/ABiatov/gbif_shiny_onlineviewer>
  **Checked** 2026-09-22.
  *"An open web-based biodiversity conservation decision-making tool for policy and governance", supported by NLBIF, grant nlbif2022.014. Feature list checked against the repository's about_en.md, Code_Explanation.md and the columns of its protected-species list*
- **The Conservation of Habitats and Species Regulations 2017** – United Kingdom, 2017
  <https://www.legislation.gov.uk/uksi/2017/1012/contents>
  *S.I. 2017/1012. The regulations under which the licences are issued in England*
