# EPL — Windows, reporting policies, and patterns: the fire alarm

*by [Emanuele Della Valle](https://emanueledellavalle.org/) and
[Claude](https://claude.com/product/overview)*

## Introduction

This is where EPL starts. One question, asked once and answered at the very end:

> **Count the fires detected by a set of smoke and temperature sensors in the last ten
> minutes.** A fire is detected when, at the same sensor, a smoke event is followed by a
> temperature above 50 °C within two minutes.

Read it again and notice how much is packed into two lines. *In the last ten minutes* is a
**window**. *Count* is an **aggregation** over that window, and asking for it at all raises
the question of **how often** the answer is republished. *Followed by, within two minutes* is
a **pattern** with a **guard**. Four ideas, and each of the three lectures this module serves
takes one or two of them.

Part 1 builds the windows and the aggregations. Part 2 asks the question that windows force
on you and that people usually discover too late: a continuous query has an answer at every
instant, so **when does it speak, and what does it say?** Part 3 brings the pattern operators
and finally answers the running example.

The module ends on a different question, about a building with two elevators, which the
[next lecture but two](https://github.com/Streaming-Data-Analytics/Courseware/tree/main/Streaming%20Data%20Engineering/EPL/epl-elevator-controller)
spends its whole hour on.

## Resources

* [espertech](https://www.espertech.com)
* [EPL documentation](http://esper.espertech.com/release-9.0.0/reference-esper/html_single/)
* [online environment to try EPL](http://esper-epl-tryout.appspot.com/epltryout/mainform.html)

## How this module is organised

| Part | Lecture | What it covers | Queries |
|---|---|---|---|
| **1** | 3 | Filtering, the landmark window, the four kinds of data window, aggregating over them | `Q.3.1` – `Q.3.11` |
| **2** | 4 | Reporting policies: `first`, `last`, `all`, `snapshot` | `Q.4.1` – `Q.4.8` |
| **3** | 5 | Patterns, `every`, guards, and the running example solved | `Q.5.1` – `Q.5.8` |

Every query is numbered `Q.<lecture>.<n>`, contiguously within its lecture. Part 2 uses a
trace of its own, given where it starts; parts 1 and 3 share the one below.

## The running example, and a note on the clock

The example above is stated in **minutes**, because that is the timescale a real building
runs on. The trace runs in **seconds**, so that a lecture can watch a whole story unfold
instead of waiting for it. Everything is scaled by the same factor: *ten minutes* becomes
`#time(10 seconds)`, *within two minutes* becomes `timer:within(2 seconds)`. The scaling is
uniform and it is the only difference. Nothing else about the example changes.

## Event types

```
create schema TemperatureSensorEvent (
  sensor string,
  temperature double
);

create schema SmokeSensorEvent (
  sensor string,
  smoke boolean
);

create schema FireEvent (
  sensor string,
  smoke boolean,
  temperature double
);
```

`FireEvent` is not produced by any sensor. It is the stream **we** are going to create in
part 3, out of the correlation between the other two. That a query can write a stream that
other queries then read is the idea the whole of part 3 turns on, and the reason the schema
is declared here rather than there.

## The trace

```
TemperatureSensorEvent={sensor='S1', temperature=30}
SmokeSensorEvent={sensor='S1', smoke=false}
t=t.plus(1 seconds)
TemperatureSensorEvent={sensor='S1', temperature=40}
SmokeSensorEvent={sensor='S1', smoke=true}
t=t.plus(1 seconds)
TemperatureSensorEvent={sensor='S1', temperature=55}
SmokeSensorEvent={sensor='S1', smoke=true}
t=t.plus(1 seconds)
TemperatureSensorEvent={sensor='S1', temperature=56}
TemperatureSensorEvent={sensor='S1', temperature=57}
SmokeSensorEvent={sensor='S1', smoke=true}
t=t.plus(1 seconds)
TemperatureSensorEvent={sensor='S1', temperature=58}
SmokeSensorEvent={sensor='S1', smoke=true}
t=t.plus(4 seconds)
t=t.plus(4 seconds)
t=t.plus(4 seconds)
t=t.plus(4 seconds)
```

Six temperature readings and five smoke readings, all from sensor `S1`, arriving between
08:00:00 and 08:00:04; then the clock runs on to 08:00:20 with nothing happening at all.

**Those four silent advances at the end are not padding.** Half of what a window does is
visible only when the stream goes quiet: rows leave, averages change without any new reading,
batches close on empty, and the count of fires falls back to zero on its own. A trace that
stops at the last event shows you an arrival and hides an expiry.

Drawn out:

![](img/time-line.png)

The drawing shows the events, which are all over by 08:00:04, and stops before the trailing
clock advances. It also predates the renumbering below.

## How to read the outputs in this file

Every result in this module was produced by running the statements on the
[online tool](http://esper-epl-tryout.appspot.com/epltryout/mainform.html) and pasting what
came back. Nothing is asserted from reading the query. The tool prints one block per instant
at which anything happened:

```
* At: <timestamp>
   * Statement: <the @name of the statement that produced these rows>
      * Insert            (or * Remove)
         * <one line per row>
```

Three things about that shape are worth knowing before you meet them:

* the `Statement:` level is **always** printed, even when only one statement is deployed;
* two blocks can carry the **same timestamp**. That is not a duplicate: the engine dispatches
  more than once at the same instant, and the order of those dispatches is itself information
  — you will meet it at `Q.3.7`;
* a statement can appear with **nothing under it**. That is an answer too, and `Q.3.11` is
  where it happens.

Where a query is shown side by side with another, both were deployed in the same run and the
transcript is filtered to the statements under discussion. Nothing is reordered.

**Two honest caveats.** The hand-drawings in `img/` were made before the queries were
renumbered and still carry the old labels: `Q0` is now `Q.3.1`, `Q0bis` is `Q.3.1bis`, `Q1`
is `Q.3.2` and `Q7` is `Q.3.7`. And in the runs that produced some of the transcripts below,
those statements still carried their old names; the names were substituted mechanically and
nothing else in any transcript was touched.

---

# Part 1 — lecture 3: windows and aggregations

## 1. Two ways to filter, one result

The first query is the one every SQL speaker writes without thinking: keep the readings above
50 °C.

```
@name('Q.3.1')
select *
from TemperatureSensorEvent
where temperature > 50;
```

The second says the same thing by putting the condition on the stream itself.

```
@name('Q.3.1bis')
select *
from TemperatureSensorEvent(temperature > 50);
```

Both were deployed in one run. Here is everything they emitted:

```
* At: 2001-01-01 08:00:02.000
   * Statement: Q.3.1
      * Insert
         * TemperatureSensorEvent={sensor='S1', temperature=55.0}
   * Statement: Q.3.1bis
      * Insert
         * TemperatureSensorEvent={sensor='S1', temperature=55.0}
* At: 2001-01-01 08:00:03.000
   * Statement: Q.3.1
      * Insert
         * TemperatureSensorEvent={sensor='S1', temperature=56.0}
   * Statement: Q.3.1bis
      * Insert
         * TemperatureSensorEvent={sensor='S1', temperature=56.0}
* At: 2001-01-01 08:00:03.000
   * Statement: Q.3.1
      * Insert
         * TemperatureSensorEvent={sensor='S1', temperature=57.0}
   * Statement: Q.3.1bis
      * Insert
         * TemperatureSensorEvent={sensor='S1', temperature=57.0}
* At: 2001-01-01 08:00:04.000
   * Statement: Q.3.1
      * Insert
         * TemperatureSensorEvent={sensor='S1', temperature=58.0}
   * Statement: Q.3.1bis
      * Insert
         * TemperatureSensorEvent={sensor='S1', temperature=58.0}
```

**They are indistinguishable.** Same four rows, same four instants, same values. The readings
of 30 and 40 produce nothing at all — no empty block, no null, nothing.

So why does the language have both? Because they do not do the same work.

![](img/Q0.png)

In `Q.3.1` every reading **enters the query**, and the query throws most of them away. The
filter is part of the query's own evaluation.

![](img/Q0bis.png)

In `Q.3.1bis` the condition is part of the **stream expression**: readings that fail it never
reach the query, and the query is not woken up for them.

This is the first thing that separates a stream engine from a database, and it is invisible
in the output on purpose. Both drawings show the same four numbers coming out of the right
hand side; what differs is what happens on the left. With one sensor and six readings it is a
curiosity. With ten thousand sensors it is the difference between an engine that evaluates
ten thousand queries per second and one that evaluates forty.

## 2. The landmark window

Now something SQL cannot do at all: an average that has an answer after **every** reading.

```
@name('Q.3.2')
select sensor, avg(temperature) as avgTemp
from TemperatureSensorEvent
group by sensor;
```

```
* At: 2001-01-01 08:00:00.000
   * Statement: Q.3.2
      * Insert
         * Q.3.2-output={sensor='S1', avgTemp=30.0}
* At: 2001-01-01 08:00:01.000
   * Statement: Q.3.2
      * Insert
         * Q.3.2-output={sensor='S1', avgTemp=35.0}
* At: 2001-01-01 08:00:02.000
   * Statement: Q.3.2
      * Insert
         * Q.3.2-output={sensor='S1', avgTemp=41.666666666666664}
* At: 2001-01-01 08:00:03.000
   * Statement: Q.3.2
      * Insert
         * Q.3.2-output={sensor='S1', avgTemp=45.25}
* At: 2001-01-01 08:00:03.000
   * Statement: Q.3.2
      * Insert
         * Q.3.2-output={sensor='S1', avgTemp=47.6}
* At: 2001-01-01 08:00:04.000
   * Statement: Q.3.2
      * Insert
         * Q.3.2-output={sensor='S1', avgTemp=49.333333333333336}
```

Six readings in, six averages out — one per reading, each one the average of everything seen
so far.

![](img/Q1.png)

The drawing adds what the transcript cannot show: the engine is not re-reading six numbers to
produce the sixth average. It keeps two numbers, a count and a running mean, and folds each
new reading into them. **Old data can be forgotten.** That is what makes the query runnable
forever on a stream that never ends.

There is no window syntax anywhere in `Q.3.2`, and yet there is a window: it opens when the
query is deployed and never closes. It is called a **landmark window**, and it is the default
when you write nothing. Spark's *logical unbounded table* is the same idea under a different
name.

Not every computation survives this treatment. There is no exact streaming algorithm for the
standard deviation — only an
[approximate one](https://math.stackexchange.com/questions/198336/how-to-calculate-standard-deviation-with-streaming-inputs),
and it assumes the process is stationary. Whether a function can be computed incrementally is
a property of the function, not of the engine.

## 3. Four kinds of data window

A landmark window grows forever, which is rarely what anyone wants. Bound it, and there are
exactly two choices to make, independently of each other:

|  | **by time** (*logical*) | **by count** (*physical*) |
|---|---|---|
| **report on a boundary** (*tumbling*) | `#time_batch(2 seconds)` — `Q.3.3` | `#length_batch(2)` — `Q.3.4` |
| **report on every event** (*sliding*) | `#time(4 seconds)` — `Q.3.5` | `#length(4)` — `Q.3.6` |

### Q.3.3 — logical tumbling

```
@name('Q.3.3')
select *
from TemperatureSensorEvent#time_batch(2 seconds);
```

```
* At: 2001-01-01 08:00:02.000
   * Statement: Q.3.3
      * Insert
         * TemperatureSensorEvent={sensor='S1', temperature=30.0}
         * TemperatureSensorEvent={sensor='S1', temperature=40.0}
* At: 2001-01-01 08:00:04.000
   * Statement: Q.3.3
      * Insert
         * TemperatureSensorEvent={sensor='S1', temperature=55.0}
         * TemperatureSensorEvent={sensor='S1', temperature=56.0}
         * TemperatureSensorEvent={sensor='S1', temperature=57.0}
* At: 2001-01-01 08:00:06.000
   * Statement: Q.3.3
      * Insert
         * TemperatureSensorEvent={sensor='S1', temperature=58.0}
```

Three batches: `[00,02)`, `[02,04)`, `[04,06)`. Look at the first one — it holds 30 and 40
but **not** the 55 that arrives at 08:00:02, the very instant the batch closes. The batch
callback runs *before* the events of its own instant. Keep hold of that; it explains four
more things in this module.

Then, from 08:00:06 on, nothing. Batches `[06,08)`, `[08,10)` and the rest are empty and the
query says nothing about them. **A plain projection has nothing to say about nothing.**

### Q.3.4 — physical tumbling

```
@name('Q.3.4')
select *
from TemperatureSensorEvent#length_batch(2);
```

```
* At: 2001-01-01 08:00:01.000
   * Statement: Q.3.4
      * Insert
         * TemperatureSensorEvent={sensor='S1', temperature=30.0}
         * TemperatureSensorEvent={sensor='S1', temperature=40.0}
* At: 2001-01-01 08:00:03.000
   * Statement: Q.3.4
      * Insert
         * TemperatureSensorEvent={sensor='S1', temperature=55.0}
         * TemperatureSensorEvent={sensor='S1', temperature=56.0}
* At: 2001-01-01 08:00:04.000
   * Statement: Q.3.4
      * Insert
         * TemperatureSensorEvent={sensor='S1', temperature=57.0}
         * TemperatureSensorEvent={sensor='S1', temperature=58.0}
```

Also three batches, also six rows, and **not the same grouping**: `{30,40}`, `{55,56}`,
`{57,58}`. The second batch straddles 08:00:02 and 08:00:03, and the third straddles 08:00:03
and 08:00:04. This window has no idea what time it is. It counts to two and reports.

### Q.3.5 and Q.3.6 — sliding, logical and physical

```
@name('Q.3.5')
select *
from TemperatureSensorEvent#time(4 seconds);
```

```
@name('Q.3.6')
select *
from TemperatureSensorEvent#length(4);
```

```
* At: 2001-01-01 08:00:00.000
   * Statement: Q.3.5
      * Insert
         * TemperatureSensorEvent={sensor='S1', temperature=30.0}
   * Statement: Q.3.6
      * Insert
         * TemperatureSensorEvent={sensor='S1', temperature=30.0}
* At: 2001-01-01 08:00:01.000
   * Statement: Q.3.5
      * Insert
         * TemperatureSensorEvent={sensor='S1', temperature=40.0}
   * Statement: Q.3.6
      * Insert
         * TemperatureSensorEvent={sensor='S1', temperature=40.0}
* At: 2001-01-01 08:00:02.000
   * Statement: Q.3.5
      * Insert
         * TemperatureSensorEvent={sensor='S1', temperature=55.0}
   * Statement: Q.3.6
      * Insert
         * TemperatureSensorEvent={sensor='S1', temperature=55.0}
* At: 2001-01-01 08:00:03.000
   * Statement: Q.3.5
      * Insert
         * TemperatureSensorEvent={sensor='S1', temperature=56.0}
   * Statement: Q.3.6
      * Insert
         * TemperatureSensorEvent={sensor='S1', temperature=56.0}
* At: 2001-01-01 08:00:03.000
   * Statement: Q.3.5
      * Insert
         * TemperatureSensorEvent={sensor='S1', temperature=57.0}
   * Statement: Q.3.6
      * Insert
         * TemperatureSensorEvent={sensor='S1', temperature=57.0}
* At: 2001-01-01 08:00:04.000
   * Statement: Q.3.5
      * Insert
         * TemperatureSensorEvent={sensor='S1', temperature=58.0}
   * Statement: Q.3.6
      * Insert
         * TemperatureSensorEvent={sensor='S1', temperature=58.0}
```

Six rows each, one per arrival, and the two are **identical** — four seconds and four events
produce the same output, which ought to be alarming.

It is not, and the reason matters more than the observation: a plain `select *` carries only
the **insert stream**. One arrival is one insert whatever window sits behind it, so the shape
of the window is simply not observable this way. Nothing here distinguishes a four-second
window from a four-event one, or either from no window at all.

Two ways to make it visible: **aggregate** over the window, which is the whole of section 4,
or ask for the removals with `irstream`, which you will see at `Q.3.9probe`.

---

## 4. Aggregating over a window

Put the average of section 2 on top of each window of section 3, and the four shapes finally
become visible — because an aggregation reports the window's *contents*, not its arrivals.

### Q.3.7 — the sliding average, against the landmark one

```
@name('Q.3.7')
select sensor, avg(temperature) as avgTemp
from TemperatureSensorEvent#time(4 seconds)
group by sensor;
```

Deployed together with `Q.3.2` so the two can be read against each other:

```
* At: 2001-01-01 08:00:00.000
   * Statement: Q.3.2
      * Insert
         * Q.3.2-output={sensor='S1', avgTemp=30.0}
   * Statement: Q.3.7
      * Insert
         * Q.3.7-output={sensor='S1', avgTemp=30.0}
* At: 2001-01-01 08:00:01.000
   * Statement: Q.3.2
      * Insert
         * Q.3.2-output={sensor='S1', avgTemp=35.0}
   * Statement: Q.3.7
      * Insert
         * Q.3.7-output={sensor='S1', avgTemp=35.0}
* At: 2001-01-01 08:00:02.000
   * Statement: Q.3.2
      * Insert
         * Q.3.2-output={sensor='S1', avgTemp=41.666666666666664}
   * Statement: Q.3.7
      * Insert
         * Q.3.7-output={sensor='S1', avgTemp=41.666666666666664}
* At: 2001-01-01 08:00:03.000
   * Statement: Q.3.2
      * Insert
         * Q.3.2-output={sensor='S1', avgTemp=45.25}
   * Statement: Q.3.7
      * Insert
         * Q.3.7-output={sensor='S1', avgTemp=45.25}
* At: 2001-01-01 08:00:03.000
   * Statement: Q.3.2
      * Insert
         * Q.3.2-output={sensor='S1', avgTemp=47.6}
   * Statement: Q.3.7
      * Insert
         * Q.3.7-output={sensor='S1', avgTemp=47.6}
* At: 2001-01-01 08:00:04.000
   * Statement: Q.3.7
      * Insert
         * Q.3.7-output={sensor='S1', avgTemp=52.0}
* At: 2001-01-01 08:00:04.000
   * Statement: Q.3.2
      * Insert
         * Q.3.2-output={sensor='S1', avgTemp=49.333333333333336}
   * Statement: Q.3.7
      * Insert
         * Q.3.7-output={sensor='S1', avgTemp=53.2}
* At: 2001-01-01 08:00:05.000
   * Statement: Q.3.7
      * Insert
         * Q.3.7-output={sensor='S1', avgTemp=56.5}
* At: 2001-01-01 08:00:06.000
   * Statement: Q.3.7
      * Insert
         * Q.3.7-output={sensor='S1', avgTemp=57.0}
* At: 2001-01-01 08:00:07.000
   * Statement: Q.3.7
      * Insert
         * Q.3.7-output={sensor='S1', avgTemp=58.0}
* At: 2001-01-01 08:00:08.000
   * Statement: Q.3.7
      * Insert
         * Q.3.7-output={sensor='S1', avgTemp=(null)}
```

![](img/EPL07.png)

They agree for five readings and then part company for good. Three things in that transcript
are worth stopping on.

**The two blocks at 08:00:03.** `Q.3.2` emits 45.25 and then 47.6 as two separate rows in two
separate blocks with the same timestamp, because 56 and 57 both arrive at 08:00:03. The engine
dispatches **once per event, not once per instant**.

**The two blocks at 08:00:04, and their order.** The first carries only `Q.3.7`, reporting
52.0 — the average after the reading of 30 has aged out of the four-second window. The second
carries the arrival of 58 and the new average, 53.2. The eviction is dispatched **before** the
arrival at the same millisecond, and it is a separate dispatch. Nothing in the query says so
and nothing could: this is engine behaviour, and the only way to know it is to run it.

**The four rows `Q.3.2` never produces.** From 08:00:05 to 08:00:08, `Q.3.7` reports 56.5,
57.0, 58.0 and finally `avgTemp=(null)` — four answers driven by nothing but the clock, as
each reading ages out. The landmark query, which forgets nothing, has nothing to say. **The
last of those rows is the query telling you the window is empty**, and part 2 is about
whether you actually get to hear it.

### Q.3.8 — the same average over a physical window

```
@name('Q.3.8')
select sensor, avg(temperature) as avgTemp
from TemperatureSensorEvent#length(4)
group by sensor;
```

```
* At: 2001-01-01 08:00:00.000
   * Statement: Q.3.8
      * Insert
         * Q.3.8-output={sensor='S1', avgTemp=30.0}
* At: 2001-01-01 08:00:01.000
   * Statement: Q.3.8
      * Insert
         * Q.3.8-output={sensor='S1', avgTemp=35.0}
* At: 2001-01-01 08:00:02.000
   * Statement: Q.3.8
      * Insert
         * Q.3.8-output={sensor='S1', avgTemp=41.666666666666664}
* At: 2001-01-01 08:00:03.000
   * Statement: Q.3.8
      * Insert
         * Q.3.8-output={sensor='S1', avgTemp=45.25}
* At: 2001-01-01 08:00:03.000
   * Statement: Q.3.8
      * Insert
         * Q.3.8-output={sensor='S1', avgTemp=52.0}
* At: 2001-01-01 08:00:04.000
   * Statement: Q.3.8
      * Insert
         * Q.3.8-output={sensor='S1', avgTemp=56.5}
```

Six rows, and then **silence** — no null, ever. `Q.3.7` and `Q.3.8` are the same aggregation
over windows of nominally the same size, and they end differently:

> A **time** window empties itself when the stream goes quiet. A **count** window cannot: it
> only evicts when a new event pushes an old one out, so with no arrivals it holds its last
> four readings forever, and keeps answering with an average of data that may be hours old.

That is not a detail. It is the choice between a query that can tell you the sensor has gone
silent and one that cannot.

### Q.3.9 and Q.3.9probe — the tumbling average, and where the removals were hiding

```
@name('Q.3.9')
select sensor, avg(temperature) as avgTemp
from TemperatureSensorEvent#time_batch(4 seconds)
group by sensor;
```

Deployed with a probe that asks for the removals as well:

```
@name('Q.3.9probe')
select irstream *
from TemperatureSensorEvent#time_batch(4 seconds);
```

```
* At: 2001-01-01 08:00:04.000
   * Statement: Q.3.9
      * Insert
         * Q.3.9-output={sensor='S1', avgTemp=47.6}
   * Statement: Q.3.9probe
      * Insert
         * TemperatureSensorEvent={sensor='S1', temperature=30.0}
         * TemperatureSensorEvent={sensor='S1', temperature=40.0}
         * TemperatureSensorEvent={sensor='S1', temperature=55.0}
         * TemperatureSensorEvent={sensor='S1', temperature=56.0}
         * TemperatureSensorEvent={sensor='S1', temperature=57.0}
* At: 2001-01-01 08:00:08.000
   * Statement: Q.3.9
      * Insert
         * Q.3.9-output={sensor='S1', avgTemp=58.0}
   * Statement: Q.3.9probe
      * Insert
         * TemperatureSensorEvent={sensor='S1', temperature=58.0}
      * Remove
         * TemperatureSensorEvent={sensor='S1', temperature=30.0}
         * TemperatureSensorEvent={sensor='S1', temperature=40.0}
         * TemperatureSensorEvent={sensor='S1', temperature=55.0}
         * TemperatureSensorEvent={sensor='S1', temperature=56.0}
         * TemperatureSensorEvent={sensor='S1', temperature=57.0}
* At: 2001-01-01 08:00:12.000
   * Statement: Q.3.9
      * Insert
         * Q.3.9-output={sensor='S1', avgTemp=(null)}
   * Statement: Q.3.9probe
      * Remove
         * TemperatureSensorEvent={sensor='S1', temperature=58.0}
```

Read the probe first, because it explains everything else in this module about windows.

* at **08:00:04**, five inserts and no removals — the first batch arriving;
* at **08:00:08**, one insert and **five removals** — the second batch arriving as the first
  leaves;
* at **08:00:12**, one removal and no insert — the second batch leaving with nothing to
  replace it. `Q.3.9` re-evaluates the average over what is left, which is nothing, and
  reports `(null)`;
* and then **nothing at all**, at 08:00:16 and 08:00:20. The batches are still closing on
  schedule, but there is neither an insert nor a removal to report.

So the null at 08:00:12 is **not** the empty batch announcing itself. It is the last echo of
the batch before it. Once there is nothing left to remove, the query falls silent — which is
the opposite of what the row at 08:00:12 invites you to assume, and matters for anything
downstream that reads silence as *unchanged*.

The probe is here to be run once and then removed. It is the only statement in this module
that uses `irstream`, and the removals it reveals were present behind `Q.3.3`, `Q.3.5` and
`Q.3.6` all along.

### Q.3.10 — the tumbling average by count

```
@name('Q.3.10')
select sensor, avg(temperature) as avgTemp
from TemperatureSensorEvent#length_batch(4)
group by sensor;
```

```
* At: 2001-01-01 08:00:03.000
   * Statement: Q.3.10
      * Insert
         * Q.3.10-output={sensor='S1', avgTemp=45.25}
```

**One row.** The first four readings make a batch and are reported; 57 and 58 are left in a
batch that never reaches four, and are never reported at all.

Set that against `Q.3.9`, which fired three times over the same trace, and the pair says
something neither says alone: **a time-driven window cannot be starved, a count-driven one
can.** `Q.3.9` keeps reporting because the clock keeps arriving. `Q.3.10` waits for two
readings that never come, and two real measurements are silently stranded.

### Q.3.11 — reporting more often than the window slides

```
@name('Q.3.11')
select sensor, avg(temperature) as avgTemp
from TemperatureSensorEvent#time(4 seconds)
group by sensor
output snapshot every 2 seconds;
```

A four-second sliding window, asked for every two seconds. The window and the reporting rhythm
are now **two independent settings**, which is what a *hopping* window is.

```
* At: 2001-01-01 08:00:02.000
   * Statement: Q.3.11
      * Insert
         * Q.3.11-output={sensor='S1', avgTemp=35.0}
* At: 2001-01-01 08:00:04.000
   * Statement: Q.3.11
      * Insert
         * Q.3.11-output={sensor='S1', avgTemp=52.0}
* At: 2001-01-01 08:00:06.000
   * Statement: Q.3.11
      * Insert
         * Q.3.11-output={sensor='S1', avgTemp=57.0}
* At: 2001-01-01 08:00:08.000
   * Statement: Q.3.11
      *
* At: 2001-01-01 08:00:10.000
   * Statement: Q.3.11
      *
* At: 2001-01-01 08:00:12.000
   * Statement: Q.3.11
      *
* At: 2001-01-01 08:00:14.000
   * Statement: Q.3.11
      *
* At: 2001-01-01 08:00:16.000
   * Statement: Q.3.11
      *
* At: 2001-01-01 08:00:18.000
   * Statement: Q.3.11
      *
* At: 2001-01-01 08:00:20.000
   * Statement: Q.3.11
      *
```

Three answers — 35.0, 52.0, 57.0 — and then **seven blocks in which `Q.3.11` is named and says
nothing**, one every two seconds, marching on to the end of the trace.

That is not a rendering accident, and the number matters. The window has emptied, the group
has no members, and this combination of clauses reports an empty group by producing no row —
but the statement is still being **called on schedule**, and will keep being called for as
long as the query runs. Three empty blocks would look like a tail. Seven, at a fixed rhythm
with nothing to say, look like what they are: a query that has stopped answering and has not
stopped being asked.

Compare it with `Q.3.7`, four lines up the page, which reported exactly the same emptiness as
`avgTemp=(null)`. Same data, same window, same `group by`, two different silences. The clause
that differs is `output snapshot every`, and that is precisely what part 2 is about — and what
goes wrong on the other end of it.

## 5. One instant, seen whole

Every transcript so far has been filtered to the statements under discussion. Here is a single
instant, 08:00:04, with all thirteen queries deployed and nothing filtered out:

```
* At: 2001-01-01 08:00:04.000
   * Statement: Q.3.3
      * Insert
         * TemperatureSensorEvent={sensor='S1', temperature=55.0}
         * TemperatureSensorEvent={sensor='S1', temperature=56.0}
         * TemperatureSensorEvent={sensor='S1', temperature=57.0}
   * Statement: Q.3.7
      * Insert
         * Q.3.7-output={sensor='S1', avgTemp=52.0}
   * Statement: Q.3.9
      * Insert
         * Q.3.9-output={sensor='S1', avgTemp=47.6}
   * Statement: Q.3.9probe
      * Insert
         * TemperatureSensorEvent={sensor='S1', temperature=30.0}
         * TemperatureSensorEvent={sensor='S1', temperature=40.0}
         * TemperatureSensorEvent={sensor='S1', temperature=55.0}
         * TemperatureSensorEvent={sensor='S1', temperature=56.0}
         * TemperatureSensorEvent={sensor='S1', temperature=57.0}
   * Statement: Q.3.11
      * Insert
         * Q.3.11-output={sensor='S1', avgTemp=52.0}
* At: 2001-01-01 08:00:04.000
   * Statement: Q.3.1
      * Insert
         * TemperatureSensorEvent={sensor='S1', temperature=58.0}
   * Statement: Q.3.1bis
      * Insert
         * TemperatureSensorEvent={sensor='S1', temperature=58.0}
   * Statement: Q.3.2
      * Insert
         * Q.3.2-output={sensor='S1', avgTemp=49.333333333333336}
   * Statement: Q.3.4
      * Insert
         * TemperatureSensorEvent={sensor='S1', temperature=57.0}
         * TemperatureSensorEvent={sensor='S1', temperature=58.0}
   * Statement: Q.3.5
      * Insert
         * TemperatureSensorEvent={sensor='S1', temperature=58.0}
   * Statement: Q.3.6
      * Insert
         * TemperatureSensorEvent={sensor='S1', temperature=58.0}
   * Statement: Q.3.7
      * Insert
         * Q.3.7-output={sensor='S1', avgTemp=53.2}
   * Statement: Q.3.8
      * Insert
         * Q.3.8-output={sensor='S1', avgTemp=56.5}
```

**Two dispatches, same millisecond, and the split between them is not arbitrary.**

The first block is everything **the clock** caused: `Q.3.3`'s two-second batch closing,
`Q.3.7`'s four-second window evicting the reading of 30, `Q.3.9`'s four-second batch closing,
the probe showing that batch's five rows, and `Q.3.11`'s scheduled report. Not one of them was
triggered by an event.

The second block is everything **the arrival of 58** caused: the two filters, the landmark
average, the physical batch that finally reached two, the two sliding windows, and the new
averages.

That is the rule you have now met four times, stated once and for all: **at any instant, the
engine does what the clock owes first, and only then delivers the events of that instant.**
Every callback in this module — batch boundaries, window evictions, `output ... every`
reports, and in part 3 the expiry of a pattern guard — sits in the first block. Everything
driven by an arrival sits in the second.

## 6. What "nothing left" looks like — part 1's summary

| statement | when the window has emptied |
|---|---|
| plain `select *` over any window (`Q.3.3`, `Q.3.5`) | nothing at all, not even a block |
| aggregation with `group by`, no `output` clause (`Q.3.7`, `Q.3.9`) | the group, with a **null** aggregate |
| aggregation with `group by` and `output snapshot every` (`Q.3.11`) | the statement, named, with an **empty body** |

Three behaviours, all executed, none of them derivable from the others. A fourth is waiting in
part 2, and it is the one you want when a dashboard is on the other end.

---

# Part 2 — lecture 4: when does a query speak, and what does it say?

Part 1 left three different silences and no way to choose between them. That choice has a
name in EPL — the **reporting policy** — and it is one word in the `output` clause. It is also
the part of the language people skip, and then spend an afternoon debugging a dashboard.

The question underneath is simple. A continuous query has an answer at every instant. Asking
it to report *every five seconds* does not say **which** answer you want, and there are four
sensible ones.

## The trace for this part

Deliberately regular, so that the policies are the only thing changing:

```
TemperatureSensorEvent={sensor='S1', temperature=22}
TemperatureSensorEvent={sensor='S1', temperature=23}
t=t.plus(5 seconds)
TemperatureSensorEvent={sensor='S2', temperature=24}
TemperatureSensorEvent={sensor='S2', temperature=25}
t=t.plus(5 seconds)
TemperatureSensorEvent={sensor='S3', temperature=26}
TemperatureSensorEvent={sensor='S3', temperature=27}
t=t.plus(5 seconds)
t=t.plus(5 seconds)
t=t.plus(5 seconds)
```

Two readings at 08:00:00, two more at 08:00:05, two more at 08:00:10 — each pair from a
different sensor — and then the clock runs on to 08:00:25 with nothing arriving. Reports fall
every five seconds, at :05, :10, :15, :20 and :25. The first three land on the same instant as
a pair of arrivals, which matters; the last two land on an empty building, which matters more.

## 1. The four policies, side by side

```
@name('Q.4.1')
select *
from TemperatureSensorEvent#time(10 seconds)
output first every 5 seconds;
```

```
@name('Q.4.2')
select *
from TemperatureSensorEvent#time(10 seconds)
output last every 5 seconds;
```

```
@name('Q.4.3')
select *
from TemperatureSensorEvent#time(10 seconds)
output all every 5 seconds;
```

```
@name('Q.4.4')
select *
from TemperatureSensorEvent#time(10 seconds)
output snapshot every 5 seconds;
```

All four deployed at once, same window, same rhythm, different last word:

```
* At: 2001-01-01 08:00:00.000
   * Statement: Q.4.1
      * Insert
         * TemperatureSensorEvent={sensor='S1', temperature=22.0}
* At: 2001-01-01 08:00:05.000
   * Statement: Q.4.2
      * Insert
         * TemperatureSensorEvent={sensor='S1', temperature=23.0}
   * Statement: Q.4.3
      * Insert
         * TemperatureSensorEvent={sensor='S1', temperature=22.0}
         * TemperatureSensorEvent={sensor='S1', temperature=23.0}
   * Statement: Q.4.4
      * Insert
         * TemperatureSensorEvent={sensor='S1', temperature=22.0}
         * TemperatureSensorEvent={sensor='S1', temperature=23.0}
* At: 2001-01-01 08:00:05.000
   * Statement: Q.4.1
      * Insert
         * TemperatureSensorEvent={sensor='S2', temperature=24.0}
* At: 2001-01-01 08:00:10.000
   * Statement: Q.4.2
      * Insert
         * TemperatureSensorEvent={sensor='S2', temperature=25.0}
   * Statement: Q.4.3
      * Insert
         * TemperatureSensorEvent={sensor='S2', temperature=24.0}
         * TemperatureSensorEvent={sensor='S2', temperature=25.0}
   * Statement: Q.4.4
      * Insert
         * TemperatureSensorEvent={sensor='S2', temperature=24.0}
         * TemperatureSensorEvent={sensor='S2', temperature=25.0}
* At: 2001-01-01 08:00:10.000
   * Statement: Q.4.1
      * Insert
         * TemperatureSensorEvent={sensor='S3', temperature=26.0}
* At: 2001-01-01 08:00:15.000
   * Statement: Q.4.2
      * Insert
         * TemperatureSensorEvent={sensor='S3', temperature=27.0}
   * Statement: Q.4.3
      * Insert
         * TemperatureSensorEvent={sensor='S3', temperature=26.0}
         * TemperatureSensorEvent={sensor='S3', temperature=27.0}
   * Statement: Q.4.4
      * Insert
         * TemperatureSensorEvent={sensor='S3', temperature=26.0}
         * TemperatureSensorEvent={sensor='S3', temperature=27.0}
* At: 2001-01-01 08:00:20.000
   * Statement: Q.4.2
      *
   * Statement: Q.4.3
      *
   * Statement: Q.4.4
      *
* At: 2001-01-01 08:00:25.000
   * Statement: Q.4.2
      *
   * Statement: Q.4.3
      *
   * Statement: Q.4.4
      *
```

Start with what is **not** where you expect it. `Q.4.1` does not report at 08:00:05 with the
others. It reports at **08:00:00**, the moment the first reading arrives, and then says nothing
until its interval closes. That is what `first` means: *let the first one through immediately,
then be quiet*. The other three wait for the boundary.

Then the two blocks at 08:00:05, in that order. The first is the boundary report for the
interval that just ended, and it contains only 22 and 23. The second is `Q.4.1` releasing the
24 that arrived at that same instant. **The callback runs before the events of its own
instant** — part 1 section 5, again, and it will not be the last time.

Now the last two blocks, where nothing has arrived for ten seconds. `Q.4.2`, `Q.4.3` and
`Q.4.4` are each **named with nothing under them**: called on schedule, answering with silence.
`Q.4.1` is not there at all — **no entry, in either block.**

That is not the tool being inconsistent. It is `first` being, once again, the one policy that
is not driven by the clock: it fires when an event *arrives*, so with no arrivals it has
nothing scheduled and nothing to report. Both of its peculiarities — reporting early at
08:00:00, and disappearing entirely at 08:00:20 — are the same fact seen from two ends.

| policy | the question it answers | when nothing has arrived |
|---|---|---|
| `first` | *has anything happened?* — tell me at once, then leave me alone | absent; it has no callback |
| `last` | *what is the latest?* | named, empty |
| `all` | *what has arrived since I last reported?* | named, empty |
| `snapshot` | *what is in the window right now?* | named, empty — the window is empty too |

## 2. When `all` and `snapshot` look like synonyms

Read the first three reports again and `all` and `snapshot` are identical, row for row. The
temptation is to conclude they are two names for the same thing.

They are not, and the agreement is an artefact of the numbers. The window is ten seconds and
the report is every five, so on every boundary the previous interval's readings expire on the
*same millisecond* the callback fires. *Since when* and *what is there now* happen to have the
same answer.

Change one number — the window, from 10 to 20 — and nothing else:

```
@name('Q.4.5')
select *
from TemperatureSensorEvent#time(20 seconds)
output all every 5 seconds;
```

```
@name('Q.4.6')
select *
from TemperatureSensorEvent#time(20 seconds)
output snapshot every 5 seconds;
```

```
* At: 2001-01-01 08:00:05.000
   * Statement: Q.4.5
      * Insert
         * TemperatureSensorEvent={sensor='S1', temperature=22.0}
         * TemperatureSensorEvent={sensor='S1', temperature=23.0}
   * Statement: Q.4.6
      * Insert
         * TemperatureSensorEvent={sensor='S1', temperature=22.0}
         * TemperatureSensorEvent={sensor='S1', temperature=23.0}
* At: 2001-01-01 08:00:10.000
   * Statement: Q.4.5
      * Insert
         * TemperatureSensorEvent={sensor='S2', temperature=24.0}
         * TemperatureSensorEvent={sensor='S2', temperature=25.0}
   * Statement: Q.4.6
      * Insert
         * TemperatureSensorEvent={sensor='S1', temperature=22.0}
         * TemperatureSensorEvent={sensor='S1', temperature=23.0}
         * TemperatureSensorEvent={sensor='S2', temperature=24.0}
         * TemperatureSensorEvent={sensor='S2', temperature=25.0}
* At: 2001-01-01 08:00:15.000
   * Statement: Q.4.5
      * Insert
         * TemperatureSensorEvent={sensor='S3', temperature=26.0}
         * TemperatureSensorEvent={sensor='S3', temperature=27.0}
   * Statement: Q.4.6
      * Insert
         * TemperatureSensorEvent={sensor='S1', temperature=22.0}
         * TemperatureSensorEvent={sensor='S1', temperature=23.0}
         * TemperatureSensorEvent={sensor='S2', temperature=24.0}
         * TemperatureSensorEvent={sensor='S2', temperature=25.0}
         * TemperatureSensorEvent={sensor='S3', temperature=26.0}
         * TemperatureSensorEvent={sensor='S3', temperature=27.0}
* At: 2001-01-01 08:00:20.000
   * Statement: Q.4.5
      *
   * Statement: Q.4.6
      * Insert
         * TemperatureSensorEvent={sensor='S2', temperature=24.0}
         * TemperatureSensorEvent={sensor='S2', temperature=25.0}
         * TemperatureSensorEvent={sensor='S3', temperature=26.0}
         * TemperatureSensorEvent={sensor='S3', temperature=27.0}
* At: 2001-01-01 08:00:25.000
   * Statement: Q.4.5
      *
   * Statement: Q.4.6
      * Insert
         * TemperatureSensorEvent={sensor='S3', temperature=26.0}
         * TemperatureSensorEvent={sensor='S3', temperature=27.0}
```

They separate immediately, and then keep separating.

`Q.4.6`, the snapshot, reports **2 rows, then 4, then 6, then 4, then 2**. Watch it fill as
readings arrive and drain as they age out, with the turn at 08:00:15 where the last pair
arrives and the first pair is one instant from leaving. Nothing but the clock produces the
second half of that sequence.

`Q.4.5`, `all`, reports two rows per interval while readings are arriving — and then, at
08:00:20 and 08:00:25, **nothing at all**, an empty body, while `Q.4.6` beside it is still
reporting four rows and then two. The window is *not* empty. `all` simply has nothing **new**
to say about it.

That is the sentence to keep:

> `all` does not mean *repeat everything*. It means **everything since the last report** — and
> when nothing has arrived, that is nothing.

Which also settles why the previous example is a bad place to build intuition and a good place
to be warned. Whenever two policies agree, ask what would have to change for them to disagree.

## 3. The same choice over an aggregation

Everything so far was `select *`, where the policy applies to a window of rows. Put an
aggregation with a `group by` underneath and the policy applies to something else entirely:
the **aggregation's own state**, one entry per group.

```
@name('Q.4.7')
select sensor, avg(temperature) as avgTemp
from TemperatureSensorEvent#time(10 seconds)
group by sensor
output all every 5 seconds;
```

```
@name('Q.4.8')
select sensor, avg(temperature) as avgTemp
from TemperatureSensorEvent#time(10 seconds)
group by sensor
output snapshot every 5 seconds;
```

```
* At: 2001-01-01 08:00:05.000
   * Statement: Q.4.7
      * Insert
         * Q.4.7-output={sensor='S1', avgTemp=22.5}
   * Statement: Q.4.8
      * Insert
         * Q.4.8-output={sensor='S1', avgTemp=22.5}
* At: 2001-01-01 08:00:10.000
   * Statement: Q.4.7
      * Insert
         * Q.4.7-output={sensor='S1', avgTemp=(null)}
         * Q.4.7-output={sensor='S2', avgTemp=24.5}
   * Statement: Q.4.8
      * Insert
         * Q.4.8-output={sensor='S2', avgTemp=24.5}
* At: 2001-01-01 08:00:15.000
   * Statement: Q.4.7
      * Insert
         * Q.4.7-output={sensor='S1', avgTemp=(null)}
         * Q.4.7-output={sensor='S2', avgTemp=(null)}
         * Q.4.7-output={sensor='S3', avgTemp=26.5}
   * Statement: Q.4.8
      * Insert
         * Q.4.8-output={sensor='S3', avgTemp=26.5}
* At: 2001-01-01 08:00:20.000
   * Statement: Q.4.7
      * Insert
         * Q.4.7-output={sensor='S1', avgTemp=(null)}
         * Q.4.7-output={sensor='S2', avgTemp=(null)}
         * Q.4.7-output={sensor='S3', avgTemp=(null)}
   * Statement: Q.4.8
      *
* At: 2001-01-01 08:00:25.000
   * Statement: Q.4.7
      * Insert
         * Q.4.7-output={sensor='S1', avgTemp=(null)}
         * Q.4.7-output={sensor='S2', avgTemp=(null)}
         * Q.4.7-output={sensor='S3', avgTemp=(null)}
   * Statement: Q.4.8
      *
```

![](img/EPL09.png)

`Q.4.8`, the snapshot, reports exactly the groups that have members: `S1` at 08:00:05, then
`S2`, then `S3` — and then, at 08:00:20 and 08:00:25, an empty body. Sensible, and quiet about
everything else.

`Q.4.7`, `all`, reports **every group it has ever seen**, and reports the emptied ones with
`avgTemp=(null)`. `S1` is still in the report at 08:00:25, twenty seconds after its last
reading left the window. Notice also that `S2` and `S3` are absent from the first report: a
group joins the report when it is first seen and never leaves.

**And now put this beside section 2, because the same word did two different things.** At
08:00:20, in one and the same block, `Q.4.5` — `all` over a plain `select` — said nothing,
while `Q.4.7` — `all` over an aggregation — reported three groups. Both are "everything since
the last report". The difference is what *persists* between reports: a plain `select` has only
the rows that arrived, and none did; an aggregation has its **groups**, and those do not go
away.

Which of the two you want depends entirely on who is listening.

> If the consumer is **remembering** what you told it — a dashboard, a table, anything with
> state — then silence is indistinguishable from *unchanged*, and `snapshot` will leave the
> last average for `S1` on the screen forever, for a sensor that stopped reporting twenty
> seconds ago. `all` is what tells it the group has emptied.
>
> The price is on the page too: at 08:00:25 `Q.4.7` is reporting three sensors, all null,
> none of which will ever report again, and it will go on doing so for as long as the query
> runs. The report grows with the number of distinct keys and never shrinks. Three sensors,
> fine. A fleet, think again.

This is not a theoretical worry. It is exactly the bug in the elevator controller's wait-time
dashboard in [the lecture on state and lifecycles](https://github.com/Streaming-Data-Analytics/Courseware/tree/main/Streaming%20Data%20Engineering/EPL/epl-elevator-controller),
and the fix there is this one word.

## 4. What "nothing left" looks like — the complete table

Part 1's table, now finished:

| statement | when the window or group is empty |
|---|---|
| `output first every` | **no entry at all** — it has no callback to fire |
| plain `select *` over any window, no `output` clause | **nothing at all** — not even a block |
| `output last` / `all` / `snapshot every` over a plain `select` | the statement, named, with an **empty body** |
| aggregation + `group by`, no `output` clause | the group, with a **null** aggregate |
| aggregation + `group by` + `output snapshot every` | the statement, named, with an **empty body** |
| aggregation + `group by` + `output all every` | the group with **null**, and every other group ever seen, for as long as the query runs |

Six behaviours. Every one of them was executed to write this table, and no two of them can be
guessed from the others.

---

# Part 3 — lecture 5: patterns, and the running example answered

Back to the trace of part 1, and to the half of the running example we have been avoiding:

> A fire is detected when, **at the same sensor**, a smoke event is **followed by** a
> temperature above 50 °C **within two minutes**.

Nothing in parts 1 and 2 can express *followed by*. A window tells you what is there; it does
not tell you what happened **in what order**. This is where EPL stops being a query language
over streams and becomes a language for **complex event processing**.

The operator is `->`, and it lives inside a
[`pattern`](http://esper.espertech.com/release-9.0.0/reference-esper/html_single/#event_patterns)
clause.

## 1. `->`, used naively

```
@name('Q.5.1')
select *
from pattern [
  s = SmokeSensorEvent(smoke=true)
  -> TemperatureSensorEvent(temperature > 50, sensor=s.sensor)
];
```

```
@name('Q.5.2')
select *
from pattern [
  every (
    s = SmokeSensorEvent(smoke=true)
    -> TemperatureSensorEvent(temperature > 50, sensor=s.sensor)
  )
];
```

Both at once, so the difference is one transcript:

```
* At: 2001-01-01 08:00:02.000
   * Statement: Q.5.1
      * Insert
         * stmt3_pat_0_0={s={SmokeSensorEvent={sensor='S1', smoke=true}}}
   * Statement: Q.5.2
      * Insert
         * stmt4_pat_0_0={s={SmokeSensorEvent={sensor='S1', smoke=true}}}
* At: 2001-01-01 08:00:03.000
   * Statement: Q.5.2
      * Insert
         * stmt4_pat_0_0={s={SmokeSensorEvent={sensor='S1', smoke=true}}}
* At: 2001-01-01 08:00:04.000
   * Statement: Q.5.2
      * Insert
         * stmt4_pat_0_0={s={SmokeSensorEvent={sensor='S1', smoke=true}}}
```

`Q.5.1` fires **once**, at 08:00:02, and then has no entry at all in the two blocks that
follow — not an empty body, no entry. `Q.5.2` fires **three times**.

`Q.5.1` is not broken. A pattern without `every` describes **one** occurrence: match it once
and you are done, forever. That is the language's default, and it is a deliberate one — it
*tames the torrent effect*, the tendency of a naive correlation over a fast stream to produce
more output than input. If you want to be flooded, you have to ask.

`every` is how you ask.

## 2. The payload, and why the projection is not cosmetic

Look at what those rows actually contain:

```
stmt4_pat_0_0={s={SmokeSensorEvent={sensor='S1', smoke=true}}}
```

Three problems, and none of them is about taste.

**The temperature is not there.** Only `s` was tagged; the temperature operand was written
without a name, so it takes part in the match and then vanishes. The query announces that a
fire was detected and discards the number that proves it.

**The three rows of `Q.5.2` are identical.** All three read exactly the same, because the one
field that differs between the three matches is the one that was not tagged. Only the
timestamps tell them apart — and a consumer downstream does not get to see the timestamps.

**And the event type is named after a position in the deployment.** `Q.5.1` emits rows of type
`stmt3_pat_0_0` and `Q.5.2` of type `stmt4_pat_0_0` — count the three `create schema`
declarations at the top of this file and you have found the 3 and the 4. Add a statement above
them, or take one away, and the type names change under you.

All three are fixed the same way, by naming what you want and projecting it, exactly as in
SQL:

```
@name('Q.5.3')
select s.sensor as sensor, t.temperature as temperature, s.smoke as smoke
from pattern [
  every (
    s = SmokeSensorEvent(smoke=true)
    -> t = TemperatureSensorEvent(temperature > 50, sensor=s.sensor)
  )
];
```

```
* At: 2001-01-01 08:00:02.000
   * Statement: Q.5.3
      * Insert
         * Q.5.3-output={sensor='S1', temperature=55.0, smoke=true}
* At: 2001-01-01 08:00:03.000
   * Statement: Q.5.3
      * Insert
         * Q.5.3-output={sensor='S1', temperature=56.0, smoke=true}
* At: 2001-01-01 08:00:04.000
   * Statement: Q.5.3
      * Insert
         * Q.5.3-output={sensor='S1', temperature=58.0, smoke=true}
```

Three matches, and now we can see them: **55, 56 and 58**.

## 3. The 57 that got away

![](img/EPL10.png)

The drawing is the shape of `every (○ → ★)`: *every first smoke followed by the first high
temperature*. The crossed-out symbols are the events that fall between the pairs and match
nothing — and now we know one of them by name.

The reading of **57 arrives at 08:00:03 and matches nothing at all.** Here is why. When the
match on 56 completes, a fresh instance of the pattern starts and begins looking for a smoke
event. The next one arrives later in that same instant — *after* 57 has already gone by. So
the instance that could have used 57 did not yet exist, and by the time it did, 57 was in the
past.

That is not a bug and not an accident of this trace. It is what `every ( A -> B )` means:
**non-overlapping pairs**. Whether that is what you want depends on the question, and it is
why the drawing ends in three unanswered variants — `every A -> B`, `every A -> every B`,
`A -> every B`. Working out which of them catches the 57, and what each one costs you, is
[the next module's](https://github.com/Streaming-Data-Analytics/Courseware/tree/main/Streaming%20Data%20Engineering/EPL/epl-every-and-guard-patterns)
whole business.

## 4. Making a stream out of the matches

A pattern that prints rows is a demo. To be part of a system it has to produce a **stream**
other queries can consume — which is what `FireEvent`, declared at the top of this file, is
for.

```
@name('Q.5.4')
insert into FireEvent
select s.sensor as sensor, s.smoke as smoke, t.temperature as temperature
from pattern [
  every (
    s = SmokeSensorEvent(smoke=true)
    -> t = TemperatureSensorEvent(temperature > 50, sensor=s.sensor)
  )
];
```

The `select` is `Q.5.3`'s; only the destination is new. And now the running example can
finally be asked, over a sliding window, exactly as stated:

```
@name('Q.5.5')
select count(*) as fires
from FireEvent#time(10 seconds);
```

```
* At: 2001-01-01 08:00:02.000
   * Statement: Q.5.4
      * Insert
         * FireEvent={sensor='S1', smoke=true, temperature=55.0}
   * Statement: Q.5.5
      * Insert
         * Q.5.5-output={fires=1}
* At: 2001-01-01 08:00:03.000
   * Statement: Q.5.4
      * Insert
         * FireEvent={sensor='S1', smoke=true, temperature=56.0}
   * Statement: Q.5.5
      * Insert
         * Q.5.5-output={fires=2}
* At: 2001-01-01 08:00:04.000
   * Statement: Q.5.4
      * Insert
         * FireEvent={sensor='S1', smoke=true, temperature=58.0}
   * Statement: Q.5.5
      * Insert
         * Q.5.5-output={fires=3}
* At: 2001-01-01 08:00:12.000
   * Statement: Q.5.5
      * Insert
         * Q.5.5-output={fires=2}
* At: 2001-01-01 08:00:13.000
   * Statement: Q.5.5
      * Insert
         * Q.5.5-output={fires=1}
* At: 2001-01-01 08:00:14.000
   * Statement: Q.5.5
      * Insert
         * Q.5.5-output={fires=0}
```

**Read the last three blocks.** The answer to *"how many fires in the last ten minutes"* is
1, 2, 3 — and then 2, 1, 0.

The rise comes from detections. **The decay comes from nothing happening at all**: at
08:00:12, :13 and :14 each fire reaches ten seconds of age and leaves the window, exactly ten
seconds after it was detected. No event causes those three rows. The clock does.

That is the whole idea of a sliding window in one transcript, and it is why the trace runs on
to 08:00:20 after the last reading. **The answer to a continuous question is not a number. It
is a time series, and it comes back to zero by itself.**

One more thing about that last row, and it connects straight back to part 2. `fires=0` is
reported **once**, at 08:00:14, and then `Q.5.5` says nothing for the rest of the trace: it has
no `output` clause, so it speaks only when its window changes, and once the last `FireEvent`
has left there is nothing more to remove. Here silence means *still zero*, and reading it that
way is correct.

Now recall `Q.4.8` in part 2, whose silence meant *the group emptied and I will not mention it
again* — the opposite. **The same silence, two opposite meanings, and nothing in the output
tells them apart.** Only knowing which clauses the statement carries does.

## 5. The guard — and an example in which it does nothing

One clause of the running example is still missing: *within two minutes*. Without it,
`Q.5.4` will happily pair a smoke event with a temperature that arrives an hour later.

The constraint is a **pattern guard**, and it wraps the operand it applies to:

```
@name('Q.5.6')
insert into FireEvent
select s.sensor as sensor, s.smoke as smoke, t.temperature as temperature
from pattern [
  every (
    s = SmokeSensorEvent(smoke=true)
    -> ( t = TemperatureSensorEvent(temperature > 50, sensor=s.sensor)
         where timer:within(2 seconds) )
  )
];
```

```
* At: 2001-01-01 08:00:02.000
   * Statement: Q.5.6
      * Insert
         * FireEvent={sensor='S1', smoke=true, temperature=55.0}
   * Statement: Q.5.5
      * Insert
         * Q.5.5-output={fires=1}
* At: 2001-01-01 08:00:03.000
   * Statement: Q.5.6
      * Insert
         * FireEvent={sensor='S1', smoke=true, temperature=56.0}
   * Statement: Q.5.5
      * Insert
         * Q.5.5-output={fires=2}
* At: 2001-01-01 08:00:04.000
   * Statement: Q.5.6
      * Insert
         * FireEvent={sensor='S1', smoke=true, temperature=58.0}
   * Statement: Q.5.5
      * Insert
         * Q.5.5-output={fires=3}
* At: 2001-01-01 08:00:12.000
   * Statement: Q.5.5
      * Insert
         * Q.5.5-output={fires=2}
* At: 2001-01-01 08:00:13.000
   * Statement: Q.5.5
      * Insert
         * Q.5.5-output={fires=1}
* At: 2001-01-01 08:00:14.000
   * Statement: Q.5.5
      * Insert
         * Q.5.5-output={fires=0}
```

Compare that with the transcript above it, and compare it carefully, because the two are more
alike than they look. **They differ in exactly three lines, and all three are the name of the
statement.** Every timestamp, every temperature, every value of `fires`: the same character
for character.

So there is nothing subtle to go looking for. **On this trace the guard changes nothing**,
because every smoke event is followed by its temperature within one second and a two-second
limit never bites. Ten seconds would not bite either — that was tried. A constraint that never
fires teaches you nothing about constraints.

So change the trace. Take the advance between the `T=56 / T=57 / S=true` block and `T=58`,
and make it three seconds instead of one:

```
t=t.plus(3 seconds)
```

Everything else stays as it is. Now:

```
* At: 2001-01-01 08:00:02.000
   * Statement: Q.5.6
      * Insert
         * FireEvent={sensor='S1', smoke=true, temperature=55.0}
   * Statement: Q.5.5
      * Insert
         * Q.5.5-output={fires=1}
* At: 2001-01-01 08:00:03.000
   * Statement: Q.5.6
      * Insert
         * FireEvent={sensor='S1', smoke=true, temperature=56.0}
   * Statement: Q.5.5
      * Insert
         * Q.5.5-output={fires=2}
* At: 2001-01-01 08:00:12.000
   * Statement: Q.5.5
      * Insert
         * Q.5.5-output={fires=1}
* At: 2001-01-01 08:00:13.000
   * Statement: Q.5.5
      * Insert
         * Q.5.5-output={fires=0}
```

**Two fires instead of three.** The smoke of 08:00:03 now waits three seconds for its
temperature; the guard, armed until 08:00:05, tears the pending match down first, and the 58
arrives to find nothing waiting for it. The count peaks at 2, and the decay finishes a second
earlier.

Run both. The pair is the only place in this module where the guard is visibly load-bearing,
and predicting the second transcript from the first is a better exercise than any question we
could ask you.

## 6. Where the brackets go

One last trap, and it costs a match.

```
@name('Q.5.7')
select s.sensor as sensor, t.temperature as temp
from pattern [
  every ( s = SmokeSensorEvent(smoke=true)
          -> t = TemperatureSensorEvent(temperature > 50, sensor=s.sensor)
          where timer:within(2 seconds) )
];
```

```
@name('Q.5.8')
select s.sensor as sensor, t.temperature as temp
from pattern [
  every ( ( s = SmokeSensorEvent(smoke=true)
            -> t = TemperatureSensorEvent(temperature > 50, sensor=s.sensor) )
          where timer:within(2 seconds) )
];
```

`Q.5.7` has no brackets at all; `Q.5.8` wraps the **whole sequence**. Deployed together:

```
* At: 2001-01-01 08:00:02.000
   * Statement: Q.5.7
      * Insert
         * Q.5.7-output={sensor='S1', temp=55.0}
* At: 2001-01-01 08:00:03.000
   * Statement: Q.5.7
      * Insert
         * Q.5.7-output={sensor='S1', temp=56.0}
   * Statement: Q.5.8
      * Insert
         * Q.5.8-output={sensor='S1', temp=56.0}
* At: 2001-01-01 08:00:04.000
   * Statement: Q.5.7
      * Insert
         * Q.5.7-output={sensor='S1', temp=58.0}
   * Statement: Q.5.8
      * Insert
         * Q.5.8-output={sensor='S1', temp=58.0}
```

`Q.5.7` matches three times — 55, 56, 58 — which is exactly `Q.5.6`'s behaviour. So the
brackets in `Q.5.6` were never doing anything: **`where timer:within` binds tighter than
`->`**, and without brackets it attaches to the operand on its left, not to the sequence.

`Q.5.8` matches **twice**, and it loses the **first** one, not the last. The guard on a whole
sequence starts counting when the **instance** starts, not when the smoke arrives. The first
instance begins when the query is deployed, at 08:00:00, so its two seconds are up at
08:00:02 — and the expiry is a scheduled callback, which runs *before* the events of its own
instant. The instance is torn down a moment before the 55 it was waiting for is delivered.

Two guards, two seconds each, on the same trace, and they disagree about which match to lose.
The rule that resolves it — *a callback runs before the events of its own instant* — is the
same one from `Q.3.3`, `Q.3.7` and `Q.4.1`. It is the single most useful thing to know about
this engine, and it has now earned its place four times.

## 7. The running example, finally

```
@name('Q.5.6')
insert into FireEvent
select s.sensor as sensor, s.smoke as smoke, t.temperature as temperature
from pattern [
  every (
    s = SmokeSensorEvent(smoke=true)
    -> ( t = TemperatureSensorEvent(temperature > 50, sensor=s.sensor)
         where timer:within(2 seconds) )
  )
];
```

```
@name('Q.5.5')
select count(*) as fires
from FireEvent#time(10 seconds);
```

Two statements. One detects, one counts. Everything else in this module was the road to them:
the filter that picked out temperatures above 50, the window that bounds *the last ten
minutes*, the aggregation that counts what is in it, the reporting policy that decides who
hears about it, and the pattern operator that turns *followed by* into something executable.

---

## Notes and observations

Seven things this module establishes about the engine that no query states and no
documentation page will make you believe until you have seen them.

* **A scheduled callback runs before the events of its own instant.** Seen four times: the
  first batch of `Q.3.3` excludes the reading arriving as it closes; `Q.3.7`'s eviction is
  dispatched before the arrival at the same millisecond; `Q.4.1` releases its event in a
  *second* block after the boundary report; and `Q.5.8` is torn down a moment before the
  match it was waiting for. If you learn one thing here, learn this.

* **Eviction wins the tie.** An event entering at *t* with an *n*-second window is gone at
  *t+n* exactly, and the callback at *t+n* does not see it.

* **The engine dispatches once per event, not once per instant.** Two readings at 08:00:03
  produce two blocks with the same timestamp. Identical timestamps are not duplicates.

* **A plain `select` carries only the insert stream.** This is why `Q.3.5` and `Q.3.6` are
  indistinguishable, and why `Q.3.3` says nothing about its empty batches. The removals are
  always happening; `irstream` is how you see them.

* **Time-driven windows cannot be starved; count-driven ones can.** `Q.3.9` keeps reporting
  on an empty stream because the clock keeps arriving. `Q.3.10` strands two real measurements
  forever in a batch that never fills. `Q.3.7` reports that it has emptied; `Q.3.8`, over the
  same data, never can.

* **A batch window speaks only when it has an insert or a removal to deliver.** `Q.3.9`'s
  null at 08:00:12 is the previous batch *leaving*, not the empty batch announcing itself —
  which is why the query then falls completely silent. Do not read silence as *unchanged*.

* **The count of nothing is zero; the average of nothing is null.** Same clause, same empty
  window, different answers, and both are right: zero is a true count, and there is no true
  average of nothing.

## Lab

### Q.3.12

Take `Q.3.9probe` and point it at `#time(4 seconds)` instead of `#time_batch(4 seconds)` —
that is, ask for the removals of `Q.3.5`.

**Predict first.** How many `Remove` rows, and at which instants? Then run it. The rows you
predicted are the ones that were there all along while `Q.3.5` was showing you six inserts and
nothing else.

### Q.3.13

A sensor fails at 08:00:04 and never reports again. You want a query that makes the failure
**visible** — something whose output changes because the readings stopped.

Of `Q.3.7`, `Q.3.8`, `Q.3.9` and `Q.3.10`, which ones can do it and which cannot? Answer from
the transcripts in this file before running anything, then check yourself. For each one that
cannot, say what a consumer downstream would believe instead.

### Q.4.9

Take the trace of part 2 and the four policies of `Q.4.1`–`Q.4.4`, and change the window from
ten seconds to **three**.

Predict what each policy emits, then run it. One of the four now reports something no reading
ever produced. Say which, and why that is the correct answer rather than a bug.

### Q.5.9

`Q.5.6` counts a fire when smoke is followed by heat. A colleague argues the detector should
also fire when the **heat comes first** and smoke follows within two seconds, and proposes
running a second copy of the pattern with the two operands swapped, inserting into the same
`FireEvent` stream.

Write it, run it against the trace, and count the fires. Then decide whether the number you
get is the number the building manager asked for. Bring your answer to the next lecture.

## And now, a different building

Everything above monitors something. The queries watch sensors, correlate them, count what
they find and report it to somebody who then decides what to do. That is what stream
processing is usually sold as, and it is what almost every tutorial stops at.

So here is a building with ten floors and two elevator cars, A and B. People press buttons in
the hallways; cars arrive and open their doors. Somewhere in that building, something has to
decide **which car answers which call** — not report on the decision, not raise an alarm about
it afterwards: *make* it, every time a button is pressed, in time to matter.

The question for the next few lectures, and it is not rhetorical:

> **Can the controller itself be written in EPL?**

Not a query that watches a controller. The controller: the thing that hears the button, looks
at where both cars are, works out which one should go, and says so.

Think about what it would need. Somewhere to keep the calls that are still waiting — and a way
to take one **out** when it is answered, which nothing in this module can do. Some notion of a
call having a **lifetime**, so that one nobody serves eventually becomes a complaint rather
than a row that sits there forever. And a way to compare two candidates and pick one, which
sounds like SQL and turns out to be.

Two of those three you have not met yet. You have met more of the third than you think.

The answer is in
[the lecture on state, lifecycles and a complete controller](https://github.com/Streaming-Data-Analytics/Courseware/tree/main/Streaming%20Data%20Engineering/EPL/epl-elevator-controller),
and it is shorter than you expect.

## Acknowledgements

The fire alarm case study, the two sensor streams and the running example are
[Emanuele Della Valle](https://emanueledellavalle.org/)'s, written for earlier editions of
this course. This file is a rewrite of that material, not a new module: the example, the
trace and the hand-drawings in `img/` are his and are kept.

This rewrite was made by [Emanuele Della Valle](https://emanueledellavalle.org/) and
[Claude](https://claude.com/product/overview), together, and it is worth saying how, because
the division of labour is the reason you can trust the numbers.

The previous version of this module stated its expected outputs **only as photographs of
hand-drawings**, and for most of its queries stated none at all. Emanuele executed every
statement in this file on the EPL online tool; Claude designed the runs, restructured the
material into the three parts, and wrote the text. Every transcript above was extracted from
a recorded run by script rather than retyped, and every query in this file was generated from
the same source as `firealarm.epl`, so the two cannot drift apart.

The drawings were then checked against the runs, one by one. They turned out to be correct —
including the comparison of the landmark and sliding averages, drawn in 2021 and never
executed until now. Two claims in the older text did not survive: a query with a malformed
window, and a section that presented a constraint using an example in which the constraint
never fires. Both are corrected here, and the second is now said out loud rather than hidden.

Claude predicted results ahead of several runs and was wrong more than once; where a
prediction and the tool disagreed, the tool won and the text was rewritten. One conclusion in
the working notes had to be withdrawn entirely after a later run contradicted it. None of that
is visible in the text above, which is the point of having run everything.

Claude's work on this course is sponsored by
[Quantia Consulting](https://www.quantiaconsulting.com/).
