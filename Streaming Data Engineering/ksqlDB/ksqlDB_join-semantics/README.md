# ksqlDB - Join semantics

## Introduction

This notebook summarizes some of the concepts described in the article [Crossing the Streams – Joins in Apache Kafka](https://www.confluent.io/blog/crossing-streams-joins-apache-kafka/). The latter shows the different types of joins that are available with Kafka Streams through an example on online advertisements. The notebook instead shows the joins supported in KsqlDB, with slight changes to the examples used in the article.

Kafka supports three kinds of join:
| Type         | Description                                                                                                                                        |
|:------------:|:---------------------------------------------------------------------------------------------------------------------------------------------------|
| Inner        | Emits an output when both input sources have records with the same key.                                                                            |
| Left         | Emits an output for each record in the left or primary input source. If the other source does not have a value for a given key, it is set to null. |
| Outer        | Emits an output for each record in either input source. If only one source contains a key, the other is null.                                      |

The following table shows which operations are permitted between KStreams and Ktables:
|Primary Type | Secondary Type | Inner Join | Left Join | Outer Join|
|:-----------:|:--------------:|:----------:|:---------:|:---------:|
| KStream     | KStream        | Supported  | Supported | Supported |
| KTable      | KTable         | Supported  | Supported | Supported |
| KStream     | KTable         | Supported  | Supported | N/A       |

## Set up

### start up the infrastructure

Bring up the entire stack by running:

```
docker-compose up -d
```

### Open ksqlDB cli

```
docker exec -it ksqldb-cli ksql http://ksqldb-server:8088
```

### Configure it for this demo

run the following commands that allows to rerun the queries always from the beginning of the data streams. This is **not to use in production**! It is for debugging/educational purpose only.

```
SET 'auto.offset.reset' = 'earliest';
```



## Implementation in Ksql

### Creating the streams
The example to demonstrate the differences in the joins is based on the online advertising domain. There is a Kafka topic that contains *view* events of particular ads and another one that contains the *click* events based on those ads. Views and clicks share an ID that serves as the key in both topics.
#### Views stream
```
CREATE STREAM AdViews_STREAM (id VARCHAR, ts VARCHAR)
  WITH (
  kafka_topic='AdView_topic', 
  value_format='json', 
  partitions=1,
  timestamp='ts',
  timestamp_format='yyyy-MM-dd''T''HH:mm:ssZ');
```
#### Clicks stream
```
CREATE STREAM AdClicks_STREAM (id VARCHAR, ts VARCHAR)
  WITH (
  kafka_topic='AdClicks_topic', 
  value_format='json', 
  partitions=1,
  timestamp='ts',
  timestamp_format='yyyy-MM-dd''T''HH:mm:ssZ');
```
### Data generation
In the examples, custom set event times provide a convenient way to simulate the timing within the streams.
We will look at the following 7 scenarios:
>* a click event arrives 1 sec after the view
>* a click event arrives 10 sec after the view
>* a view event arrives 1 sec after the click
>* there is a view event but no click
>* there is a click event but no view
>* there are two consecutive view events and one click event 1 sec after the first view
>* there is a view event followed by two click events shortly after each other
#### Generation of stream events
As we want to show showcase some specific scenarios, it's better to insert events manually (as seen in the image below).

![](https://cdn.confluent.io/wp-content/uploads/input-streams-1-768x300.jpg)
```
INSERT INTO AdViews_STREAM (id, ts) VALUES ('A', '2021-10-23T06:00:00+0200');
INSERT INTO AdViews_STREAM (id, ts) VALUES ('B', '2021-10-23T06:00:01+0200');
INSERT INTO AdClicks_STREAM (id, ts) VALUES ('A', '2021-10-23T06:00:01+0200');
INSERT INTO AdClicks_STREAM (id, ts) VALUES ('C', '2021-10-23T06:00:02+0200');
INSERT INTO AdViews_STREAM (id, ts) VALUES ('C', '2021-10-23T06:00:03+0200');
INSERT INTO AdViews_STREAM (id, ts) VALUES ('D', '2021-10-23T06:00:04+0200');
INSERT INTO AdClicks_STREAM (id, ts) VALUES ('E', '2021-10-23T06:00:05+0200');
INSERT INTO AdViews_STREAM (id, ts) VALUES ('F', '2021-10-23T06:00:06+0200');
INSERT INTO AdViews_STREAM (id, ts) VALUES ('F', '2021-10-23T06:00:06+0200');
INSERT INTO AdClicks_STREAM (id, ts) VALUES ('F', '2021-10-23T06:00:07+0200');
INSERT INTO AdViews_STREAM (id, ts) VALUES ('G', '2021-10-23T06:00:08+0200');
INSERT INTO AdClicks_STREAM (id, ts) VALUES ('G', '2021-10-23T06:00:09+0200');
INSERT INTO AdClicks_STREAM (id, ts) VALUES ('G', '2021-10-23T06:00:09+0200');
INSERT INTO AdClicks_STREAM (id, ts) VALUES ('B', '2021-10-23T06:00:11+0200');
```
### Kstream to Kstream joins
KStream is stateless, so we need some internal state where we can save some results, windows are used to do that. In the following examples, we use windows of 9 seconds.
#### Inner join
```
SELECT *
FROM AdViews_STREAM V
  JOIN AdClicks_STREAM C WITHIN 9 SECONDS
  ON V.id = C.id
EMIT CHANGES;
```
##### Result
![](https://cdn.confluent.io/wp-content/uploads/inner_stream-stream_join-768x475.jpg)
```
+------------------------+------------------------+------------------------+------------------------+
|V_ID                    |V_TS                    |C_ID                    |C_TS                    |
+------------------------+------------------------+------------------------+------------------------+
|A                       |2021-10-23T06:00:00+0200|A                       |2021-10-23T06:00:01+0200|
|B                       |2021-10-23T06:00:01+0200|B                       |2021-10-23T06:00:11+0200|
|C                       |2021-10-23T06:00:03+0200|C                       |2021-10-23T06:00:02+0200|
|F                       |2021-10-23T06:00:06+0200|F                       |2021-10-23T06:00:07+0200|
|F                       |2021-10-23T06:00:06+0200|F                       |2021-10-23T06:00:07+0200|
|G                       |2021-10-23T06:00:08+0200|G                       |2021-10-23T06:00:09+0200|
|G                       |2021-10-23T06:00:08+0200|G                       |2021-10-23T06:00:09+0200|
```
Records A and C appear as expected as the key appears in both streams within 9 seconds, even though they come in different order. Records B produce no result: even though both records have matching keys, they do not appear within the time window. Records D and E don’t join because neither has a matching key contained in both streams. Records F and G appear two times as the keys appear twice in the view stream for F and in the clickstream for scenario G.
#### Left join
The left join starts a computation each time an event arrives for either the left or right input stream. However, processing for both is slightly different. For input records of the left stream, an output event is generated every time an event arrives. If an event with the same key has previously arrived in the right stream, it is joined with the one in the primary stream. Otherwise it is set to null. On the other hand, each time an event arrives in the right stream, it is only joined if an event with the same key arrived in the primary stream previously.
```
SELECT *
FROM AdViews_STREAM V
  LEFT JOIN AdClicks_STREAM C WITHIN 9 SECONDS
  ON V.id = C.id
EMIT CHANGES;
```
##### Result
![](https://cdn.confluent.io/wp-content/uploads/left-stream-stream-join-768x459.jpg)
```
+------------------------+------------------------+------------------------+------------------------+
|V_ID                    |V_TS                    |C_ID                    |C_TS                    |
+------------------------+------------------------+------------------------+------------------------+
|A                       |2021-10-23T06:00:00+0200|null                    |null                    |
|A                       |2021-10-23T06:00:00+0200|A                       |2021-10-23T06:00:01+0200|
|B                       |2021-10-23T06:00:01+0200|null                    |null                    |
|C                       |2021-10-23T06:00:03+0200|C                       |2021-10-23T06:00:02+0200|
|D                       |2021-10-23T06:00:04+0200|null                    |null                    |
|F                       |2021-10-23T06:00:06+0200|null                    |null                    |
|F                       |2021-10-23T06:00:06+0200|null                    |null                    |
|F                       |2021-10-23T06:00:06+0200|F                       |2021-10-23T06:00:07+0200|
|F                       |2021-10-23T06:00:06+0200|F                       |2021-10-23T06:00:07+0200|
|G                       |2021-10-23T06:00:08+0200|null                    |null                    |
|G                       |2021-10-23T06:00:08+0200|G                       |2021-10-23T06:00:09+0200|
|G                       |2021-10-23T06:00:08+0200|G                       |2021-10-23T06:00:09+0200|
```
The result contains all records from the inner join. Additionally, it contains a result record for B and D and thus contains all records from the primary (left) “view” stream. Also note the results for “view” records A, F.1/F.2, and G with null (indicated as “dot”) on the right-hand side. Those records would not be included in a SQL join. As Kafka provides stream join semantics and processes each record when it arrives, the right-hand window does not contain a corresponding keys for primary “view” input events A, F1./F.2, and G in the secondary “click” input stream in our example and thus correctly includes those events in the result.
#### Outer join
An outer join will emit an output each time an event is processed in either stream. If the window state already contains an element with the same key in the other stream, it will apply the join method to both elements. If not, it will only apply the incoming element.
```
SELECT V.id AS ID_VIEW, V.ts AS TS_VIEW, C.id AS ID_CLICK, C.ts AS TS_CLICK
FROM AdViews_STREAM V
  FULL OUTER JOIN AdClicks_STREAM C WITHIN 9 SECONDS
  ON V.id = C.id
EMIT CHANGES;
```
##### Result
![](https://cdn.confluent.io/wp-content/uploads/outer-stream-stream-join-768x464.jpg)
```
+--------------------------+--------------------------+--------------------------+--------------------------+
|ID_VIEW                   |TS_VIEW                   |ID_CLICK                  |TS_CLICK                  |
+--------------------------+--------------------------+--------------------------+--------------------------+
|A                         |2021-10-23T06:00:00+0200  |null                      |null                      |
|A                         |2021-10-23T06:00:00+0200  |A                         |2021-10-23T06:00:01+0200  |
|B                         |2021-10-23T06:00:01+0200  |null                      |null                      |
|null                      |null                      |C                         |2021-10-23T06:00:02+0200  |
|C                         |2021-10-23T06:00:03+0200  |C                         |2021-10-23T06:00:02+0200  |
|D                         |2021-10-23T06:00:04+0200  |null                      |null                      |
|null                      |null                      |E                         |2021-10-23T06:00:05+0200  |
|F                         |2021-10-23T06:00:06+0200  |null                      |null                      |
|F                         |2021-10-23T06:00:06+0200  |null                      |null                      |
|F                         |2021-10-23T06:00:06+0200  |F                         |2021-10-23T06:00:07+0200  |
|F                         |2021-10-23T06:00:06+0200  |F                         |2021-10-23T06:00:07+0200  |
|G                         |2021-10-23T06:00:08+0200  |null                      |null                      |
|G                         |2021-10-23T06:00:08+0200  |G                         |2021-10-23T06:00:09+0200  |
|G                         |2021-10-23T06:00:08+0200  |G                         |2021-10-23T06:00:09+0200  |
|null                      |null                      |B                         |2021-10-23T06:00:11+0200  |
```
For record A, an event is emitted once the view is processed. There is no click yet. When the click arrives, the joined event on view and click is emitted. For records B, we also get two output events. However, since the events do not occur within the window, neither of these events contains both view and click (i.e., both are independent outer-join results). “View” record D appears in the output without a click, and the equivalent (but “reverse”) output is emitted for “click” record E. Records F produce 4 output events as there are two views that are emitted immediately and once again when they are joined against a click. In contrast, records G produce only 3 events as both clicks can be immediately joined against a view that arrived earlier.
### Ktable to Ktable joins
#### Creating a materialized view for AdViews
```
CREATE TABLE AdViews_view AS
  SELECT id AS ID, LATEST_BY_OFFSET(ts) AS TS
  FROM AdViews_STREAM
  GROUP BY id
  EMIT CHANGES;
```
#### Creating a materialized view for AdClicks
```
CREATE TABLE AdClicks_view AS
  SELECT id AS ID, LATEST_BY_OFFSET(ts) AS TS
  FROM AdClicks_STREAM
  GROUP BY id
  EMIT CHANGES;
```
#### Inner join
Joins on KTables are not windowed and their result is an ever-updating view of the join result of both input tables. If one input table is updated, the resulting KTable is also updated accordingly; note that this update to the result table is a new output record only, because the resulting KTable is not materialized by default.
```
SELECT V.id AS ID, V.ts AS TS_VIEW, C.ts AS TS_CLICK
FROM AdViews_view V
  INNER JOIN AdClicks_view C
  ON V.id = C.id
  EMIT CHANGES;
```
##### Result
![](https://cdn.confluent.io/wp-content/uploads/Inner-Table-Table-Join-768x727.jpg)
```
+-----------------------------------+-----------------------------------+-----------------------------------+
|ID                                 |TS_VIEW                            |TS_CLICK                           |
+-----------------------------------+-----------------------------------+-----------------------------------+
|A                                  |2021-10-23T06:00:00+0200           |2021-10-23T06:00:01+0200           |
|C                                  |2021-10-23T06:00:03+0200           |2021-10-23T06:00:02+0200           |
|F                                  |2021-10-23T06:00:06+0200           |2021-10-23T06:00:07+0200           |
|G                                  |2021-10-23T06:00:08+0200           |2021-10-23T06:00:09+0200           |
|B                                  |2021-10-23T06:00:01+0200           |2021-10-23T06:00:11+0200           |
```
All the inner join pairs are emitted as expected. Since we’re no longer windowed, even record B/B is in the result. Note, that the result contains only one result for F but two for G. Because click F appears after views F.1 and F.2, F.2 did replace F.1 before F triggers the join computation. For G, the view arrives before both clicks and thus, G.1 and G.2 join with G. This scenario demonstrates the update behavior of table-table join. After G.1 arrived, the join result is G.1/G. Then the click event G.2 updates the click table and triggers a recomputation of the join result to G.2/G.1

We want to point out that this update behavior also applies to deletions. If, for example, one input KTable is directly consumed from a compacted changelog topic and a tombstone record is consumed (a tombstone is a message with format <key:null> and has delete semantics), a result might be removed from the resulting KTable. This is indicated by appending a tombstone record to the resulting KTable.2

Last but not least, similar to our KStream-KStream examples, we assume that records are processed in timestamp order. In practice, this might not hold as time synchronization between streams or tables is based on a best-effort principle. Thus, the intermediate result might differ slightly. For example, click F might get processed before views F.1 and F.2 even if click F has a larger timestamp. If this happens, we would get an additional intermediate result F.1/F before we get final result F.2/F. We want to point out that this runtime dependency does only apply to intermediate but not to the “final” result that is always the same.
#### Left join
```
SELECT V.id AS ID_VIEW, V.ts AS TS_VIEW, C.id AS ID_CLICK, C.ts AS TS_CLICK
FROM AdViews_view V
  LEFT JOIN AdClicks_view C
  ON V.id = C.id
  EMIT CHANGES;
```
##### Result
![](https://cdn.confluent.io/wp-content/uploads/Left-Table-Table-Join-768x727.jpg)
```
+--------------------------+--------------------------+--------------------------+--------------------------+
|ID_VIEW                   |TS_VIEW                   |ID_CLICK                  |TS_CLICK                  |
+--------------------------+--------------------------+--------------------------+--------------------------+
|D                         |2021-10-23T06:00:04+0200  |null                      |null                      |
|A                         |2021-10-23T06:00:00+0200  |A                         |2021-10-23T06:00:01+0200  |
|C                         |2021-10-23T06:00:03+0200  |C                         |2021-10-23T06:00:02+0200  |
|F                         |2021-10-23T06:00:06+0200  |F                         |2021-10-23T06:00:07+0200  |
|G                         |2021-10-23T06:00:08+0200  |G                         |2021-10-23T06:00:09+0200  |
|B                         |2021-10-23T06:00:01+0200  |B                         |2021-10-23T06:00:11+0200  |
```
The result is the same as with the inner join with the addition of proper data for (left) view events A, B, D, F.1, F.1, and G that do a left join with empty right-hand side when they are processed first. Thus, view D is preserved and only click E is not contained as there is no corresponding view.
#### Outer join
```
SELECT V.id AS ID_VIEW, V.ts AS TS_VIEW, C.id AS ID_CLICK, C.ts AS TS_CLICK
FROM AdViews_view V
  FULL OUTER JOIN AdClicks_view C
  ON V.id = C.id
  EMIT CHANGES;
```
##### Result
![](https://cdn.confluent.io/wp-content/uploads/Outer-Table-Table-Join-768x727.jpg)
```
+--------------------------+--------------------------+--------------------------+--------------------------+
|ID_VIEW                   |TS_VIEW                   |ID_CLICK                  |TS_CLICK                  |
+--------------------------+--------------------------+--------------------------+--------------------------+
|D                         |2021-10-23T06:00:04+0200  |null                      |null                      |
|A                         |2021-10-23T06:00:00+0200  |A                         |2021-10-23T06:00:01+0200  |
|C                         |2021-10-23T06:00:03+0200  |C                         |2021-10-23T06:00:02+0200  |
|null                      |null                      |E                         |2021-10-23T06:00:05+0200  |
|F                         |2021-10-23T06:00:06+0200  |F                         |2021-10-23T06:00:07+0200  |
|G                         |2021-10-23T06:00:08+0200  |G                         |2021-10-23T06:00:09+0200  |
|B                         |2021-10-23T06:00:01+0200  |B                         |2021-10-23T06:00:11+0200  |
```
The result is the same as with the left join plus the “right join” result records for clicks C and D with an empty left-hand side.

 We can observe that KTable-KTable join is pretty close to SQL semantics and thus easy to understand. The difference to plain SQL is that the resulting KTable gets updated automatically if an input KTable is updated. Thus, the resulting KTable can be described as an ever-updating view of the table join. 
### Kstream to Ktable joins
Similar to a table-table join, this join is not windowed; however, the output of this operation is another stream, and not a table. However, differently from the other two cases, stream-table join is asymmetric, in this case only the (left) stream input triggers a join computation. Because the join is not-windowed, the (left) input stream is stateless and thus, join lookups from table record to stream records are not possible.

Usually, this semantics is used to enrich a data stream with auxiliary information from a table. However, for the example in use we'll use the *"views"* as the left stream and *"clicks"* as the right table input: 
#### Inner join
```
SELECT V.id AS ID, V.ts AS TS_VIEW, C.ts AS TS_CLICK
FROM AdViews_STREAM V
  INNER JOIN AdClicks_view C
  ON V.id = C.id
EMIT CHANGES;
```
##### Result
![](https://cdn.confluent.io/wp-content/uploads/Inner-Stream-Table-Join-768x561.jpg)
```
+-----------------------------------+-----------------------------------+-----------------------------------+
|ID                                 |TS_VIEW                            |TS_CLICK                           |
+-----------------------------------+-----------------------------------+-----------------------------------+
|C                                  |2021-10-23T06:00:03+0200           |2021-10-23T06:00:02+0200           |
```
The result is just a single record as click C is the only click that arrives before the corresponding view event.
#### Left join
It’s the same as an inner KStream-KTable join but preserves all (left) stream input records in case there is no matching join record in the (right) KTable input.
```
SELECT V.id AS ID_VIEW, V.ts AS TS_VIEW, C.id AS ID_CLICK, C.ts AS TS_CLICK
FROM AdViews_STREAM V
  LEFT JOIN AdClicks_view C
  ON V.id = C.id
EMIT CHANGES;
```
##### Result
![](https://cdn.confluent.io/wp-content/uploads/Left-Stream-Table-Join-768x561.jpg)
```
+--------------------------+--------------------------+--------------------------+--------------------------+
|ID_VIEW                   |TS_VIEW                   |ID_CLICK                  |TS_CLICK                  |
+--------------------------+--------------------------+--------------------------+--------------------------+
|A                         |2021-10-23T06:00:00+0200  |null                      |null                      |
|B                         |2021-10-23T06:00:01+0200  |null                      |null                      |
|C                         |2021-10-23T06:00:03+0200  |C                         |2021-10-23T06:00:02+0200  |
|D                         |2021-10-23T06:00:04+0200  |null                      |null                      |
|F                         |2021-10-23T06:00:06+0200  |null                      |null                      |
|F                         |2021-10-23T06:00:06+0200  |null                      |null                      |
|G                         |2021-10-23T06:00:08+0200  |null                      |null                      |
```
As expected, we get the inner C/C join result as well as one join result for each (left) stream record.

## Acknowledgements
Images and examples were taken from the article "Crossing the Streams – Joins in Apache Kafka" available here: https://www.confluent.io/blog/crossing-streams-joins-apache-kafka/
