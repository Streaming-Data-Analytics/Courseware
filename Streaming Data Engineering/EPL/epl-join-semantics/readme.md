# EPL — Join semantics on elevator dispatching

## Introduction

A passenger presses a hall button. Some time later, a car opens its doors at that floor,
going that way. These are two independent streams that share a key, and nothing guarantees
which of the two arrives first — a car can be already on its way when the button is pressed.

Almost every question a building manager asks is a join over those two streams. *Which calls
were served?* *Which were not?* *How long did people wait?* *Did two cars answer the same
call?* The queries below are all the same join, written four ways. What changes is not the
join condition — it never changes — but what kind of state each side is held in, and that
turns out to decide the answer.

This is the theory that a working dispatching controller instantiates. When you come to
build one, its bidding statement will be query Q.6.4 of this module, and the state it
dispatches from will be the window introduced in Q.6.5. Nothing in it will be new.

## Resources

* [espertech](https://www.espertech.com)
* [EPL documentation](http://esper.espertech.com/release-9.0.0/reference-esper/html/index.html)
* [online environment to try EPL](http://esper-epl-tryout.appspot.com/epltryout/mainform.html)

## The trace used by this module

The **adversarial** trace. It is built so that each of the pathologies of the domain happens
exactly once and on its own key: a call served late, a car that opens before anyone presses,
a call nobody serves, a car that opens where nobody called, a double press, and two cars
answering one call. It is not a plausible minute in the life of a building, and it is not
meant to be. The regular trace, used for windows and aggregations, and the full trace, used
by the complete controller, are different files.

Every output in this module comes from one run of the tool against this trace. Nothing here
is inferred from anything else here.

## The domain

The building has floors 0 to 9 and two cars, A and B. Floor 0 has an UP button only, floor 9
a DOWN button only.

### Event types

```
create schema HallCall(floor int, dir string);
create schema DoorOpened(car string, floor int, servedDir string);
```

`HallCall` is what a hall button emits: a floor and the direction the passenger wants to go.
It carries **no car and no identifier**, because a hall button has neither.

`DoorOpened` is what a car emits when it opens its doors: which car, at which floor, and
which direction it is serving. `servedDir` is deliberately not called `dir` — a car's
direction is where it is heading, whereas `servedDir` is which of the two calls at that floor
it has just answered.

So the join condition throughout this module is

```
h.floor = d.floor and h.dir = d.servedDir
```

and the key of a call is the pair `(floor, dir)`.

### The trace

```
HallCall={floor=2, dir='UP'}
t=t.plus(1 seconds)
HallCall={floor=4, dir='UP'}
DoorOpened={car='A', floor=2, servedDir='UP'}
t=t.plus(1 seconds)
DoorOpened={car='B', floor=6, servedDir='DOWN'}
t=t.plus(1 seconds)
HallCall={floor=6, dir='DOWN'}
t=t.plus(1 seconds)
HallCall={floor=7, dir='UP'}
t=t.plus(1 seconds)
DoorOpened={car='A', floor=1, servedDir='DOWN'}
t=t.plus(1 seconds)
HallCall={floor=3, dir='UP'}
HallCall={floor=3, dir='UP'}
t=t.plus(1 seconds)
DoorOpened={car='B', floor=3, servedDir='UP'}
t=t.plus(1 seconds)
HallCall={floor=5, dir='DOWN'}
t=t.plus(1 seconds)
DoorOpened={car='A', floor=5, servedDir='DOWN'}
DoorOpened={car='B', floor=5, servedDir='DOWN'}
t=t.plus(2 seconds)
DoorOpened={car='B', floor=4, servedDir='UP'}
t=t.plus(20 seconds)
```

Assumption, stated because it is visible in the numbers: the trace moves a car about one
floor per second. That is fast for a ten-storey building. Nothing in any query depends on
it — the movements are there only so that the trace is not physically absurd.

### The seven scenarios

Each takes its own key, so no two ever interfere.

| Key | Call | Service | What it is |
|---|---|---|---|
| (2, UP) | 08:00:00 | 08:00:01, car A | served after 1 second |
| (4, UP) | 08:00:01 | 08:00:11, car B | served after 10 seconds |
| (6, DOWN) | 08:00:03 | 08:00:02, car B | **the doors open before the call** — a car was already going there |
| (7, UP) | 08:00:04 | never | the call nobody serves |
| (1, DOWN) | never | 08:00:05, car A | a car opens where nobody called — the empty pass |
| (3, UP) | 08:00:06, **twice** | 08:00:07, car B | the double button press |
| (5, DOWN) | 08:00:08 | 08:00:09, cars A **and** B | two cars answer one call — bunching |

Before running anything, it is worth predicting how many rows each query below produces. The
answers are all small numbers, and most people get at least one of them wrong.

## 1. Stream to stream joins

Two or more streams can appear in the from-clause, and every one of them determines the
result. A join requires **a data window on each stream**: without one there is no state to
join against. Here both windows are nine seconds.

#### Q.6.1

Which hall calls were served within nine seconds.

```
@name('Q.6.1')
select *
from HallCall#time(9 sec) as h
     inner join
     DoorOpened#time(9 sec) as d
     on h.floor = d.floor and h.dir = d.servedDir;
```

##### Result

```
* At: 2001-01-01 08:00:01.000
   * Insert
      * Q.6.1-output={h={HallCall={floor=2, dir='UP'}}, d={DoorOpened={car='A', floor=2, servedDir='UP'}}}
* At: 2001-01-01 08:00:03.000
   * Insert
      * Q.6.1-output={h={HallCall={floor=6, dir='DOWN'}}, d={DoorOpened={car='B', floor=6, servedDir='DOWN'}}}
* At: 2001-01-01 08:00:07.000
   * Insert
      * Q.6.1-output={h={HallCall={floor=3, dir='UP'}}, d={DoorOpened={car='B', floor=3, servedDir='UP'}}}
      * Q.6.1-output={h={HallCall={floor=3, dir='UP'}}, d={DoorOpened={car='B', floor=3, servedDir='UP'}}}
* At: 2001-01-01 08:00:09.000
   * Insert
      * Q.6.1-output={h={HallCall={floor=5, dir='DOWN'}}, d={DoorOpened={car='A', floor=5, servedDir='DOWN'}}}
* At: 2001-01-01 08:00:09.000
   * Insert
      * Q.6.1-output={h={HallCall={floor=5, dir='DOWN'}}, d={DoorOpened={car='B', floor=5, servedDir='DOWN'}}}
```

Six rows. The call at (2, UP) matches, and so does (6, DOWN) even though its service arrived
*before* it — the window holds both sides, and neither the join nor the window cares which
one came first. The call at (4, UP) never appears: it was served ten seconds later, and by
then the call had left the window. That single absence is the whole point of the nine
seconds.

Two rows deserve attention. At 08:00:07 the same row is emitted **twice**, and the two copies
are identical down to the last character. That is the double press: two `HallCall` events sat
in the window, one `DoorOpened` matched both. There is nothing in the payload to tell the two
presses apart because there is nothing in the world to tell them apart either — a hall button
has no identity, and pressing it twice produces two events that are equal in every respect.
At 08:00:09 there are again two rows, but this time they differ by car: one call, two cars,
which is bunching.

#### Q.6.2

Every hall call, with its service on the right when there is one.

```
@name('Q.6.2')
select *
from HallCall#time(9 sec) as h
     left outer join
     DoorOpened#time(9 sec) as d
     on h.floor = d.floor and h.dir = d.servedDir;
```

##### Result

```
* At: 2001-01-01 08:00:00.000
   * Insert
      * Q.6.2-output={h={HallCall={floor=2, dir='UP'}}, d=(null)}
* At: 2001-01-01 08:00:01.000
   * Insert
      * Q.6.2-output={h={HallCall={floor=4, dir='UP'}}, d=(null)}
* At: 2001-01-01 08:00:01.000
   * Insert
      * Q.6.2-output={h={HallCall={floor=2, dir='UP'}}, d={DoorOpened={car='A', floor=2, servedDir='UP'}}}
* At: 2001-01-01 08:00:03.000
   * Insert
      * Q.6.2-output={h={HallCall={floor=6, dir='DOWN'}}, d={DoorOpened={car='B', floor=6, servedDir='DOWN'}}}
* At: 2001-01-01 08:00:04.000
   * Insert
      * Q.6.2-output={h={HallCall={floor=7, dir='UP'}}, d=(null)}
* At: 2001-01-01 08:00:06.000
   * Insert
      * Q.6.2-output={h={HallCall={floor=3, dir='UP'}}, d=(null)}
* At: 2001-01-01 08:00:06.000
   * Insert
      * Q.6.2-output={h={HallCall={floor=3, dir='UP'}}, d=(null)}
* At: 2001-01-01 08:00:07.000
   * Insert
      * Q.6.2-output={h={HallCall={floor=3, dir='UP'}}, d={DoorOpened={car='B', floor=3, servedDir='UP'}}}
      * Q.6.2-output={h={HallCall={floor=3, dir='UP'}}, d={DoorOpened={car='B', floor=3, servedDir='UP'}}}
* At: 2001-01-01 08:00:08.000
   * Insert
      * Q.6.2-output={h={HallCall={floor=5, dir='DOWN'}}, d=(null)}
* At: 2001-01-01 08:00:09.000
   * Insert
      * Q.6.2-output={h={HallCall={floor=5, dir='DOWN'}}, d={DoorOpened={car='A', floor=5, servedDir='DOWN'}}}
* At: 2001-01-01 08:00:09.000
   * Insert
      * Q.6.2-output={h={HallCall={floor=5, dir='DOWN'}}, d={DoorOpened={car='B', floor=5, servedDir='DOWN'}}}
```

Twelve rows, and the six of the inner join are among them. The other six have `d=(null)`.

This is where the streaming semantics part company with SQL. A left outer join over streams
starts a computation **every time an event arrives on either side**. When a `HallCall`
arrives it emits immediately, joined if a matching `DoorOpened` is already in the window and
with `null` otherwise. So the call at (2, UP) appears twice: once at 08:00:00 with `null`,
because nothing had served it yet, and again at 08:00:01 when car A opened its doors. In SQL
the first of those two rows would not exist.

Note what does **not** happen. The call at (6, DOWN) appears once and already joined, because
the doors had opened a second earlier and the `DoorOpened` was waiting in the window. And the
empty pass at (1, DOWN) appears nowhere at all: a left outer join is driven by its left
stream, and no call was ever pressed there.

This has a consequence worth stating before the lab asks about it: **`d=(null)` does not mean
"not served"**. Six rows carry a null, and only one of them, (7, UP), is a call that was
really never answered. The others are calls seen a moment too early.

## 2. Table to table joins

EPL offers three ways to build a table out of an unbounded stream:

* The `keepall` window retains every arriving event. Care is needed to remove events from it
  in good time.
* The `unique` window keeps only **the most recent** among the events that share a value for
  the given expression or list of expressions.
* The `create table` statement, with a corresponding `insert into` aggregation query, since
  tables are holders of aggregation state.

A `unique` window is a **materialized view**: a table kept continuously up to date by a
stream, holding exactly one row per key. That is the term used from here on, rather than
*table*, which in EPL already means something else.

A materialized view has no time window. State does not expire — it is only overwritten.

#### Q.6.3

The same inner join as Q.6.1, over two materialized views instead of two time windows.

```
@name('Q.6.3')
select *
from HallCall#unique(floor, dir) as h
     inner join
     DoorOpened#unique(floor, servedDir) as d
     on h.floor = d.floor and h.dir = d.servedDir;
```

##### Result

```
* At: 2001-01-01 08:00:01.000
   * Insert
      * Q.6.3-output={h={HallCall={floor=2, dir='UP'}}, d={DoorOpened={car='A', floor=2, servedDir='UP'}}}
* At: 2001-01-01 08:00:03.000
   * Insert
      * Q.6.3-output={h={HallCall={floor=6, dir='DOWN'}}, d={DoorOpened={car='B', floor=6, servedDir='DOWN'}}}
* At: 2001-01-01 08:00:07.000
   * Insert
      * Q.6.3-output={h={HallCall={floor=3, dir='UP'}}, d={DoorOpened={car='B', floor=3, servedDir='UP'}}}
* At: 2001-01-01 08:00:09.000
   * Insert
      * Q.6.3-output={h={HallCall={floor=5, dir='DOWN'}}, d={DoorOpened={car='A', floor=5, servedDir='DOWN'}}}
* At: 2001-01-01 08:00:09.000
   * Insert
      * Q.6.3-output={h={HallCall={floor=5, dir='DOWN'}}, d={DoorOpened={car='B', floor=5, servedDir='DOWN'}}}
* At: 2001-01-01 08:00:11.000
   * Insert
      * Q.6.3-output={h={HallCall={floor=4, dir='UP'}}, d={DoorOpened={car='B', floor=4, servedDir='UP'}}}
```

Six rows again — the same number as Q.6.1, but not the same rows. Two differences, and each
is a lesson.

**(4, UP) now appears**, at 08:00:11. There is no time window, so the call was still in the
view ten seconds after it was pressed. Same join, same data, one line of difference in the
from-clause, and a call that Q.6.1 called unserved is here served.

**The double press now yields one row instead of two.** At 08:00:06 the second press did not
join the first in the view; it *replaced* it, because `#unique(floor, dir)` keeps only the
most recent event per key. When the doors opened at 08:00:07 there was one call to match. You
cannot see which of the two presses survived, and that is not a limitation of the output —
the two events are identical, so the question has no answer. Whether the *first* press or the
*last* press should survive is exactly the design decision a controller has to make, and the
reason it will not use `#unique` for this.

The bunching case works the other way round. At 08:00:09 the first `DoorOpened` joins and
emits with car A; the second overwrites it in the view and triggers a recomputation, which
emits with car B. Here the replacement **is** visible, because the two events differ by car.

One last thing about this section, worth noticing now and returning to much later. Turning a
stream into a keyed view cost **two words in a from-clause**. Not every engine gives you
that. Spark Structured Streaming has no such construct: its own *unbounded table* is the
input abstraction, not a view keyed on anything, and *one row per key* has to be built by
hand — as a stateful aggregation, or as a custom stateful operator that keeps the state
itself. It works, and it is a great deal more code. We will come back to this when we leave
one building for a fleet of them.

## 3. Stream to table joins

The `unidirectional` keyword marks the stream that provides the events driving the join. All
the other streams in the from-clause become **passive**: when an event arrives at or leaves
one of their data windows, no join result is produced.

This makes the join asymmetric. Only the left input triggers a computation, and because that
side carries no window, it is stateless — so a lookup in the other direction, from a table
row back to a stream event, is not possible.

The usual reason to write this is enrichment: take each arriving event and decorate it with
whatever the table knows. It is also the shape a controller's bidding statement takes, where
each new call is joined against the current position of every car.

#### Q.6.4

For each call as it arrives, had this floor and direction already been served?

```
@name('Q.6.4')
select *
from HallCall as h
     unidirectional inner join
     DoorOpened#unique(floor, servedDir) as d
     on h.floor = d.floor and h.dir = d.servedDir;
```

##### Result

```
* At: 2001-01-01 08:00:03.000
   * Insert
      * Q.6.4-output={h={HallCall={floor=6, dir='DOWN'}}, d={DoorOpened={car='B', floor=6, servedDir='DOWN'}}}
```

One row, out of seven calls. Only (6, DOWN) had a `DoorOpened` waiting in the view at the
moment its call arrived — it is the one scenario where the doors opened first.

The other six produce nothing, and it is worth being precise about why, because there are two
different reasons. The calls at (2, UP), (4, UP), (3, UP) and (5, DOWN) *were* eventually
served, but their service arrived later, and a passive stream cannot trigger anything. The
calls at (7, UP) — and the door at (1, DOWN) — never had a counterpart at all. A
unidirectional join cannot distinguish those two situations, because it only ever looks once.

## 4. Named windows

Every window so far has been written inline, inside a from-clause. Such a window is **scoped
to its statement**. It has no name, so nothing else can address it: no other statement can
read it, write to it, or remove a row from it, and it ceases to exist when its statement
does.

A named window is the opposite. It is declared once, it has a name, and it is **shared
state**. It can be fed by several `insert into` statements at once, read by several more that
never mention the stream the rows came from, and — this is what a controller is built on —
have rows taken out of it by yet another. Only the first two are shown in this module; taking
rows out is the next lecture's business.

Both halves of that are shown by running something, not by assertion; the experiment is at
the end of this section.

#### Q.6.5

The declaration. A named window is created from an event type, with the data window that
governs it.

```
@name('Q.6.5')
create window PendingCall#unique(floor, dir) as HallCall;
```

##### Result

```
* At: 2001-01-01 08:00:00.000
   * Insert
      * PendingCall={floor=2, dir='UP'}
* At: 2001-01-01 08:00:01.000
   * Insert
      * PendingCall={floor=4, dir='UP'}
* At: 2001-01-01 08:00:03.000
   * Insert
      * PendingCall={floor=6, dir='DOWN'}
* At: 2001-01-01 08:00:04.000
   * Insert
      * PendingCall={floor=7, dir='UP'}
* At: 2001-01-01 08:00:06.000
   * Insert
      * PendingCall={floor=3, dir='UP'}
* At: 2001-01-01 08:00:06.000
   * Insert
      * PendingCall={floor=3, dir='UP'}
   * Remove
      * PendingCall={floor=3, dir='UP'}
* At: 2001-01-01 08:00:08.000
   * Insert
      * PendingCall={floor=5, dir='DOWN'}
```

The first thing to notice is that **there is a result at all**. `create window` is not a
declaration that sits quietly to one side: it is a statement, and it emits. Seven inserts,
one per call, and — at 08:00:06 — one *remove*.

That remove is the double press, and it is the eviction of `#unique` made visible. The second
press entered the window and the first left it, in the same breath. Nothing of the sort is
observable when the window is written inline, because an inline window has no name, no
identity, and no output of its own.

#### Q.6.6

The feed. A named window is empty until something writes to it.

```
@name('Q.6.6')
insert into PendingCall select * from HallCall;
```

##### Result

```
* At: 2001-01-01 08:00:00.000
   * Insert
      * PendingCall={floor=2, dir='UP'}
* At: 2001-01-01 08:00:01.000
   * Insert
      * PendingCall={floor=4, dir='UP'}
* At: 2001-01-01 08:00:03.000
   * Insert
      * PendingCall={floor=6, dir='DOWN'}
* At: 2001-01-01 08:00:04.000
   * Insert
      * PendingCall={floor=7, dir='UP'}
* At: 2001-01-01 08:00:06.000
   * Insert
      * PendingCall={floor=3, dir='UP'}
* At: 2001-01-01 08:00:06.000
   * Insert
      * PendingCall={floor=3, dir='UP'}
* At: 2001-01-01 08:00:08.000
   * Insert
      * PendingCall={floor=5, dir='DOWN'}
```

Seven inserts, no removes — and this is the pair worth staring at. At 08:00:06 the feed
reports an insert, while the window reports an insert **and** a remove. The two statements
disagree about what happened, and both are right: `insert into` always emits, because it
knows nothing about the window it writes to and nothing about uniqueness. It sends a row; what
the window does with it is the window's business.

Comparing Q.6.5 and Q.6.6 at 08:00:06 is the clearest demonstration of deduplication
available, and it costs one timestamp.

#### Q.6.7

A third statement, reading the window by name. Note that it never mentions `HallCall`.

```
@name('Q.6.7')
select floor, dir from PendingCall;
```

##### Result

```
* At: 2001-01-01 08:00:00.000
   * Insert
      * Q.6.7-output={floor=2, dir='UP'}
* At: 2001-01-01 08:00:01.000
   * Insert
      * Q.6.7-output={floor=4, dir='UP'}
* At: 2001-01-01 08:00:03.000
   * Insert
      * Q.6.7-output={floor=6, dir='DOWN'}
* At: 2001-01-01 08:00:04.000
   * Insert
      * Q.6.7-output={floor=7, dir='UP'}
* At: 2001-01-01 08:00:06.000
   * Insert
      * Q.6.7-output={floor=3, dir='UP'}
* At: 2001-01-01 08:00:06.000
   * Insert
      * Q.6.7-output={floor=3, dir='UP'}
* At: 2001-01-01 08:00:08.000
   * Insert
      * Q.6.7-output={floor=5, dir='DOWN'}
```

Seven rows. The window is genuinely shared: this statement was written without any knowledge
of where the rows come from, and it sees all of them.

It sees the insert at 08:00:06 but **not** the remove that Q.6.5 reported at the same instant.
A plain `select` delivers only the insert stream. Asking for removals as well requires
`irstream`, which is where the next lecture starts.

#### The experiment

Neither half of the claim that opened this section should be taken on trust, and one half
cannot be taken on trust at all. Both were run against this same trace.

**Is an inline window really the statement's own?** Two statements, the same stream, the same
key, two different kinds of window:

```
@name('Q.6.V1')
select floor, dir from HallCall#firstunique(floor, dir);

@name('Q.6.V2')
select floor, dir from HallCall#unique(floor, dir);
```

`#firstunique` keeps the **first** event for each key and refuses every later one.
`#unique` keeps the **last**, so each new event replaces its predecessor. On the double press
the two are obliged to disagree, and they do. Here is the first press, with the output
filtered to these two statements:

```
* At: 2001-01-01 08:00:06.000
   * Statement: Q.6.V1
      * Insert
         * Q.6.V1-output={floor=3, dir='UP'}
   * Statement: Q.6.V2
      * Insert
         * Q.6.V2-output={floor=3, dir='UP'}
```

And the second press, the next block at the very same millisecond. `Q.6.V1` is not in it:

```
* At: 2001-01-01 08:00:06.000
   * Statement: Q.6.V2
      * Insert
         * Q.6.V2-output={floor=3, dir='UP'}
```

One shared window on `HallCall` could not be in both states at the same instant. These are
two window objects, one per statement.

One caveat, and it is the more interesting half. This shows that two windows which *differ*
are separate. It does **not** show that two *identical* inline windows are separate — and
nothing can. Two identical windows over one stream always hold identical rows, so no output
could ever distinguish one object from two. The question falls outside what the language lets
you observe, which is why the paragraph above says *scoped to its statement* rather than
*a private copy of the state*. It is a small instance of something this course keeps running
into: in EPL, what is not observable is not part of the semantics.

**Is a named window really shared?** One container, two writers that know nothing of each
other, and a reader that never mentions `HallCall`:

```
@name('Q.6.V3')
create window AllCalls#keepall as HallCall;

@name('Q.6.V4')
insert into AllCalls select * from HallCall(dir='UP');

@name('Q.6.V5')
insert into AllCalls select * from HallCall(dir='DOWN');

@name('Q.6.V6')
select count(*) as n from AllCalls;
```

The reader counts to seven — five calls from the UP feed and two from the DOWN feed — and the
two arrive interleaved. Two consecutive seconds make the point:

```
* At: 2001-01-01 08:00:03.000
   * Statement: Q.6.V5
      * Insert
         * AllCalls={floor=6, dir='DOWN'}
   * Statement: Q.6.V6
      * Insert
         * Q.6.V6-output={n=3}
* At: 2001-01-01 08:00:04.000
   * Statement: Q.6.V4
      * Insert
         * AllCalls={floor=7, dir='UP'}
   * Statement: Q.6.V6
      * Insert
         * Q.6.V6-output={n=4}
```

At 08:00:03 the DOWN feed writes and the counter goes to three; at 08:00:04 the UP feed
writes and it goes to four. Neither writer knows the other exists. The window is the only
thing they share, and it is enough.

## Notes and observations

* **The join condition never changed.** Four queries, four different answers, one condition.
  What varied was the state each side was held in: a nine-second window, a materialized view,
  or nothing at all. In a stream engine, choosing the state *is* choosing the semantics.

* **Two identical events are two events.** The double press produces two rows in Q.6.1 and one
  in Q.6.3, and no query can tell you which press survived. Deduplication is not something the
  engine does for you; it is something you ask for, by choosing a window.

* **The tool opens a new `At:` block per event delivered, not per timestamp.** 08:00:01,
  08:00:06 and 08:00:09 each appear twice in the raw output. Two events at the same
  millisecond are still two events, evaluated one after the other, and the second sees the
  effect of the first — which is exactly why bunching emits car A and then car B rather than
  both at once.

* **Nothing here reports the empty pass.** The car that opened at (1, DOWN) with no call
  behind it appears in none of the four queries. Neither does the surplus door at (4, UP) at
  08:00:11, nor the early one at (6, DOWN) at 08:00:02. Each is an event on the right-hand
  stream that had no live counterpart on the left when it arrived. Which join would report
  them, and what it would report, is the first lab — run it rather than reasoning about it.

* **`insert into` always emits.** Q.6.6 against Q.6.5 at 08:00:06. Worth remembering, because
  the same pair of statements comes back to prove the same point about a controller's own
  state.

## Lab

### Q.6.8

Write the **full outer** join of the two streams, over nine-second windows on both sides, and
run it against the trace.

Predict first, then run. How many rows does it produce, and at which timestamps? Some of
them appear in no query of this module: say which, and what each one is in the building. If
your prediction and the tool disagree, the tool is right — work out why.

### Q.6.9

The building manager asks for **the calls that were never served**.

Write it as a left outer join and run it. Then read your own output carefully and decide
whether it answers the question. If it does not, say precisely what it answers instead, and
what you would need — that EPL has not yet given you — to answer the question that was asked.

Bring the result to the next lecture. It is where we start.

## Acknowledgements

This module owes its shape to **"Crossing the Streams — Joins in Apache Kafka"** by Florian
Troßbach, written in May 2017 on codecentric and republished in September 2017 on Confluent's
blog. That is where the seven scenarios come from, and the intervals between them, reproduced
here beat for beat. The domain is different, and the schemas, the queries, the trace and every
result in this file are new. The article is very much worth reading on its own terms.

* https://www.codecentric.de/wissens-hub/blog/crossing-streams-joins-apache-kafka
* https://www.confluent.io/blog/crossing-streams-joins-apache-kafka/
