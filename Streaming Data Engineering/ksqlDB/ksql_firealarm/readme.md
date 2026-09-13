# KSQL - Demo
## Fire alarm

### set up

#### start up the infrastructure

```
docker-compose up -d
```

#### Open ksqlDB cli

```
docker exec -it ksqldb-cli ksql http://ksqldb-server:8088
```

#### Configure it for this demo

run the following commands that allows to rerun the queries always from the beginning of the data streams. This is **not to use in production**! It is for debugging/educational purpose only.

```
SET 'auto.offset.reset' = 'earliest';
```

### Let's explore ksqlDB by example

Please refer to [../epl_firealarm/readme.md](https://github.com/quantiaconsulting/continuous-analytics-examples/blob/master/epl_firealarm/readme.md) for the EPL version of the following queries.


#### Let's create the Kstreams ontop of Kafka topics
 
```
CREATE STREAM Temperature_STREAM (sensor VARCHAR, temperature DOUBLE, ts VARCHAR)
  WITH (
  kafka_topic='Temperature_topic', 
  value_format='json', 
  partitions=1,
  timestamp='ts',
  timestamp_format='yyyy-MM-dd''T''HH:mm:ssZ');
```


```
CREATE STREAM Smoke_STREAM (sensor VARCHAR, smoke BOOLEAN, ts VARCHAR)
  WITH (
  kafka_topic='Smoke_topic', 
  value_format='json', 
  partitions=1,
  timestamp='ts',
  timestamp_format='yyyy-MM-dd''T''HH:mm:ssZ');
```

```
show topics;
```

#### Let's insert some data into them

NOTE: Normally you do not insert data manually, this is for educational purpose only.

```
INSERT INTO Temperature_STREAM (sensor, temperature, ts) VALUES ('S1', 30,'2021-10-23T06:00:00+0200');
INSERT INTO Smoke_STREAM (sensor, smoke, ts) VALUES ('S1', false, '2021-10-23T06:00:00+0200');
INSERT INTO Temperature_STREAM (sensor, temperature, ts) VALUES ('S1', 40, '2021-10-23T06:00:01+0200');
INSERT INTO Smoke_STREAM (sensor, smoke, ts) VALUES ('S1', true, '2021-10-23T06:00:01+0200');
INSERT INTO Temperature_STREAM (sensor, temperature, ts) VALUES ('S1', 55, '2021-10-23T06:00:02+0200');
INSERT INTO Smoke_STREAM (sensor, smoke, ts) VALUES ('S1', true, '2021-10-23T06:00:02+0200');
INSERT INTO Temperature_STREAM (sensor, temperature, ts) VALUES ('S1', 55, '2021-10-23T06:00:03+0200');
INSERT INTO Smoke_STREAM (sensor, smoke, ts) VALUES ('S1', true, '2021-10-23T06:00:03+0200');
INSERT INTO Temperature_STREAM (sensor, temperature, ts) VALUES ('S1', 55, '2021-10-23T06:00:04+0200');
INSERT INTO Smoke_STREAM (sensor, smoke, ts) VALUES ('S1', true, '2021-10-23T06:00:04+0200');

```

#### Q0 - Filter

the temperature events whose temperature is greater than 50 °C 

```
SELECT *
FROM Temperature_STREAM
WHERE temperature > 50 EMIT CHANGES;
```

The query returns:

```
+------------------------+------------------------+------------------------+
|SENSOR                  |TEMPERATURE             |TS                      |
+------------------------+------------------------+------------------------+
|S1                      |55.0                    |2021-10-23T06:00:02+0200|
|S1                      |55.0                    |2021-10-23T06:00:03+0200|
|S1                      |55.0                    |2021-10-23T06:00:04+0200|
```

Note that the query is still running. If you open another ksqlDB CLI in another terminal:

```
docker exec -it ksqldb-cli ksql http://ksqldb-server:8088
```

and you send more data

```
INSERT INTO Temperature_STREAM (sensor, temperature, ts) VALUES ('S1', 30, '2021-10-23T06:00:05+0200');
INSERT INTO Temperature_STREAM (sensor, temperature, ts) VALUES ('S1', 60, '2021-10-23T06:00:06+0200');
```

the result will be updated accordingly

```
+------------------------+------------------------+------------------------+
|SENSOR                  |TEMPERATURE             |TS                      |
+------------------------+------------------------+------------------------+
|S1                      |55.0                    |2021-10-23T06:00:02+0200|
|S1                      |55.0                    |2021-10-23T06:00:03+0200|
|S1                      |55.0                    |2021-10-23T06:00:04+0200|
|S1                      |60.0                    |2021-10-23T06:00:06+0200|
```

#### Q1 - Avg

the average of all the temperature observation for each sensor up to the last event received


```
SELECT SENSOR, AVG(temperature) AS AVG_TEMP
FROM Temperature_STREAM
GROUP BY SENSOR EMIT CHANGES;
```

this query will return

```
+--------------------------------------+--------------------------------------+
|SENSOR                                |AVG_TEMP                              |
+--------------------------------------+--------------------------------------+
|S1                                    |46.42857142857143                     |
```

If you want to see it changing, you can insert more data in the other CLI, e.g.,

```
INSERT INTO Temperature_STREAM (sensor, temperature, ts) VALUES ('S1', 70, '2021-10-23T06:00:07+0200');
```

The answer becomes:

```
+--------------------------------------+--------------------------------------+
|SENSOR                                |AVG_TEMP                              |
+--------------------------------------+--------------------------------------+
|S1                                    |46.42857142857143                     |
|S1                                    |49.375                                |
```


#### Q2 - Logical Sliding Window

The average temperature observed by each sensor in the last 4 seconds

MEMO: the average should change as soon as the receive a new event

**Partially supported, see the discussion in Q3**


#### Q3 - [Logical Tumbling Window](https://docs.ksqldb.io/en/latest/concepts/time-and-windows-in-ksqldb-queries/#tumbling-window)

The average temperature of the last 4 seconds every 4 seconds

```
SELECT SENSOR, AVG(temperature) AS AVG_TEMP
FROM Temperature_STREAM 
     WINDOW TUMBLING (SIZE 4 SECONDS)
GROUP BY SENSOR EMIT CHANGES;
```

returning 

```
+--------------------------------------+--------------------------------------+
|SENSOR                                |AVG_TEMP                              |
+--------------------------------------+--------------------------------------+
|S1                                    |45.0                                  |
|S1                                    |53.75                                 |
```

##### But the semantics is not so linear

First of all, let's inspect the start and the end of the windows

```
SELECT SENSOR, 
		AVG(temperature) AS AVG_TEMP,
		WINDOWSTART AS window_start,
       WINDOWEND AS window_end
FROM Temperature_STREAM 
     WINDOW TUMBLING (SIZE 4 SECONDS)
GROUP BY SENSOR EMIT CHANGES;
```

or even better using  TIMESTAMPTOSTRING to have a human readable timestamp

```
SELECT SENSOR, 
		AVG(temperature) AS AVG_TEMP,
		TIMESTAMPTOSTRING(WINDOWSTART, 'yyy-MM-dd HH:mm:ssZ','UTC+2') as window_start,
       TIMESTAMPTOSTRING(WINDOWEND, 'yyy-MM-dd HH:mm:ssZ','UTC+2') as window_end
FROM Temperature_STREAM 
     WINDOW TUMBLING (SIZE 4 SECONDS)
GROUP BY SENSOR EMIT CHANGES;
```

you get a result like this:

```
+--------------------------+--------------------------+--------------------------+--------------------------+
|SENSOR                    |AVG_TEMP                  |WINDOW_START              |WINDOW_END                |
+--------------------------+--------------------------+--------------------------+--------------------------+
|S1                        |45.0                      |2021-10-23 06:00:00+0200  |2021-10-23 06:00:04+0200  |
|S1                        |53.75                     |2021-10-23 06:00:04+0200  |2021-10-23 06:00:08+0200  |
```

**NOTE**: windows include WINDOW_START but not WINDOW_END

if you send more data within the scope of the last window: 

```
INSERT INTO Temperature_STREAM (sensor, temperature, ts) VALUES ('S1', 80, '2021-10-23T06:00:07+0200');
```

a new result appears for the same window (see window_start and window_end):

```
+--------------------------+--------------------------+--------------------------+--------------------------+
|SENSOR                    |AVG_TEMP                  |WINDOW_START              |WINDOW_END                |
+--------------------------+--------------------------+--------------------------+--------------------------+
|S1                        |45.0                      |2021-10-23 06:00:00+0200  |2021-10-23 06:00:04+0200  |
|S1                        |53.75                     |2021-10-23 06:00:04+0200  |2021-10-23 06:00:08+0200  |
|S1                        |59.0                      |2021-10-23 06:00:04+0200  |2021-10-23 06:00:08+0200  |
```

if you send more data within the scope of the next window: 

```
INSERT INTO Temperature_STREAM (sensor, temperature, ts) VALUES ('S1', 80, '2021-10-23T06:00:09+0200');
```

a new window appears (see window_start and window_end) with the next result

```
+--------------------------+--------------------------+--------------------------+--------------------------+
|SENSOR                    |AVG_TEMP                  |WINDOW_START              |WINDOW_END                |
+--------------------------+--------------------------+--------------------------+--------------------------+
|S1                        |45.0                      |2021-10-23 06:00:00+0200  |2021-10-23 06:00:04+0200  |
|S1                        |53.75                     |2021-10-23 06:00:04+0200  |2021-10-23 06:00:08+0200  |
|S1                        |59.0                      |2021-10-23 06:00:04+0200  |2021-10-23 06:00:08+0200  |
|S1                        |80.0                      |2021-10-23 06:00:08+0200  |2021-10-23 06:00:12+0200  |
```

but if you stop and you rerun the query, you get only a result per window

```
+--------------------------+--------------------------+--------------------------+--------------------------+
|SENSOR                    |AVG_TEMP                  |WINDOW_START              |WINDOW_END                |
+--------------------------+--------------------------+--------------------------+--------------------------+
|S1                        |45.0                      |2021-10-23 06:00:00+0200  |2021-10-23 06:00:04+0200  |
|S1                        |59.0                      |2021-10-23 06:00:04+0200  |2021-10-23 06:00:08+0200  |
|S1                        |80.0                       |2021-10-23 06:00:08+0200 |2021-10-23 06:00:12+0200  |
```

**SO** the tubling windows behaves as in EPL on the historical data, but they also give real-time updates whenever a new data arrives.

**NOTE**: ksqlDB also handles late arrivals

If you send

```
INSERT INTO Temperature_STREAM (sensor, temperature, ts) VALUES ('S1', 70, '2021-10-23T06:00:07+0200');
```

whose timestamp makes it fit into the window [06:00:04+0200-06:00:08+0200] the results is:

```
+--------------------------+--------------------------+--------------------------+--------------------------+
|SENSOR                    |AVG_TEMP                  |WINDOW_START              |WINDOW_END                |
+--------------------------+--------------------------+--------------------------+--------------------------+
|S1                        |45.0                      |2021-10-23 06:00:00+0200  |2021-10-23 06:00:04+0200  |
|S1                        |59.0                      |2021-10-23 06:00:04+0200  |2021-10-23 06:00:08+0200  |
|S1                        |80.0                      |2021-10-23 06:00:08+0200  |2021-10-23 06:00:12+0200  |
|S1                        |60.833333333333336        |2021-10-23 06:00:04+0200  |2021-10-23 06:00:08+0200  |
```

For more information about late arrivals, see the [`GRACE PERIOD` clause]( https://docs.ksqldb.io/en/latest/concepts/time-and-windows-in-ksqldb-queries/#out-of-order-events)

#### Q4 - Physical Sliding Window

The moving average of the last 4 temperature events

**Not supported**


#### Q5 - Physical Tumbling Window

The moving average of the last 4 temperature events every 4 events

**Not supported**

#### Q6 - [Logical Hopping Window](https://docs.ksqldb.io/en/latest/concepts/time-and-windows-in-ksqldb-queries/#hopping-window)

The average temperature of the last 4 seconds every 2 seconds

```
SELECT SENSOR, 
		AVG(temperature) AS AVG_TEMP,
		TIMESTAMPTOSTRING(WINDOWSTART, 'yyy-MM-dd HH:mm:ssZ','UTC+2') as window_start,
       TIMESTAMPTOSTRING(WINDOWEND, 'yyy-MM-dd HH:mm:ssZ','UTC+2') as window_end
FROM Temperature_STREAM 
      WINDOW HOPPING (SIZE 4 SECONDS, ADVANCE BY 2 SECONDS)
GROUP BY SENSOR EMIT CHANGES;
```

returning

```
+--------------------------+--------------------------+--------------------------+--------------------------+
|SENSOR                    |AVG_TEMP                  |WINDOW_START              |WINDOW_END                |
+--------------------------+--------------------------+--------------------------+--------------------------+
|S1                        |35.0                      |2021-10-23 05:59:58+0200  |2021-10-23 06:00:02+0200  |
|S1                        |45.0                      |2021-10-23 06:00:00+0200  |2021-10-23 06:00:04+0200  |
|S1                        |48.75                     |2021-10-23 06:00:02+0200  |2021-10-23 06:00:06+0200  |
|S1                        |80.0                      |2021-10-23 06:00:08+0200  |2021-10-23 06:00:12+0200  |
|S1                        |60.833333333333336        |2021-10-23 06:00:04+0200  |2021-10-23 06:00:08+0200  |
|S1                        |72.0                      |2021-10-23 06:00:06+0200  |2021-10-23 06:00:10+0200  |
```

NOTE: sending more data it behaves as the logical tumbling window in Q3.

#### Q7 - Stream-to-Stream Join

In EPL, at this point we moved on to the pattern matching part required to satisfy the information need, i.e., "find every smoke event followed by a temperature event whose temperature is above 50 °C within 2 minutes."

ksqlDB does not support the EPL's operator `->` (that reads as followed by). We need to use a stream-to-stream join.

```
SELECT *
FROM Temperature_STREAM T
  JOIN Smoke_STREAM S WITHIN 2 MINUTES
  ON S.sensor = T.sensor
 WHERE 
 T.temperature > 50 and
 S.smoke  and
 S.ts < T.ts 
 EMIT CHANGES;
```

##### Discussion

This query is equivalent to the EPL pattern `every a = SmokeSensorEvent(smoke=true) -> every TemperatureSensorEvent(temperature > 50, sensor=a.sensor) where timer:within(2 min)`.

Do not expect the same performances! It is evaluated as a relational join. ksqlDB lacks the specialised data structure of Esper.

However, ksqlDB partially deals with the torrent effect thanks to the two [aggregate functions `LATEST_BY_OFFSET` and `EARLIEST_BY_OFFSET`](https://docs.ksqldb.io/en/latest/developer-guide/ksqldb-reference/aggregate-functions/)

You can create a materialised view

```
CREATE TABLE FireAlerts AS
SELECT S.sensor AS sensor,
		LATEST_BY_OFFSET(S.smoke) AS smoke,
		LATEST_BY_OFFSET(S.ts) AS smoke_ts,
		LATEST_BY_OFFSET(T.temperature) AS temperature,
		LATEST_BY_OFFSET(T.ts) AS temperature_ts
		
FROM Temperature_STREAM T
  JOIN Smoke_STREAM S WITHIN 2 MINUTES
  ON S.sensor = T.sensor
 WHERE 
 T.temperature > 50 and
 S.smoke  and
 S.ts < T.ts 
 group by S.sensor
 EMIT CHANGES;
``` 

and query it with a pull query

```
SELECT * FROM FireAlerts WHERE sensor='S1';
```


#### Q8 - Count FireEvent 

we are very close to the solution of the running example, we "just" need to count the number of events generated by the previous query over an hopping window of 10 seconds that slides every seconds (was a sliding window in EPL).

```
CREATE STREAM Fire_STREAM AS
SELECT S.sensor AS sensor, 
		S.smoke AS smoke, 
		T.temperature AS temperature
FROM Temperature_STREAM T
  JOIN Smoke_STREAM S WITHIN 2 MINUTES
  ON S.sensor = T.sensor
 WHERE 
 T.temperature > 50 and
 S.smoke  and
 S.ts < T.ts 
 EMIT CHANGES;
```

```
SELECT SENSOR, count(*) AS CNT,
		TIMESTAMPTOSTRING(WINDOWSTART, 'yyy-MM-dd HH:mm:ssZ','UTC+2') as window_start,
       TIMESTAMPTOSTRING(WINDOWEND, 'yyy-MM-dd HH:mm:ssZ','UTC+2') as window_end

FROM Fire_STREAM 
      WINDOW HOPPING (SIZE 10 SECONDS, ADVANCE BY 1 SECOND)
GROUP BY SENSOR 
EMIT CHANGES;
```

that returns

```
+---------------------------+---------------------------+---------------------------+---------------------------+
|SENSOR                     |KSQL_COL_0                 |WINDOW_START               |WINDOW_END                 |
+---------------------------+---------------------------+---------------------------+---------------------------+
|S1                         |1                          |2021-10-23 05:59:53+0200   |2021-10-23 06:00:03+0200   |
|S1                         |3                          |2021-10-23 05:59:54+0200   |2021-10-23 06:00:04+0200   |
|S1                         |6                          |2021-10-23 05:59:55+0200   |2021-10-23 06:00:05+0200   |
|S1                         |6                          |2021-10-23 05:59:56+0200   |2021-10-23 06:00:06+0200   |
|S1                         |10                         |2021-10-23 05:59:57+0200   |2021-10-23 06:00:07+0200   |
|S1                         |22                         |2021-10-23 05:59:58+0200   |2021-10-23 06:00:08+0200   |
|S1                         |22                         |2021-10-23 05:59:59+0200   |2021-10-23 06:00:09+0200   |
|S1                         |26                         |2021-10-23 06:00:00+0200   |2021-10-23 06:00:10+0200   |
|S1                         |26                         |2021-10-23 06:00:01+0200   |2021-10-23 06:00:11+0200   |
|S1                         |26                         |2021-10-23 06:00:02+0200   |2021-10-23 06:00:12+0200   |
|S1                         |25                         |2021-10-23 06:00:03+0200   |2021-10-23 06:00:13+0200   |
|S1                         |23                         |2021-10-23 06:00:04+0200   |2021-10-23 06:00:14+0200   |
|S1                         |20                         |2021-10-23 06:00:05+0200   |2021-10-23 06:00:15+0200   |
|S1                         |20                         |2021-10-23 06:00:06+0200   |2021-10-23 06:00:16+0200   |
|S1                         |16                         |2021-10-23 06:00:07+0200   |2021-10-23 06:00:17+0200   |
|S1                         |4                          |2021-10-23 06:00:08+0200   |2021-10-23 06:00:18+0200   |
|S1                         |4                          |2021-10-23 06:00:09+0200   |2021-10-23 06:00:19+0200   |
```

We can expose it to a downstream app using a materialized view 

```
CREATE TABLE Fire_Alarm_Count AS
SELECT SENSOR, count(*) AS CNT,
		TIMESTAMPTOSTRING(WINDOWSTART, 'yyy-MM-dd HH:mm:ssZ','UTC+2') as window_start,
       TIMESTAMPTOSTRING(WINDOWEND, 'yyy-MM-dd HH:mm:ssZ','UTC+2') as window_end
FROM Fire_STREAM 
      WINDOW HOPPING (SIZE 10 SECONDS, ADVANCE BY 1 SECOND)
GROUP BY SENSOR 
EMIT CHANGES;
```

querable also with a [pull query](https://docs.ksqldb.io/en/latest/developer-guide/ksqldb-reference/select-pull-query/)

```
select * from Fire_Alarm_Count 
WHERE 
SENSOR ='S1' and 
WINDOWSTART >= '2021-10-23T06:00:00+0200' AND
WINDOWEND <= '2021-10-23T06:00:10+0200';
```

returning 

```
+-----------------+-----------------+-----------------+-----------------+-----------------+-----------------+
|SENSOR           |WINDOWSTART      |WINDOWEND        |CNT              |WINDOW_START     |WINDOW_END       |
+-----------------+-----------------+-----------------+-----------------+-----------------+-----------------+
|S1               |1634961600000    |1634961610000    |26               |2021-10-23 06:00:|2021-10-23 06:00:|
|                 |                 |                 |                 |00+0200          |10+0200          |
```


### Bonus content

#### [Session windows](https://docs.ksqldb.io/en/latest/concepts/time-and-windows-in-ksqldb-queries/#session-window)

A session window aggregates records into a session, which represents a period of activity separated by a specified gap of inactivity, or "idleness". Any records with timestamps that occur within the inactivity gap of existing sessions are merged into the existing sessions. If a record's timestamp occurs outside of the session gap, a new session is created.

A new session window starts if the last record that arrived is further back in time than the specified inactivity gap.

Session windows are different from the other window types, because:

* ksqlDB tracks all session windows independently across keys, so windows of different keys typically have different start and end times.
* Session window durations vary. Even windows for the same key typically have different durations.

Session windows are especially useful for user behavior analysis. Session-based analyses range from simple metrics, like counting user visits on a news website or social platform, to more complex metrics, like customer-conversion funnel and event flows.

![](https://docs.ksqldb.io/en/latest/img/ksql-session-windows.gif)

```SQL
SELECT SENSOR, COUNT(*) ,
		TIMESTAMPTOSTRING(WINDOWSTART, 'yyy-MM-dd HH:mm:ssZ','UTC+2') as window_start,
       TIMESTAMPTOSTRING(WINDOWEND, 'yyy-MM-dd HH:mm:ssZ','UTC+2') as window_end
FROM Temperature_STREAM
  WINDOW SESSION (2 SECONDS)
  GROUP BY SENSOR
  EMIT CHANGES;
```  

returns

``` 
+--------------------------+--------------------------+--------------------------+--------------------------+
|SENSOR                    |KSQL_COL_0                |WINDOW_START              |WINDOW_END                |
+--------------------------+--------------------------+--------------------------+--------------------------+
|S1                        |11                        |2021-10-23 06:00:00+0200  |2021-10-23 06:00:09+0200  |
``` 

inserting

```   
INSERT INTO Temperature_STREAM (sensor, temperature, ts) VALUES ('S1', 70, '2021-10-23T06:00:15+0200');
``` 

returns

```   
+--------------------------+--------------------------+--------------------------+--------------------------+
|SENSOR                    |KSQL_COL_0                |WINDOW_START              |WINDOW_END                |
+--------------------------+--------------------------+--------------------------+--------------------------+
|S1                        |11                        |2021-10-23 06:00:00+0200  |2021-10-23 06:00:09+0200  |
|S1                        |1                         |2021-10-23 06:00:15+0200  |2021-10-23 06:00:15+0200  |
``` 

inserting

```   
INSERT INTO Temperature_STREAM (sensor, temperature, ts) VALUES ('S1', 70, '2021-10-23T06:00:16+0200');
``` 

returns

```   
+--------------------------+--------------------------+--------------------------+--------------------------+
|SENSOR                    |KSQL_COL_0                |WINDOW_START              |WINDOW_END                |
+--------------------------+--------------------------+--------------------------+--------------------------+
|S1                        |11                        |2021-10-23 06:00:00+0200  |2021-10-23 06:00:09+0200  |
|S1                        |1                         |2021-10-23 06:00:15+0200  |2021-10-23 06:00:15+0200  |
|S1                        |<TOMBSTONE>               |<TOMBSTONE>               |<TOMBSTONE>               |
|S1                        |2                         |2021-10-23 06:00:15+0200  |2021-10-23 06:00:16+0200  |
```

NOTE: For **tombstone records** see [the documentation](https://docs.confluent.io/5.4.3/ksql/docs/developer-guide/aggregate-streaming-data.html#tombstone-records) and this [post](https://rmoff.net/2020/11/03/kafka-connect-ksqldb-and-kafka-tombstone-messages/).

inserting

```
INSERT INTO Temperature_STREAM (sensor, temperature, ts) VALUES ('S1', 70, '2021-10-23T06:00:07+0200');
```

returns

```
+--------------------------+--------------------------+--------------------------+--------------------------+
|SENSOR                    |KSQL_COL_0                |WINDOW_START              |WINDOW_END                |
+--------------------------+--------------------------+--------------------------+--------------------------+
|S1                        |11                        |2021-10-23 06:00:00+0200  |2021-10-23 06:00:09+0200  |
|S1                        |1                         |2021-10-23 06:00:15+0200  |2021-10-23 06:00:15+0200  |
|S1                        |<TOMBSTONE>               |<TOMBSTONE>               |<TOMBSTONE>               |
|S1                        |2                         |2021-10-23 06:00:15+0200  |2021-10-23 06:00:16+0200  |
|S1                        |12                        |2021-10-23 06:00:00+0200  |2021-10-23 06:00:09+0200  |
```

#### Sending data programmatically

In the folder `../datagen` you find two notebooks to send them smoke and temperature events programmatically:

* Run the code in [../datagen/smoke_sensor_simulator.ipynb](../ksql_firealarm/datagen/smoke_sensor_simulator.ipynb) to simulate the smoke events.
* Run the code in [../datagen/temperature_sensor_simulator.ipynb](../ksql_firealarm/datagen/temperature_sensor_simulator.ipynb) to simulate the temperature events.

They two notebooks use [ksql-python](https://github.com/bryanyang0528/ksql-python), a python wrapper for the KSQL REST API. As you can see, it allows for easily interact with the KSQL REST API using a python library.

### Tear down the stack

When you're done, tear down the stack by running:

```
docker-compose down
```


