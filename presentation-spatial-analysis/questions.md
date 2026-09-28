<!-- Appended verbatim to OUTLINE.md by build-outline.R. Authored here, not
     there, because OUTLINE.md is a generated file. -->

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

**"Is that map where the Eros blue lives?"**
*(Ministry, policymakers)* – No, and the caption says so: it is relative
habitat suitability, where conditions resemble the places the butterfly has
been recorded. It chooses where to look. It cannot show that a species is
absent from a site, and it must never be used to wave a permit through. After
one season of ground-truthing, with the visits that find nothing recorded as
absences, it becomes evidence. The same script builds the map for any species
with a few dozen precise records.

**"Why train the model on other countries' records? And why not MaxEnt?"**
*(Academics)* – Every Kosovo record is a 10 km atlas square, and a 1 km model
cannot learn where on a mountain a butterfly flies from a 10 km square. The
neighbours' precise records sample the same ranges, and keeping Kosovo out of
the calibration is what makes its atlas an independent check – 8 of 9 squares,
AUC 0.82 against the other butterfly squares. With 25 presence cells, one model
with four predictors and their squares over-fits; an ensemble of small models
(Breiner et al. 2015) – six two-predictor GLMs weighted by their performance –
is the established answer for rare species. MaxEnt would draw a similar map.
The method matters less than the records and the validation, and the script is
in the repository.

**"Isn't the Balkan butterfly *Polyommatus eroides*?"**
*(Academics – a lepidopterist will ask)* – Both occur in the region, and GBIF's
taxonomy merges them, and files the Blue Argus under the same name as well. The
model keeps only records whose recorder wrote *P. eros*, drops the 123 written
as *eroides*, and the calibration set still deserves an expert look before the
map is used for more than choosing plots. It matters beyond taxonomy: *P.
eroides* is on Annexes II and IV of the Habitats Directive and *P. eros* is not,
so a merged record can carry legal weight it should not.

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
the EEA39, which includes Kosovo, and the 2018 layer does carry Kosovo data –
the Eros blue model reads its grassland polygons inside the boundary. [VERIFY]
which earlier reference years do before quoting a change period – do not bluff
a year. And the Sentinel
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
