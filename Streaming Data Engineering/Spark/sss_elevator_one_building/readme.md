# Kafka & Spark Structured Streaming — one building

Politecnico di Milano — Streaming Data Analytics — lecture 9

## Introduction

One building, three lift units, five minutes of a morning, and four queries. It
is the Structured Streaming block of lecture 9 with something to run under it:
a stream read from Kafka, given a schema, filtered, counted, put into windows of
event time, and finally joined against a table that does not move.

The building is the one of lectures 6 and 7 — the same doors, the same
directions — and the units are the `EU-001`, `EU-002`, `EU-003` of the Kafka
module of lecture 8. Nothing about the domain is new here. What is new is the
language it is written in, and the comparison is the lesson.

| # | the fact | the slide it belongs to |
|---|---|---|
| 1 | a stream read from Kafka is a **DataFrame**, and `isStreaming` is the only thing that says otherwise | *Creating streaming DataFrames* |
| 2 | Spark does not guess what is inside `value`: a schema is supplied, and every DataFrame downstream of a streaming source is itself streaming | *Creating streaming DataFrames (cont.)* |
| 3 | a streaming query does not return rows, it **starts**, and writes to a sink | *Spark is lazy … write results!* |
| 4 | an unbounded aggregation can only be written in `complete` mode, because no group is ever finished | *Basic operations — aggregation* |
| 5 | a window is on **event time**, so a replay gives the same answer; and in `update` mode the same window is reported again whenever it changes | *Window operations on event time* |
| 6 | a stream joins a static table with ordinary join syntax: the static side is re-read for every batch | *Stream to table join operations* |
| 7 | a stream can be joined **to itself**, and that is how a `->` is written when the language has no `->` — at the cost of saying the direction of time out loud, and of one pairing the pattern would never have made | *«Followed by» operator as a stream to stream join* |

## What this module deliberately does not contain

* **Late arrivals and watermarks in depth.** `Spark/sss_late-arrivals` is the
  module for that, with a simulator built to make events late on purpose.
* **The fleet.** `Spark/sss_elevator-fleet` is lecture 10: 150,000 units, three
  regions, the straggler, and the sizing arithmetic. Running it a day early
  spoils the question lecture 10 opens with.

## Resources

* [Structured Streaming Programming Guide](https://spark.apache.org/docs/3.5.0/structured-streaming-programming-guide.html)
* [Structured Streaming + Kafka integration](https://spark.apache.org/docs/3.5.0/structured-streaming-kafka-integration.html)

## 1. Set up

### make sure

Docker is running, and ports `8888` and `29092` are free. If you have another
module of this course up, bring it down first: the stacks use the same ports and
the same container name for Kafka.

### start up the infrastructure

```
docker-compose up -d
```

Two services, not five: a single-node Kafka in KRaft mode — no ZooKeeper — and a
`pyspark-notebook` image with the Kafka python client installed before Jupyter
starts. Both images are multi-architecture, so this runs natively on Apple
Silicon as well as on Intel.

### you know you succeeded if

<http://localhost:8888/lab?token=sda> opens, and `work/` holds the two
notebooks.

## 2. Run it

**Two notebooks, open side by side, run interleaved — and both of them run
downwards only.** `1_building_simulator.ipynb` produces,
`2_building_monitoring.ipynb` consumes, and no cell further up is ever run a
second time: a reading that has changed is taken again lower down, next to the
question that changed it.

1. the **simulator**, from the top down to and including the cell that creates
   the producer and defines `send(...)` — the last one before *1) The morning*.
   It prints `37 events` and the five per-minute counts on the way. Nothing has
   been sent yet;
2. the **monitoring** notebook, from the top to the `SELECT` of `Q.9.1`. It
   prints an empty table, which is correct;
3. the **simulator**, *1) The morning, one minute at a time*;
4. the **monitoring** notebook, down to and including the two queries of `Q.9.5`
   and their two `SELECT`s. Those come back empty too, and that is also correct;
5. the **simulator**, *2) One floor, four openings*, and then the cell that moves
   the clock on;
6. the **monitoring** notebook, the rest of it, straight down;
7. *Clean up* in the monitoring notebook, which stops the queries, then *Clean
   up* in the simulator, which deletes the topic.

**Open the two notebooks side by side, with `1_building_simulator.ipynb` on the
LEFT and `2_building_monitoring.ipynb` on the RIGHT**, and keep them that way:
every hand-off between them is a heading inside the notebooks — `❯❯` for *go to
the one on the right*, `❮❮` for *come back to the one on the left* — and those
arrows mean nothing if the windows are the other way round. Each heading also
says what to run once you are there and where to pick up on your way back, so
the seven steps above are a map rather than something to keep in your head.

When a table comes back empty where it should not be, the batch has not landed:
run **that** cell again, not the ones before it.

Both notebooks carry those seven steps at the top, so neither of them has to be
read from the middle.

Sending the whole morning before starting Spark also works — `startingOffsets`
is `earliest`, so nothing is lost — and it is the quick way to check that the
stack is up. It is the wrong way to teach: every event is already on the topic,
Spark consumes them in a single batch, each window is reported exactly once, and
the behaviour of `update` mode that `Q.9.3` is built to show never happens.

| section | what you will do | stop and predict |
|---|---|---|
| *The topic* | create `building-events` with three partitions, one per unit, keyed by `unitId` | three units and three partitions — one each? |
| *1) The stream, before it means anything* | read from Kafka and print the schema | how many of the columns carry your data? |
| *2) Giving the bytes a schema* | `from_json` with the building's schema | is the result still a streaming DataFrame? |
| *Q.9.1* | keep the `DoorOpened` rows and five columns | how many of the 37 events come through? |
| *Q.9.2* | count per unit, over the whole stream | what has to be the output mode, and why? |
| *Q.9.3* | the same count, per minute of event time | you wrote down 3, 6, 15, 9, 4 — which of them come back, and keyed by what? |
| *Q.9.4* | join the doors against the two banks | the low bank has two units and the high bank one. Is the low bank busier in every minute? |
| *Q.9.5* | the bunching rule of lecture 7, as a self-join, written twice | three numbers, written down before running: the rule as it reads, the rule with `b.ts > a.ts`, and what `every a -> b` would have given on the same four openings |
| *8) Nothing above has finished* | read `Q.9.1` to `Q.9.4` again, at the bottom | the earlier cells printed an empty table and the counts 15, 10, 12. What do they hold now, and why was no cell edited? |

### the trace is designed, not random

Thirty-seven door events over five minutes: 3, 6, 15, 9, 4. Two units serve the
lower floors and one the upper floors, and the upper one is **asleep in the
first minute** and busiest two minutes later, when the people who came through
the lobby reach it. Every answer in the monitoring notebook can be checked
against those numbers by hand, which is the point of designing a trace rather
than generating one.

Then six more events, for `Q.9.5` alone. Four openings at one unit, one floor,
one direction, cars alternating at `+0`, `+8`, `+14` and `+18` seconds: close
enough together that they look like two bunchings and are not. And two ordinary
openings two minutes later at another floor, whose only job is to carry the event
time forward — in `append` mode a joined row is held back until the watermark
says no partner can still arrive, so without them the join's table stays empty
and looks broken.

Those six are door events like any other, so `Q.9.1` to `Q.9.4` grow with them:
a minute 7 and a minute 9 appear, and the running totals go from 37 to 43.

### an empty table is a question, not a failure

The memory sink fills when a batch lands. An empty `SELECT` means the simulator
has not sent that minute yet, or the batch has not arrived: wait a second and
run the cell again. A query that has really failed raises, and
`q.exception()` says so.

### the one mistake worth warning about

In `update` mode a window is reported **again** every time its count changes, so
the sink holds the history of a group's answers and not just the answer.
Summing the query's table directly counts those intermediate updates as if they
were events. The notebook builds a `_final` view with `MAX(count)` per window
and sums that instead — and the difference between the two numbers is worth
putting on the board.

## 3. Stop

```
docker-compose down
```

Stop the queries in the monitoring notebook and delete the topic in the
simulator first, in that order. Deleting a topic under a running query produces
an exception that teaches nothing.

## Acknowledgements

The stack, the schema and the discipline of a designed trace are those of
`Spark/sss_elevator-fleet`, which this module is the small version of.

The elevator domain, the controller this module sits above and the `bunching` rule are
[Emanuele Della Valle](https://emanueledellavalle.org/)'s, from lectures 6 and 7 of this
course. The building, its designed trace and the five queries were built for this module by
Emanuele and [Claude](https://claude.com/product/overview) together: Claude designed the
trace and verified the queries, Emanuele ran the infrastructure and captured every output
committed here.

`Q.9.5` is where that division of labour pays. It reaches lecture 7's bunching rule with a
stream-stream self-join, and the three numbers the notebook reports — eight, four and
**three** — were a prediction until Emanuele ran the same four openings through the EPL
online tool on 11-ott-2026 and the pattern emitted exactly three rows. The missing pair is
the first opening against the last, and it is missing for a reason that has nothing to do
with time. Nothing in this module is asserted from a run that was not recorded.

Claude's work on this course is sponsored by
[Quantia Consulting](https://www.quantiaconsulting.com/).
