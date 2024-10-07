# EPL - Join semantics

## Introduction

This running example summarizes some concepts described in the article [Crossing the Streams – Joins in Apache Kafka](https://www.confluent.io/blog/crossing-streams-joins-apache-kafka/) and shows how to implement them in EPL. The original article shows the different types of joins available with Kafka Streams through an example of online advertisements. This running example instead shows the joins supported in Esper, with slight changes to the examples used in the article.

## Resources

* [espertech](https://www.espertech.com)
* [EPL documentation](http://esper.espertech.com/release-9.0.0/reference-esper/html/index.html)
* [online environment to try EPL](http://esper-epl-tryout.appspot.com/epltryout/mainform.html)
* 
## Implementation in EPL

### Creating the events

The example to demonstrate the differences in the joins is based on the online advertising domain. There is a EPL event type that describes *view* events of particular ads and another one that contains the *click* events based on those ads. Views and clicks share an ID that serves as the key in both event types.

#### View event type

```
create schema View (id string,n int);
```
#### Click event type
```
	create schema Click (id string,n int);

```
### Data generation
In the examples, `t.plus` event times provide a convenient way to simulate the time passing between the events.

We will look at the following 7 scenarios:

* a click event arrives 1 sec after the view
* a click event arrives 10 sec after the view
* a view event arrives 1 sec after the click
* there is a view event but no click
* there is a click event but no view
* there are two consecutive view events and one click event 1 sec after the first view
* there is a view event followed by two click events shortly after each other

#### Generation of stream events

As we want to show showcase some specific scenarios, we insert events as seen in the image below.

![](https://cdn.confluent.io/wp-content/uploads/input-streams-1-768x300.jpg)

```
View={id='A'};
t = t.plus(1 seconds);
View={id='B'};
Click={id='A'};
t = t.plus(1 seconds);
Click={id='C'};
t = t.plus(1 seconds);
View={id='C'};
t = t.plus(1 seconds);
View={id='D'};
t = t.plus(1 seconds);
Click={id='E'};
t = t.plus(1 seconds);
View={id='F',n=1};
View={id='F',n=2};
t = t.plus(1 seconds);
Click={id='F'};
t = t.plus(1 seconds);
View={id='G'};
t = t.plus(1 seconds);
Click={id='G',n=1};
Click={id='G',n=2};
t = t.plus(2 seconds);
Click={id='B'};
t = t.plus(20 seconds);
```

### stream to stream joins

Two or more event streams can be part of the from-clause, and thus, both (all) streams determine the resulting events. Joins require that at least a window is specified for each stream. In the following examples, we use windows of 9 seconds.


#### Inner join
```
@name('inner-window')
select *
from View#time(9 sec) as v
     inner join
     Click#time(9 sec) as c
     on v.id = c.id;
```
##### Result

![](https://cdn.confluent.io/wp-content/uploads/inner_stream-stream_join-768x475.jpg)

```
 At: 2001-01-01 08:00:01.000

    Insert
        inner-window-output={v={View={id='A', n=(null)}}, c={Click={id='A', n=(null)}}}

At: 2001-01-01 08:00:03.000

    Insert
        inner-window-output={v={View={id='C', n=(null)}}, c={Click={id='C', n=(null)}}}

At: 2001-01-01 08:00:07.000

    Insert
        inner-window-output={v={View={id='F', n=1}}, c={Click={id='F', n=(null)}}}
        inner-window-output={v={View={id='F', n=2}}, c={Click={id='F', n=(null)}}}

At: 2001-01-01 08:00:09.000

    Insert
        inner-window-output={v={View={id='G', n=(null)}}, c={Click={id='G', n=1}}}

At: 2001-01-01 08:00:09.000

    Insert
        inner-window-output={v={View={id='G', n=(null)}}, c={Click={id='G', n=2}}}

```

Records A and C appear as expected, as the key appears in both streams within 9 seconds, even though they come in different order. Records B produce no result: although both records have matching keys, they do not appear within the time window. Records D and E don’t join because neither has a matching key contained in both streams. Records F and G appear two times as the keys appear twice in the view stream for F and in the clickstream for scenario G.

#### Left join

The left join starts a computation each time an event arrives for either the left or right input stream. However, processing for both is slightly different. For input records of the left stream, an output event is generated every time an event arrives. If an event with the same key has previously arrived in the right stream, it is joined with the one in the primary stream. Otherwise, it is set to null. On the other hand, each time an event arrives in the right stream, it is only joined if an event with the same key previously arrived in the primary stream.

```
select *
from View#time(9 sec) as v 
        left outer join
        Click#time(9 sec) as c
        on v.id = c.id;
```

##### Result

![](https://cdn.confluent.io/wp-content/uploads/left-stream-stream-join-768x459.jpg)

```
 At: 2001-01-01 08:00:00.000

    Insert
        left-outer-window-output={v={View={id='A', n=(null)}}, c=(null)}

At: 2001-01-01 08:00:01.000

    Insert
        left-outer-window-output={v={View={id='B', n=(null)}}, c=(null)}

At: 2001-01-01 08:00:01.000

    Insert
        left-outer-window-output={v={View={id='A', n=(null)}}, c={Click={id='A', n=(null)}}}

At: 2001-01-01 08:00:03.000

    Insert
        left-outer-window-output={v={View={id='C', n=(null)}}, c={Click={id='C', n=(null)}}}

At: 2001-01-01 08:00:04.000

    Insert
        left-outer-window-output={v={View={id='D', n=(null)}}, c=(null)}

At: 2001-01-01 08:00:06.000

    Insert
        left-outer-window-output={v={View={id='F', n=1}}, c=(null)}

At: 2001-01-01 08:00:06.000

    Insert
        left-outer-window-output={v={View={id='F', n=2}}, c=(null)}

At: 2001-01-01 08:00:07.000

    Insert
        left-outer-window-output={v={View={id='F', n=1}}, c={Click={id='F', n=(null)}}}
        left-outer-window-output={v={View={id='F', n=2}}, c={Click={id='F', n=(null)}}}

At: 2001-01-01 08:00:08.000

    Insert
        left-outer-window-output={v={View={id='G', n=(null)}}, c=(null)}

At: 2001-01-01 08:00:09.000

    Insert
        left-outer-window-output={v={View={id='G', n=(null)}}, c={Click={id='G', n=1}}}

At: 2001-01-01 08:00:09.000

    Insert
        left-outer-window-output={v={View={id='G', n=(null)}}, c={Click={id='G', n=2}}}

```

The result contains all records from the inner join. Additionally, it contains a result record for B and D and thus contains all records from the primary (left) “view” stream. Also, note the results for “view” records A, F.1/F.2, and G with null (indicated as “dot”) on the right-hand side. Those records would not be included in a SQL join. As Esper provides stream join semantics and processes each record when it arrives, the right-hand window does not contain a corresponding key for primary “view” input events A, F1./F.2, and G in the secondary “click” input stream in our example and thus correctly includes those events in the result.

#### Outer join

An outer join will emit an output each time an event is processed in either stream. The join method will be applied to both elements if the window state already contains an element with the same key in the other stream. If not, it will only apply to the incoming element.

```
select *
from View#time(9 sec) as v 
        full outer join
        Click#time(9 sec) as c
        on v.id = c.id;
```

##### Result

![](https://cdn.confluent.io/wp-content/uploads/outer-stream-stream-join-768x464.jpg)

```
 At: 2001-01-01 08:00:00.000

    Insert
        full-outer-window-output={v={View={id='A', n=(null)}}, c=(null)}

At: 2001-01-01 08:00:01.000

    Insert
        full-outer-window-output={v={View={id='B', n=(null)}}, c=(null)}

At: 2001-01-01 08:00:01.000

    Insert
        full-outer-window-output={v={View={id='A', n=(null)}}, c={Click={id='A', n=(null)}}}

At: 2001-01-01 08:00:02.000

    Insert
        full-outer-window-output={v=(null), c={Click={id='C', n=(null)}}}

At: 2001-01-01 08:00:03.000

    Insert
        full-outer-window-output={v={View={id='C', n=(null)}}, c={Click={id='C', n=(null)}}}

At: 2001-01-01 08:00:04.000

    Insert
        full-outer-window-output={v={View={id='D', n=(null)}}, c=(null)}

At: 2001-01-01 08:00:05.000

    Insert
        full-outer-window-output={v=(null), c={Click={id='E', n=(null)}}}

At: 2001-01-01 08:00:06.000

    Insert
        full-outer-window-output={v={View={id='F', n=1}}, c=(null)}

At: 2001-01-01 08:00:06.000

    Insert
        full-outer-window-output={v={View={id='F', n=2}}, c=(null)}

At: 2001-01-01 08:00:07.000

    Insert
        full-outer-window-output={v={View={id='F', n=1}}, c={Click={id='F', n=(null)}}}
        full-outer-window-output={v={View={id='F', n=2}}, c={Click={id='F', n=(null)}}}

At: 2001-01-01 08:00:08.000

    Insert
        full-outer-window-output={v={View={id='G', n=(null)}}, c=(null)}

At: 2001-01-01 08:00:09.000

    Insert
        full-outer-window-output={v={View={id='G', n=(null)}}, c={Click={id='G', n=1}}}

At: 2001-01-01 08:00:09.000

    Insert
        full-outer-window-output={v={View={id='G', n=(null)}}, c={Click={id='G', n=2}}}

At: 2001-01-01 08:00:11.000

    Insert
        full-outer-window-output={v=(null), c={Click={id='B', n=(null)}}}

```

For record A, an event is emitted once the view is processed. There is no click yet. When the click arrives, the joined event on view and click is emitted. For record B, we also get two output events. However, since the events do not occur within the window, neither of these events contains both view and click (i.e., both are independent outer-join results). “View” record D appears in the output without a click, and the equivalent (but “reverse”) output is emitted for “click” record E. Records F produce 4 output events as there are two views that are emitted immediately and once again when they are joined against a click. In contrast, records G produce only 3 events as both clicks can be immediately joined against a view that arrived earlier.

### Discussion

**In SQL**, joins are performed on tables, which are static data structures. The semantics of SQL joins are based on a relational data model and queries that work with complete data sets. 

* Inner Join: Returns only rows with matches on both tables.
* Left/Right Outer Join: Returns all rows from one table (left or right), with matches found in the other table, and NULL for rows with no matches.
* Full Outer Join: Returns all rows when a match occurs in one of the tables.

These joins operate on “static” data and usually do not consider the time dimension (unless specific time conditions are applied, but this is not intrinsic to the joins' semantics).

**Joins among streams** have profoundly different semantics because they are designed to run on real-time data streams, essentially unbounded record sequences. Events are joined only if they arrive within a specified time window. This temporal aspect is central and intrinsic to the join semantics of streams.

* Streaming Inner Joins: Returns combined records only when a match exists within the time window.
* Left Join: Returns all records in the left stream with matches in the right stream (where there are no matches, they are filled with null).
* Outer Join: Similar to SQL joins, includes all records from both streams, with null for fields with no matches.

The concept of time is crucial. Joins depend on the time synchronization of events in streams, which introduces a significant difference from traditional SQL joins.

### "Table" to "Table" and Stream to "Table" joins

EPL offers three ways to build tables out of unbounded streams:

* The `keep all` window is a data window that retains all arriving events. However, care should be taken to remove events from the keep-all data window in a timely manner.
* The `unique` window is a window that includes only **the most recent** among **events** having the same value(s) for the result of the specified expression or list of expressions.
* The `create Table` statement with the corresponding `insert into` aggregation query since they are holders for aggregation state
  
`unique` windows implement the ktable abstraction of Kafka Stream described in the original article. In Kafka-agnostic terminology, they are named **materialized view**s. In the following, we call them simply **Table**s even if this term collides with EPL Tables (for more information, see [2.14.2. Tables](http://esper.espertech.com/release-9.0.0/reference-esper/html/processingmodel.html#processingmodel_infra_table) in EPL documentation).


#### Inner Table-Table join 

```
@name('inner-unique')
select *
from View#unique(id) as v
     inner join
     Click#unique(id) as c
     on v.id = c.id;
```

##### Result

![](https://cdn.confluent.io/wp-content/uploads/Inner-Table-Table-Join-768x727.jpg)

```
 At: 2001-01-01 08:00:01.000

    Insert
        inner-unique-output={v={View={id='A', n=(null)}}, c={Click={id='A', n=(null)}}}

At: 2001-01-01 08:00:03.000

    Insert
        inner-unique-output={v={View={id='C', n=(null)}}, c={Click={id='C', n=(null)}}}

At: 2001-01-01 08:00:07.000

    Insert
        inner-unique-output={v={View={id='F', n=2}}, c={Click={id='F', n=(null)}}}

At: 2001-01-01 08:00:09.000

    Insert
        inner-unique-output={v={View={id='G', n=(null)}}, c={Click={id='G', n=1}}}

At: 2001-01-01 08:00:09.000

    Insert
        inner-unique-output={v={View={id='G', n=(null)}}, c={Click={id='G', n=2}}}

At: 2001-01-01 08:00:11.000

    Insert
        inner-unique-output={v={View={id='B', n=(null)}}, c={Click={id='B', n=(null)}}}

```

All the inner join pairs are emitted as expected. Since we’re no longer windowed, even record B/B is in the result. Note that the result contains only one result for F but two for G. Because click F appears after views F.1 and F.2, F.2 did replace F.1 before F triggers the join computation. For G, the view arrives before both clicks, and thus, G.1 and G.2 join with G. This scenario demonstrates the update behavior of a join between two materialized views. After G.1 arrives, the join result is G.1/G. Then the click event G.2 updates the click table and triggers a recomputation of the join result to G.2/G.1

#### Left Table-Table join

```
@name('left-outer-unique')
select *
from View#unique(id) as v
     left outer join
     Click#unique(id) as c
     on v.id = c.id;
```

##### Result

![](https://cdn.confluent.io/wp-content/uploads/Left-Table-Table-Join-768x727.jpg)

```
 At: 2001-01-01 08:00:00.000

    Insert
        left-outer-window-output={v={View={id='A', n=(null)}}, c=(null)}

At: 2001-01-01 08:00:01.000

    Insert
        left-outer-window-output={v={View={id='B', n=(null)}}, c=(null)}

At: 2001-01-01 08:00:01.000

    Insert
        left-outer-window-output={v={View={id='A', n=(null)}}, c={Click={id='A', n=(null)}}}

At: 2001-01-01 08:00:03.000

    Insert
        left-outer-window-output={v={View={id='C', n=(null)}}, c={Click={id='C', n=(null)}}}

At: 2001-01-01 08:00:04.000

    Insert
        left-outer-window-output={v={View={id='D', n=(null)}}, c=(null)}

At: 2001-01-01 08:00:06.000

    Insert
        left-outer-window-output={v={View={id='F', n=1}}, c=(null)}

At: 2001-01-01 08:00:06.000

    Insert
        left-outer-window-output={v={View={id='F', n=2}}, c=(null)}

At: 2001-01-01 08:00:07.000

    Insert
        left-outer-window-output={v={View={id='F', n=1}}, c={Click={id='F', n=(null)}}}
        left-outer-window-output={v={View={id='F', n=2}}, c={Click={id='F', n=(null)}}}

At: 2001-01-01 08:00:08.000

    Insert
        left-outer-window-output={v={View={id='G', n=(null)}}, c=(null)}

At: 2001-01-01 08:00:09.000

    Insert
        left-outer-window-output={v={View={id='G', n=(null)}}, c={Click={id='G', n=1}}}

At: 2001-01-01 08:00:09.000

    Insert
        left-outer-window-output={v={View={id='G', n=(null)}}, c={Click={id='G', n=2}}}

```

The result is the same as with the inner join with the addition of proper data for (left) view events A, B, D, F.1, F.2, and G that do a left join with empty right-hand side when they are processed first. Thus, view D is preserved and only click E is not contained as there is no corresponding view.

#### Outer Table-Table join
```
@name('full-outer-unique')
select *
from View#unique(id) as v
     full outer join
     Click#unique(id) as c
     on v.id = c.id;
```

##### Result

![](https://cdn.confluent.io/wp-content/uploads/Outer-Table-Table-Join-768x727.jpg)

```
 At: 2001-01-01 08:00:00.000

    Insert
        full-outer-unique-output={v={View={id='A', n=(null)}}, c=(null)}

At: 2001-01-01 08:00:01.000

    Insert
        full-outer-unique-output={v={View={id='B', n=(null)}}, c=(null)}

At: 2001-01-01 08:00:01.000

    Insert
        full-outer-unique-output={v={View={id='A', n=(null)}}, c={Click={id='A', n=(null)}}}

At: 2001-01-01 08:00:02.000

    Insert
        full-outer-unique-output={v=(null), c={Click={id='C', n=(null)}}}

At: 2001-01-01 08:00:03.000

    Insert
        full-outer-unique-output={v={View={id='C', n=(null)}}, c={Click={id='C', n=(null)}}}

At: 2001-01-01 08:00:04.000

    Insert
        full-outer-unique-output={v={View={id='D', n=(null)}}, c=(null)}

At: 2001-01-01 08:00:05.000

    Insert
        full-outer-unique-output={v=(null), c={Click={id='E', n=(null)}}}

At: 2001-01-01 08:00:06.000

    Insert
        full-outer-unique-output={v={View={id='F', n=1}}, c=(null)}

At: 2001-01-01 08:00:06.000

    Insert
        full-outer-unique-output={v={View={id='F', n=2}}, c=(null)}

At: 2001-01-01 08:00:07.000

    Insert
        full-outer-unique-output={v={View={id='F', n=2}}, c={Click={id='F', n=(null)}}}

At: 2001-01-01 08:00:08.000

    Insert
        full-outer-unique-output={v={View={id='G', n=(null)}}, c=(null)}

At: 2001-01-01 08:00:09.000

    Insert
        full-outer-unique-output={v={View={id='G', n=(null)}}, c={Click={id='G', n=1}}}

At: 2001-01-01 08:00:09.000

    Insert
        full-outer-unique-output={v={View={id='G', n=(null)}}, c={Click={id='G', n=2}}}

At: 2001-01-01 08:00:11.000

    Insert
        full-outer-unique-output={v={View={id='B', n=(null)}}, c={Click={id='B', n=(null)}}}

```

The result is the same as with the left join plus the “right join” result records for clicks C and D with an empty left-hand side.

This join is pretty close to SQL semantics and, thus, easy to understand. The difference to plain SQL is that the result automatically updates when new data arrives on the streams. Thus, the result can be described as an ever-updating view of the table join. 

### stream to table joins

The `unidirectional` keyword can be used in the from clause to identify streams that provide the events to execute the join. If the keyword is present for a stream, all other streams in the from clause become passive streams. When events arrive or leave a data window of a passive stream, then the join does not generate join results. 

Therefore, the `unidirectional` keyword makes the stream-table join asymmetric: only the (left) stream input triggers a join computation. Because the join is not-windowed, the (left) input stream is stateless, and thus, join lookups from table records to stream records are not possible.

This semantics is usually used to enrich a data stream with auxiliary information from a table. However, for the example in use, we'll use the *"views"* as the left stream and *"clicks"* as the right table input.

#### Inner join
```
@name('inner-stream-table')
select *
from View as v
     unidirectional inner join
     Click#unique(id) as c
     on v.id = c.id;
```
##### Result

![](https://cdn.confluent.io/wp-content/uploads/Inner-Stream-Table-Join-768x561.jpg)

```
At: 2001-01-01 08:00:03.000

    Insert
        inner-stream-table-output={v={View={id='C', n=(null)}}, c={Click={id='C', n=(null)}}}
```

The result is just a single record, as click C is the only click that arrives before the corresponding view event.

#### Left join

It’s the same as an inner stream-table join but preserves all (left) stream input records in case there is no matching join record in the (right) table input.

```
@name('left-stream-table')
select *
from View as v
     unidirectional left outer join
     Click#unique(id) as c
     on v.id = c.id;
```

##### Result

![](https://cdn.confluent.io/wp-content/uploads/Left-Stream-Table-Join-768x561.jpg)

```
 At: 2001-01-01 08:00:00.000

    Insert
        left-stream-table-output={v={View={id='A', n=(null)}}, c=(null)}

At: 2001-01-01 08:00:01.000

    Insert
        left-stream-table-output={v={View={id='B', n=(null)}}, c=(null)}

At: 2001-01-01 08:00:03.000

    Insert
        left-stream-table-output={v={View={id='C', n=(null)}}, c={Click={id='C', n=(null)}}}

At: 2001-01-01 08:00:04.000

    Insert
        left-stream-table-output={v={View={id='D', n=(null)}}, c=(null)}

At: 2001-01-01 08:00:06.000

    Insert
        left-stream-table-output={v={View={id='F', n=1}}, c=(null)}

At: 2001-01-01 08:00:06.000

    Insert
        left-stream-table-output={v={View={id='F', n=2}}, c=(null)}

At: 2001-01-01 08:00:08.000

    Insert
        left-stream-table-output={v={View={id='G', n=(null)}}, c=(null)}

```

As expected, we get the inner C/C join result as well as one join result for each (left) stream record.

## Acknowledgements
Images and examples were taken from the article "Crossing the Streams – Joins in Apache Kafka" available here: https://www.confluent.io/blog/crossing-streams-joins-apache-kafka/
