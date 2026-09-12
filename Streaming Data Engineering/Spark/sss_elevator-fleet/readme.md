# Kafka & Spark Structured Streaming — the elevator fleet

*by [Emanuele Della Valle](https://emanueledellavalle.org/) and
[Claude](https://claude.com/product/overview)*

## Introduction

Lectures 6 and 7 put an EPL controller on **one building**: two cars, ten floors, decisions in
milliseconds, and it has to keep working with the network down. That is not a choice about
technology, it is a normative one — the dispatch loop is safety-critical, it falls under
EN 81-20/81-50 and ASME A17.1, and nobody puts a dispatcher behind a round trip to a cloud
region.

This module is the other tier of the same system. **150,000 units, minute latency, no
control — only intelligence.** Same domain, same events, four orders of magnitude more of
them, and questions the controller cannot even ask: how does the fleet behave, where is the
load, which units are drifting.

One slide's worth of the lecture is the question this module answers by running it:

> **Does the same question, asked at the two tiers, need the same language?**

It does not, and `Q.10.3` is where that stops being an opinion.

The real-world reference is a cloud platform for connected elevators — door movements, trips,
calls and error codes collected from a fleet of well over a hundred thousand units, and
trends used to estimate remaining component life. What such a platform does internally is
not public, so **nothing here claims to be how anyone does it**. It is a plausible
architecture for a problem of this shape, which is the better exercise anyway: you design
instead of copying.

## Resources

* [Structured Streaming programming guide](https://spark.apache.org/docs/latest/structured-streaming-programming-guide.html)
* [The EPL controller this module sits above](../../EPL/epl-elevator-controller/readme.md)
* [The join semantics the fleet query reuses](../../EPL/epl-join-semantics/readme.md)

## 1. Set up

### make sure

* you have [docker](https://docs.docker.com/get-docker/) and docker compose (a single app on
  Windows and Mac; on Linux [install docker compose separately](https://docs.docker.com/compose/install/))
* you do not have any firewall forbidding you from reaching `localhost:8888`

### start up the infrastructure

```
docker-compose up -d
```

The first time it downloads a couple of GB. **Don't do it in class.**

### you know you succeeded if

1. you can open [http://localhost:8888](http://localhost:8888)
2. entering the token `sda` you get a [jupyter lab](https://jupyterlab.readthedocs.io/en/stable/)
   with a folder named `work`
3. `docker-compose ps` shows **two** services, `kafka` and `notebook`, both up

### the compose file of this module is not the one of the others

Two services instead of five, and different images. Both changes have a reason, and the
second one matters if you are on a recent Mac.

**Both images are multi-architecture.** `docker` pulls the variant that matches your
machine, so this runs natively on Apple Silicon, on Intel and on Windows/WSL2. The
images the other Spark modules use are `linux/amd64` only, and are therefore *emulated*
on an ARM laptop — where the notebook kernel wedges, unkillably, the moment a cell
launches a subprocess. That is why this module has no `pip` cell: the Kafka client is
installed by `setup/20-kafka-client.sh`, which the notebook image runs before the server
starts. It also fixes the client version, since the `confluent-kafka` 1.7.0 that the
other modules pin has no wheel for python 3.10+ and none for `aarch64`.

**Kafka runs in KRaft mode**, so there is no ZooKeeper — deprecated in the 3.x line and
gone from Kafka 4 — and no schema registry and no `kafkacat`, because nothing in this
module uses them.

## 2. Run it

The two notebooks **alternate**, as in `sss_late-arrivals`: the monitoring notebook registers
a streaming query, then sends you back to the simulator to produce the next section of the
trace. Three rules make the whole thing painless:

* **keep both notebooks open**, side by side if your screen allows it;
* **never re-run a cell that starts a query** (`q101 = …`). It is already running. What you
  re-run is the `SELECT` cell below it, which reads what the query has accumulated;
* a query keeps consuming while you are in the other notebook. That is the point.

Sections are named by the headings in the notebooks, so you can always tell where you are.

| # | notebook | run this section | what you should see |
|---|---|---|---|
| 1 | simulator | *The client is already installed* → *The two topics, and why they are two* → *The fleet*, down to the producer. **Stop at the heading `1) Background traffic`** | `confluent-kafka 2.5.0`; `elevator-events` with **6** partitions and `elevator-faults` with **1**; then the four sections of the trace: **384** background events over `08:00:00..08:05:59`, 6 bunching, 6 straggler, 4 faults, `units 24, regions 3` |
| 2 | monitoring | *The session, and the Kafka connector* → *The static side* → *Q.10.1 — how many doors, per unit, per minute* | `spark 3.5.0 / scala 2.12`, the schema of `doors`, the reference table — and **an empty result table**. Correct: nothing has been produced yet |
| 3 | simulator | *1) Background traffic — six minutes of fleet time*, both cells | six lines, one per minute of fleet time, then the four faults |
| 4 | monitoring | the `SELECT` under *Go to the simulator: section 1)* — **that cell only**, not the one that starts the query — then *The same minute can appear twice, and it is not a bug* | one row per unit per minute: EU units at **1** door in `08:00`, JP units at **6**. Rush hour is local, and it is already visible here |
| 5 | monitoring | *Q.10.2 — the same doors, per region*, then *Now add the totals up* | per region the count swings **8 → 48**, a factor of six, with each region peaking in a different minute; summed across regions the fleet total moves only between **56 and 72** |
| 6 | monitoring | *Q.10.3 — bunching, and what it costs to lose `->`*, the query cell only. Then **stop and predict** | nothing yet — and the question is worth answering before the data exists |
| 7 | simulator | *2) One bunching, and two things that are not* | 6 events |
| 8 | monitoring | the `SELECT` under *Q.10.3*, then read *Read the differences, not the result* | **exactly one row**. Three configurations went in; two are cut, for two different reasons |
| 9 | monitoring | *Q.10.4 — the unit that reconnects, and the events nobody misses*, including the watermark cell. Then **stop and predict** | the current watermark, and a question: which of six replayed events survive? |
| 10 | simulator | *3) A unit that reconnects with a backlog* | 6 events, with event times already in the past |
| 11 | monitoring | the `SELECT` under *Go to the simulator: section 3)*, the metrics cell, then *Two things to take away, and the second is a trap* | some minutes counted, at least one missing entirely, and a metric that does **not** mean what it says |
| 12 | monitoring | *The sizing arithmetic* → *Check your denominator before you believe the number* → *The counterintuitive part* | two rates computed from the same run, 63% apart. Both are correct; only one sizes a cluster |
| 13 | both | *Clean up* in the monitoring notebook, then the last cell of the simulator | the three queries stop; the two topics are deleted |

### an empty table is a question, not a failure

It happens by design at steps 2 and 6, and it has exactly three causes:

1. **the section has not been produced yet** — go to the simulator and run it;
2. **the micro-batch has not landed** — wait a second or two and re-run the `SELECT`. Spark
   consumes on its own schedule, not on yours;
3. **`Q.10.3` only**: the join writes in `append` mode, so a row is emitted when the watermark
   guarantees no partner can still arrive. Producing the next section pushes the watermark
   forward and flushes it.

What an empty table never means is that the query failed. A failed query raises, and
`q101.exception()` says so.

### if you are teaching this

Do steps 1 and 2 **before** the class: the image pull and the Maven download of the Kafka
connector are the only slow parts, and they are both invisible pedagogy. From step 3 on,
everything runs in seconds and the predictions are where the hour goes.

Two moments are worth the wait. `Q.10.3` is the one worth the hour: the same question EPL
answered in three lines with `->`, written here as a stream-stream self-join. And `Q.10.4`'s
metric is the trap — ask for a number before revealing it.

## 3. Stop

```
docker-compose down
```

## The fleet, and why it is small

24 units, three regions, eight each. A laptop cannot simulate 150,000 elevators and there
would be no point: the arithmetic that matters is done **on the measured rate** in the last
section, and it extrapolates. What the 24 units buy is the thing you cannot get by
extrapolating — **each region peaks at a different minute of the same absolute timeline**,
because rush hour is local.

The trace is **designed, not random**, and that is deliberate. Background traffic exists so
that the aggregations and the sizing have something plausible to work on. Every other section
isolates exactly one thing:

| section | what it isolates |
|---|---|
| 1 — background | six minutes, three regional peaks, one flat fleet total |
| 2 — bunching | one real bunching, one pair too far apart in time, one pair in opposite directions |
| 3 — straggler | a unit that reconnects with a backlog of events the watermark has already passed |

If `Q.10.3` returns more than one row, something is wrong — and that is the point of building
the trace that way. The EPL modules of this course use the same discipline for the same
reason: two queries shown side by side are a claim that they differ, and a trace that cannot
tell them apart proves nothing.

## The four queries

| | question | what it teaches |
|---|---|---|
| `Q.10.1` | doors per unit per minute | the baseline, and the state the watermark governs |
| `Q.10.2` | doors per region per minute | rush hour is local: regional peaks, flat fleet total |
| `Q.10.3` | two cars at one floor within 20 s | **the same question as EPL's `bunching`, without `->`** |
| `Q.10.4` | what happens to a unit that reconnects late | the case that breaks watermarks |

### `Q.10.3` is the one worth the hour

Lecture 7 wrote bunching in three lines, because EPL has a sequence operator:

```
every a=DoorOpened
  -> b=DoorOpened(floor=a.floor, servedDir=a.servedDir, car != a.car)
     where timer:within(20 sec)
```

Structured Streaming has no `->`. That much is not news by this point: lecture 9 made exactly
this move on the fire alarm, and stated the equivalence outright — a stream-stream join with
temporal constraints against `every x=A -> every B(id=x.id) where timer:within(2 minutes)`.
What is new here is that you write one yourself, for a rule you wrote in EPL three lectures
ago: a **stream-stream self-join** with a watermark on each side and the ordering written by
hand as a temporal predicate. It works, it is more verbose, and it is less expressive — and
you will have written both, which is the operational difference between a CEP engine and a
distributed stream processor with no theory required.

Three things the EPL version never had to say, and the notebook names each one: `b.ts > a.ts`
(a join is symmetric, `->` is not), two separate watermarks (the bound on state and the
business rule were one clause in EPL and are two decisions here), and `append` output mode (a
row is only final once no partner can still arrive).

### `Q.10.4` has a trap in the instrumentation

A unit reconnects and replays six events. Some are counted and some vanish, and which is
which depends only on where the watermark happened to be — nothing about the unit changed.

And **`numRowsDroppedByWatermark` does not count events.** It counts state rows, one per
`(window, key)` group: several dropped events for the same unit in the same minute are
pre-aggregated inside the batch and reported as **one**. Read it as "events lost" and you
under-count, by a factor that depends on how the backlog happens to be spread. That was
measured, not assumed: the same six late events were spread over one, two and three units,
and the metric reported 1, 2 and 3.

## On the outputs in these notebooks

Every number quoted in this module was executed twice, and the second time is the one that
matters. First against a file source carrying exactly the events the simulator produces, with
the notebook's own query cells run verbatim; then, the whole module end to end **on this
`docker-compose` stack, with the broker in place**. Every result matched — the partition
counts, the trace, all four queries, the watermark, the dropped-row metric.

What did not match were **two cells of the notebook**, and both were wrong in the same way:
they worked only because a file source let me decide where the micro-batch boundaries fell.
With Kafka the consumer decides, and the two assumptions broke — the instrumentation read an
idle batch, and a sum over a `memory` sink in `update` mode counted intermediate updates as
if they were events. Both are now fixed, and both earned a section of their own, because the
mistakes teach more than the numbers do.

**Nothing here is a prediction.** Where a result contradicted what was expected — the
dropped-row metric, the denominator of the rate, and the two cells above — the contradiction
was tested rather than argued, and what the test said is what this module now says.

## Acknowledgements

The elevator domain, the controller this module sits above and the `bunching` rule are
[Emanuele Della Valle](https://emanueledellavalle.org/)'s, from lectures 6 and 7 of this
course. The fleet, the designed trace and the four queries were built for this module by
Emanuele and [Claude](https://claude.com/product/overview) together: Claude designed the
trace and verified the queries, Emanuele ran the infrastructure and captured the traces.

Claude's work on this course is sponsored by
[Quantia Consulting](https://www.quantiaconsulting.com/).
