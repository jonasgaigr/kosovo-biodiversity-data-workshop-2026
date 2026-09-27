<!-- GENERATED FILE - DO NOT EDIT.
     Built by build-outline.R from db-architecture.qmd (titles, slide text,
     speaker notes), data/slide-plan.csv (timings, key messages, visuals)
     and data-flow.mmd. Edit one of those and re-run: Rscript build-outline.R -->

# Data flow, quality and standards

**Biodiversity Database Architecture and Data Modelling – Part 2.**
Slide-by-slide outline, visual plan and speaker notes.

TAIEX Expert Mission on GIS and biodiversity data management, Pristina, case ID ETT IND/EXP 82606. Day 1, Monday 28 September 2026, 11:50-12:30, shared with Part 1 (Karel Chobot). Speaker: Jonáš Gaigr, AOPK ČR.

**2104 spoken words** over 15.5 min of planned slide time – 16.8 min at a calm 125 words per minute, 15.6 min at 135.

Kosovo\* - this designation is without prejudice to positions on status, and is in line with UNSCR 1244/1999 and the ICJ Opinion on the Kosovo declaration of independence.

---

## At a glance

| # | Slide | Time | Words |
|---|---|---|---|
| 1 | Data flow, quality and standards | 0.5 min | 68 |
| 2 | About me | 1 min | 126 |
| 3 | A national database in five layers | 1.5 min | 225 |
| 4 | Three sources, one path | 1.5 min | 212 |
| 5 | Flow A – structured monitoring | 1.5 min | 204 |
| 6 | Flow B – records from trusted experts | 1.5 min | 210 |
| 7 | Flow C – citizen science, on demand | 1.5 min | 193 |
| 8 | Data that nobody uses do not get corrected | 2 min | 264 |
| 9 | Speak Darwin Core from day one | 2 min | 285 |
| 10 | Six habits of a database that lasts | 1.5 min | 194 |
| 11 | Four things to take away | 1 min | 123 |

---

## Slide 1 – Data flow, quality and standards

**Time:** 0.5 min &nbsp;·&nbsp; **Spoken words:** 68

**Key message:** Part 1 showed what the Czech system holds; Part 2 shows how a record travels, how quality is earned, and which standards carry it.

**On the slide:**

*(title slide – no content beyond the title)*

**Visual:** The AOPK title slide. The bridge from Part 1 is spoken over it.

**Speaker notes:**

Thank you, Karel. Karel has shown you what the Czech system holds: the registers, the species records, and the tools we record them with. I take the next step. How does a record travel through a national database, from the field to a report? How is its quality earned on the way? And which standards make that possible? Our tools are only examples. What matters is the design.

---

## Slide 2 – About me

**Time:** 1 min &nbsp;·&nbsp; **Spoken words:** 126

**Key message:** Who is speaking: AOPK ČR since 2020, the BiodivPond pilot in Biodiversa+, the TAIEX mission to Kosovo in December 2023, and the path to Natura 2000 with Ukrainian partners in ConNatur LIFE – one question throughout: how data get from the field to a decision.

**On the slide:**

![](images/gaigr-ento.jpg){fig-alt="Jonáš Gaigr in the field, looking at an insect in a sweep net."}

- **Nature Conservation Agency of the Czech Republic** (AOPK ČR) – since 2020
- **Biodiversa+** – lead development and coordination of the **BiodivPond**
  pond-monitoring pilot
- **TAIEX** – expert mission to Kosovo, December 2023
- **ConNatur LIFE** – with Ukrainian partners, the path to Natura 2000 and to
  implementing the Birds and Habitats Directives in Ukraine

**Visual:** The speaker in the field with a sweep net (images/gaigr-ento.jpg), cropped to fill the left column; four one-line roles on the right.

**Speaker notes:**

First, briefly, who I am. Since 2020 I have worked at the Nature Conservation
Agency of the Czech Republic, the government body for nature conservation.

In Biodiversa+, the European biodiversity partnership, I led the development of
BiodivPond, a pilot on monitoring the biodiversity of ponds, and I now coordinate
it. You will hear more about it on Wednesday.

This is not my first time in Kosovo. I was here in December 2023 on a TAIEX
expert mission. And in the ConNatur LIFE project I work with Ukrainian partners
on the path for Ukraine to Natura 2000 and to the two directives, Birds and
Habitats.

In all of this, the question is the same: how data get from the field to a
decision. That is today's topic.

---

## Slide 3 – A national database in five layers

**Time:** 1.5 min &nbsp;·&nbsp; **Spoken words:** 225

**Key message:** Five layers, one direction of travel: a reference layer every record points to, then staging, validation, core and publication. Layers mean you can always go back to the raw data.

**On the slide:**

**Reference layer** – every other layer points here

- national **checklist**, linked to the Catalogue of Life
- **protection and Red List status**, by taxon ID
- **grids** and **protected sites**
- **habitat crosswalk** and **vocabularies**

**1 · Staging** – raw data exactly as received. Never edited.

**2 · Validation** – automatic checks and expert review. A status on every record.

**3 · Core** – verified, interpreted records. The one copy everybody uses.

**4 · Publication** – portal with sensitive species generalised · API · GBIF via the IPT · reporting

**Visual:** A layer stack drawn in HTML on the slide: the reference layer as a dashed grey column on the left, notched towards a four-step dark-green stack with arrows between steps; publication in light green.

**Speaker notes:**

As we saw in the previous talk, a national system holds many kinds of data. Here
is how I recommend organising them: in layers.

On the left is the reference layer, and everything else points to it. The most
important table in the whole database is the national taxonomic checklist. Every
record points to a taxon ID, never to a name typed by hand. Link the checklist to
the Catalogue of Life, which GBIF now uses as its taxonomy. Hang protection status
and Red List category on the same taxon ID. When a name changes, or a species
goes on the Red List, you change one row, not a million records. The same layer
holds the grids, the protected-site boundaries, the crosswalk from national
habitat types to Annex I habitats, and the lists of allowed values.

Then the data travel down. Staging keeps the raw data exactly as they arrived.
Validation gives every record a status. Core holds the verified records, the one
copy everybody uses. Publication produces everything the outside world sees.

Why layers? Because you can always go back. If an interpretation was wrong, you
run it again from the raw data, and nothing is lost.

For a newer system, the reference layer and staging can start as a few
well-kept tables. The layers are a way of working before they are software.

---

## Slide 4 – Three sources, one path

**Time:** 1.5 min &nbsp;·&nbsp; **Spoken words:** 212

**Key message:** All three sources take the same path; they differ only in how much checking a record needs. The dashed feedback arrow from use back to validation is the most important line on the slide.

**On the slide:**

*The data-flow diagram – rendered, with its Mermaid source, at the end of this outline.*

The layers are the same for every source. What differs is how much checking a record needs – and who does it.

**Visual:** The Mermaid data-flow diagram in data-flow.mmd: sources A, B, C into staging, validation, core; three outputs; reference layer dashed into validation; dashed feedback from reporting to validation.

**Speaker notes:**

This is the whole talk on one picture. On the left are three kinds of source.
A is structured monitoring, collected by trained people on a fixed protocol. B is
records from experts we trust, specialists who send many records every year. C
is citizen science, which we bring in when we need it.

All three follow the same path: staging, validation, core, publication. What
differs is how much checking a record needs, and who does it. A monitoring record
has already been checked by the form and by the coordinator. A citizen-science
record needs an expert before it goes into an official product. A trusted
expert's record sits in between: checked by the machine, and by a person only
when the machine raises a flag.

Under everything is the reference layer. Every automatic check in validation is a
check against the checklist, the grids and the vocabularies.

Now look at the dashed line going backwards, from reporting to validation. When
somebody uses the data, for a report, a Red List or an impact assessment, they
find problems. Those problems go back to validation, and the record is corrected
in core. That loop is the most important arrow on this slide, and I will come
back to it in a few minutes.

---

## Slide 5 – Flow A – structured monitoring

**Time:** 1.5 min &nbsp;·&nbsp; **Spoken words:** 204

**Key message:** Quality starts in the form, is confirmed by a coordinator, and monitoring must be stored as events – only an event can hold an absence and the effort behind it.

**On the slide:**

- **Checks built into the form:** required fields, pick-lists fed from the
  checklist and vocabularies, device position with its accuracy
- **Automatic sync** to staging – nobody retypes
- **The coordinator validates:** protocol followed, all visits done, values
  plausible
- **Stored as an event:** one visit, with its occurrences and measurements

One visit, stored as an event

Event **Visit** · pond 07 · 14 May · night torch count · 2 observers, 2 h

Occurrence *Bombina variegata* – present, 12 adults

Occurrence crested newt (*Triturus* sp.) – absent

Measurement water depth – 0.6 m

Measurement shading – 30 %

Illustrative values. The event carries the date, site, method and effort; the
absence is only meaningful because of them.

**Visual:** An event tree drawn in HTML: one visit (site, date, method, effort) with two occurrences, one of them an absence, and two measurements, each line tagged with its Darwin Core class. Values are illustrative.

**Possible upgrade:** Optional: the Czech Survey123 data-flow slide from taiex_kosovo_monitoring.pptx (slide 12), if the room wants to see the real tool – but Part 1 already showed Survey123 screens.

**Speaker notes:**

Flow A is structured monitoring. In Czechia, surveyors fill in Survey123 forms,
and Karel showed you one. The first line of quality is the form itself. Required
fields cannot be skipped. The species list and every pick-list come from the
reference layer, so nobody can type a name the checklist does not know. The
position comes from the device, with its accuracy in metres. A newer system does
not need Survey123: the free form tools we compare on Wednesday do the same job.

When the form is sent, it syncs into staging automatically. Nobody retypes
anything, and a whole class of errors disappears.

Then a person checks it: the scheme coordinator or an expert. Was the protocol
followed? Were all the planned visits done? Are the numbers plausible? In our
system the coordinator marks the data as guaranteed, and only then do they flow
into the species database.

On the right is the structure. The visit is stored as an event, with its date,
site, method and effort, and the occurrences and measurements hang from it. Why?
Because only an event can hold an absence. Without it, you cannot tell not found
from not looked for. Absences and effort are what make a trend.

---

## Slide 6 – Flow B – records from trusted experts

**Time:** 1.5 min &nbsp;·&nbsp; **Spoken words:** 210

**Key message:** Trust is given once, to an accredited person, per species group. Automatic checks sort records; flagged records go to a review queue, never to the bin.

**On the slide:**

- **Trusted status is earned:** accreditation per species group, reviewed
- **Automatic overnight import** from their app or database
- **Automatic checks:** name matches the checklist · point inside the country,
  plausible uncertainty · plausible date and season · far outside the known
  range?
- **Clean → accepted. Flagged → review queue**, not rejected

A status on every record: the NDOP example

| | Validation – proposed by a regional expert |
|---|---|
| 0 | not yet validated |
| 1 | proposed as fully reliable |
| 3 | proposed as less reliable |
| 6 | proposed as erroneous |
| 9 | proposed for correction |

A central guarantor then confirms the proposal. For species protected by Czech
law, species of Community interest and Annex I birds, this check is compulsory.

**Visual:** The NDOP validation scale as a table (0 not yet validated; 1, 3, 6, 9 proposals), with a caption on the guarantor step and the compulsory check for protected species, species of Community interest and Annex I birds. Source: the NDOP validation slides in Documents/PREZENTACE.

**Possible upgrade:** Optional: a cropped screenshot of the validation fields in the NDOP record editor.

**Speaker notes:**

Flow B is for experts we already trust: the specialists who send hundreds of
records a year. Checking each of those records by hand wastes the validators'
time, so the trust is given once, to the person.

Trusted status is granted by accreditation, per species group. A botanist trusted
for orchids is not automatically trusted for beetles. And the status is reviewed.

Their records come in automatically, as a batch import every night. The Czech
BioLog app works like this: selected users have their records transferred
automatically, while other users' records are checked, usually against a photo.

Every record then passes automatic checks. Does the name match the checklist? Is
the point inside the country, with a plausible uncertainty? Is the date plausible?
A butterfly flying in January is suspicious. Is it far outside the known range?

A clean record is accepted. A flagged record is not deleted. It goes to a review
queue, because the unusual record is sometimes the most valuable one: a new site,
a range expansion. The queue needs an owner and a deadline, or it becomes a
second bin.

On the right is how NDOP stores the result: a validation status on every record,
proposed by a regional expert and confirmed by a central guarantor.

---

## Slide 7 – Flow C – citizen science, on demand

**Time:** 1.5 min &nbsp;·&nbsp; **Spoken words:** 193

**Key message:** Citizen science is imported on demand, filtered, validated by an expert before official use, and always recognisable by its source fields. Deduplicate across platforms.

**On the slide:**

- **Imported when needed** – for one assessment, taxon or area
- **Filters first:** open licence · community identification grade · photo
- **Expert validation** before use in any official product
- **Source always visible:** `datasetName`, `basisOfRecord`,
  `identificationVerificationStatus`
- **Deduplicate** – one sighting often arrives by two routes

What stays on the record after import

| Term | Value |
|---|---|
| datasetName | iNaturalist Research-grade Observations |
| basisOfRecord | HumanObservation |
| identificationVerificationStatus | community consensus – expert check pending |
| license | CC BY-NC 4.0 |
| associatedMedia | link to the photograph |
| occurrenceID | the platform's own ID, kept unchanged |

Illustrative. `identificationVerificationStatus` takes free text in Darwin Core,
so agree a short national list of values for it.

**Visual:** A Darwin Core table of what stays on a citizen-science record after import: datasetName, basisOfRecord, identificationVerificationStatus, license, associatedMedia, occurrenceID. Values are illustrative.

**Possible upgrade:** Optional: an iNaturalist observation page beside the table, showing the research-grade badge and licence.

**Speaker notes:**

Flow C is citizen science. The volume is large and growing, and so is the range of
quality. My advice: do not pour it into the core continuously. Import it on
demand, when you need it for a specific assessment, taxon or area. NDOP, for
example, takes in research-grade observations from iNaturalist. Observation.org
and national apps are the other usual sources.

Filter first. Is the licence open enough for your use? Has the community agreed
on the identification? iNaturalist calls that research grade. Is there a photo an
expert can check?

Then an expert validates, before the records go into anything official. A
research-grade identification is a good start, not a guarantee.

Two rules make this safe. First, the source must always stay visible. Three
Darwin Core fields do it: datasetName says where the record came from,
basisOfRecord says what kind of record it is, and identificationVerificationStatus
says who has checked the identification. Second, deduplicate. The same observer
often uploads the same sighting to two platforms, and one frog must not be counted
twice.

For a small team this flow is the cheapest place to start. The platforms have
already done the collecting.

---

## Slide 8 – Data that nobody uses do not get corrected

**Time:** 2 min &nbsp;·&nbsp; **Spoken words:** 264

**Key message:** Data that nobody uses do not get corrected. Build the way back in (flag, review, tell the observer, version every change) and plan for the uses that find the errors.

**On the slide:**

Build the way back in

- **Any user can flag** a record
- **The validator** for that group reviews it
- **The observer is told** – and often knows the answer
- **Every change is versioned:** who, when, why – an audit trail

The uses that find the errors

- **Art. 17 / Art. 12 reporting** – with EU accession
- **Natura 2000 / Emerald** site assessments
- **Red List** – AOO and EOO from the records (R package *ndopred*)
- **EIA and permitting**
- **Protected-area management plans**

Use → Flag → Review → Tell the observer → Correct, with a trace ↺

**Visual:** Two equal columns – mechanisms and uses – over a loop strip: Use → Flag → Review → Tell the observer → Correct, with a trace ↺.

**Possible upgrade:** Optional: an ndopred map of one species' extent of occurrence with a single outlying point, to show how one wrong record inflates a Red List range.

**Speaker notes:**

This is the key message of my talk. Data that nobody uses, and nobody relies on,
do not get corrected. Errors are not found by checking a database harder. They
are found by using it.

So build the way back into the system. Any user can flag a record: this looks
wrong. The flag goes to the validator for that species group. The observer is
told, because the observer often knows the answer, and because people who never
hear back stop sending records. And every change is versioned: who changed what,
when, and why.

On the right are the uses that do this checking for you. Reporting under Article
17 of the Habitats Directive and Article 12 of the Birds Directive means a
distribution map on the ten-kilometre grid for every listed species, every six
years. For Kosovo this is an obligation that comes with EU accession.

Natura 2000 and Emerald site assessments: a record that puts a site on the list
will be questioned.

Red List assessments compute area of occupancy and extent of occurrence straight
from the records. In Czechia we use an R package, ndopred. IUCN guidance says not
to trim outlying points from the extent, so one wrong point far away inflates the
range, and the assessor goes and checks it. And ndopred leaves out records that
validators have marked as doubtful, so the status does real work.

In impact assessment and permitting, a record can stop a project, so both sides
check it. The same happens in management planning.

Every use is also a quality check. Plan for it.

---

## Slide 9 – Speak Darwin Core from day one

**Time:** 2 min &nbsp;·&nbsp; **Spoken words:** 285

**Key message:** Build in Darwin Core from day one, or keep a documented crosswalk for every field. Event core plus extensions carries monitoring; uncertainty and persistent IDs are non-negotiable.

**On the slide:**

- **Use DwC directly – or keep a documented crosswalk** from every internal field
- **Occurrence** and **Event** cores; **Extended Measurement or Fact**;
  **Humboldt** for effort and completeness
- **Fixed values:** `basisOfRecord`; `occurrenceStatus` = present / absent
- **Mandatory:** `coordinateUncertaintyInMeters`; persistent `occurrenceID` and
  `eventID`
- **Pays back:** GBIF without rework · EU reporting and INSPIRE · open tools ·
  no vendor lock-in · cross-border exchange

A crosswalk: survey spreadsheet → Darwin Core

| Your column | Darwin Core term |
|---|---|
| Species | scientificName + taxonID |
| Date | eventDate (2026-06-18) |
| Lat / Long | decimalLatitude / decimalLongitude |
| GPS accuracy (m) | coordinateUncertaintyInMeters |
| Found? yes / no | occurrenceStatus: present / absent |
| Record no. | occurrenceID – never reused |

The full crosswalk, with the event and measurement fields, is on the handout.

**Visual:** A six-row crosswalk from a typical survey spreadsheet to Darwin Core terms. The full crosswalk is on the handout.

**Speaker notes:**

Now the standard that makes all of this work. Karel showed you the basic Darwin
Core fields. My message is stronger: build in Darwin Core from day one.

You have two options. Use Darwin Core terms directly as your field names. Or keep
your own field names, in your own language, but keep a documented crosswalk that
says which Darwin Core term every field maps to. On the right is part of one, for
a typical survey spreadsheet. The full version is on your handout.

Darwin Core gives you the structure I have described. The Occurrence core for
single records, the Event core for monitoring visits. Measurements go into the
Extended Measurement or Fact extension, which comes from OBIS, the ocean data
network, and is accepted by GBIF. For effort and completeness, what was searched
for and how hard, there is the Humboldt extension, ratified in 2024. It is new,
and tool support is still growing.

Some values come from fixed lists: basisOfRecord, and occurrenceStatus, present
or absent. Two things I would make mandatory. Coordinate uncertainty in metres,
because a point without it cannot be used safely. And a persistent ID on every
record and every event, never changed and never reused. That ID is how a
correction finds its record.

What does it buy you? Publishing to GBIF without rework. An easier path to EU
reporting and INSPIRE. For example, Article 17 maps are drawn on the European
ten-kilometre grid: a record with coordinates and an uncertainty can be placed
in its grid cell automatically, and a record without them cannot. Then the open
tools built for Darwin Core. No lock-in to one vendor. And exchange with your
neighbours, who use the same terms.

---

## Slide 10 – Six habits of a database that lasts

**Time:** 1.5 min &nbsp;·&nbsp; **Spoken words:** 194

**Key message:** Six habits decide whether a database lasts: a named steward and validators, data (not reports) as the deliverable, raw data kept, a sensitive-species policy, clear licensing, and starting small.

**On the slide:**

1
**A named data steward** – and validators for each species group

Here: [to be named]

2
**Funded surveys deliver DwC-ready data** – written into every contract

3
**Raw data never overwritten** – provenance on every record

4
**A written sensitive-species policy** – generalise, do not hide

5
**Clear licence and citation** – so contributors get credit

6
**Start simple, then iterate** – one flow, one group, one year

**Visual:** Six numbered cards in a three-by-two grid. Card 1 carries a placeholder for the local data steward.

**Speaker notes:**

How do you run a database like this? Six habits, taken from the longer list on
your handout.

One: a named data steward. A person, not a committee. And a network of
validators, at least one for each species group. In Czechia, regional experts
validate and a central guarantor confirms. The principle travels; the size does
not.

Two: every survey paid for with public money delivers its data in a form that
maps to Darwin Core, as a condition of the contract. The report is not the
deliverable. The data are.

Three: raw data are never overwritten, and every record carries its provenance:
where it came from, when, and what was changed.

Four: a written sensitive-species policy. The usual answer is to generalise the
location in public, not to hide the record. I will show the Czech solution this
afternoon.

Five: clear licensing and citation. People share data when they know how it will
be used, and that their name stays on it.

Six: start simple and iterate. A newer system can start with a checklist, one
validated flow, and a first dataset on GBIF. Add the next flow when the first
one runs.

---

## Slide 11 – Four things to take away

**Time:** 1 min &nbsp;·&nbsp; **Spoken words:** 123

**Key message:** Four messages to remember, and three questions that open the discussion.

**On the slide:**

1**Layers protect you** – keep the raw data, validate, then publish.

2**Every record carries a status and a source.**

3**Use is the best quality control** – build the way back in.

4**Darwin Core from day one** – every field mapped.

**For discussion – in Kosovo\*:** which flow comes first?
[answer from the room] · Who owns the national checklist?
[to be agreed] · Who validates each species group?
[to be agreed]

*This designation is without prejudice to positions on status, and is in line
with UNSCR 1244/1999 and the ICJ Opinion on the Kosovo declaration of
independence.

**Visual:** Four numbered takeaways, a discussion box with three orange placeholders to be filled from the room, and the TAIEX status designation footnote.

**Speaker notes:**

Four things to remember. Layers protect you: keep the raw data, validate, and
only then publish. Every record carries a status and a source, which is what lets
you trust it and trace it. Use is the best quality control, so build the way back
in from the start. And speak Darwin Core from day one, with every field mapped.

To open the discussion, three questions for you. Which of the three flows matters
most here today? Who should own the national checklist? And who could validate
each species group? Karel and I would like to hear how you see it.

This afternoon I will show what such a system makes possible: analysis, open
access that still protects sensitive species, and faster permits.

---

## The data-flow diagram (slide 4) as Mermaid

The source is `data-flow.mmd`; the deck includes it with `%%| file:`, so this is exactly the diagram the slide shows. GitHub renders the block below as a diagram; open the raw file, or `data-flow.mmd`, for the code. The `%%{init}%%` first line only sizes it for the slide – see "The data-flow diagram" in the README.

```mermaid
%%{init: {"flowchart": {"wrappingWidth": 320, "rankSpacing": 28, "nodeSpacing": 22, "padding": 10}, "themeVariables": {"fontSize": "20px"}}}%%
flowchart LR
  A["<b>A · Monitoring</b><br>forms, fixed protocol"]
  B["<b>B · Trusted experts</b><br>nightly import"]
  C["<b>C · Citizen science</b><br>on demand"]

  S["<b>Staging</b><br>raw data,<br>never edited"]
  V["<b>Validation</b><br>a status on<br>every record"]
  K["<b>Core</b><br>verified,<br>interpreted"]

  P1["<b>Portal and API</b><br>sensitive species<br>generalised"]
  P2["<b>GBIF</b><br>via the IPT"]
  P3["<b>Reporting and use</b><br>Art. 17 and 12 · Red List<br>EIA · site plans"]

  R["<b>Reference layer</b><br>checklist · grids<br>sites · vocabularies"]

  A --> S
  B --> S
  C --> S
  S --> V
  V -- accepted --> K
  K --> P1
  K --> P2
  K --> P3
  R -.-> V
  P3 -. "users flag errors" .-> V

  classDef source fill:#FFFFFF,stroke:#006B4D,stroke-width:2px,color:#000000
  classDef layer fill:#006B4D,stroke:#006B4D,color:#FFFFFF
  classDef out fill:#E8F4D8,stroke:#8CC83C,stroke-width:2px,color:#000000
  classDef ref fill:#F1F1F1,stroke:#B1B1B1,stroke-dasharray:5 4,color:#000000
  class A,B,C source
  class S,V,K layer
  class P1,P2,P3 out
  class R ref
```

