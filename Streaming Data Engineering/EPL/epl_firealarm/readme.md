# Esper & EPL

## resources

* [espertech](https://www.espertech.com)
* [EPL documentation](http://esper.espertech.com/release-8.8.0/reference-esper/html/index.html)
* [online environment to try EPL](http://esper-epl-tryout.appspot.com/epltryout/mainform.html)

## let's get dirty

### running example

> Count the number of fires detected using a set of smoke and temperature sensors in the last 10 minutes
> A fire is detected if at the same sensor a smoke event is followed by a temperature>50 events within 2 minutes


### schema of the event types for the running example

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

### data stream for the running example

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
```

visually

![](img/time-line.png)

### let's explore the EPL syntax by example

#### Q0

the temperature events whose temperature is greater than 50 C°

##### the SQL style

```
@Name('Q0')
select *
from TemperatureSensorEvent
where temperature > 50;
```

visually

![](img/Q0.png)

Execution mode: Data points enter the query that filters them  


##### The Event-Based System Style

```
@Name('Q0bis')
select *
from TemperatureSensorEvent(temperature > 50) ;
```

visually

![](img/Q0bis.png)

Execution mode: data points are filtered before flowing into the query and the query execution does not get triggered


#### Q1
the average of all the temperature observations for each sensor up to the last event received


```
@Name('Q1')
select sensor, avg(temperature)
from TemperatureSensorEvent
group by sensor;
```

visually

![](img/Q1.png)

Execution mode

* From a logical perspective, data points cumulate in the landmark window, and the query emits a new avg for every data point
* From a physical perspective, the query is evaluated incrementally and maintains a state that captures the number of events (cnt) seen so far and the last avg. The new average depends on the state and the latest data point entering the query. Old data can be forgotten.


Not all the algorithms can be converted to a streaming one, e.g., there is not **an exact** way to compute the standard deviation in a streaming algorithm. However, there is an [approximate streaming algorithm for the standard deviation](https://math.stackexchange.com/questions/198336/how-to-calculate-standard-deviation-with-streaming-inputs) that **assumes** the stationarity of the observed process.

NOTE: even if you cannot read it in the syntax, a *landmark window* opens when the stream starts (or when you register the query in esper) and keeps widening. As a side note, the *logical unbounded table* assumed by spark is a landmark window, so the two words are synonyms. 

#### Q2
the average temperature observed by each sensor in the last 4 seconds (a.k.a. **logical sliding window**)

Assumption: the average should change as soon as they receive a new event

```
@Name('Q2')
select sensor, avg(temperature)
from TemperatureSensorEvent.win:time(4 seconds)
group by sensor;
```

#### Q1's vs. Q2's results 

I am elaborating more on Q2 (landmark window) and the difference with Q3 (sliding window).

![](img/EPL07.jpg)


#### Q3
the average temperature of the last 4 seconds every 4 seconds (a.k.a. **logical tumbling window**)


```
@Name('Q3')
select sensor, avg(temperature)
from TemperatureSensorEvent.win:time_batch(4 seconds)
group by sensor;
```

#### Q4
the moving average of the last 4 temperature events (a.k.a. **physical sliding window**)

```
@Name('Q4')
select sensor, avg(temperature)
from TemperatureSensorEvent.win:length(4)
group by sensor;
```

#### Q5
the moving average of the last 4 temperature events every 4 events (a.k.a. **physical tumbling window**)

```
@Name('Q5')
select sensor, avg(temperature)
from TemperatureSensorEvent.win:length_batch(4)
group by sensor;
```

#### Q3 vs. Q4 vs. Q4

![](./img/EPL08.jpg)

#### Q6
the average temperature of the last 4 seconds every 2 seconds (a.k.a. **logical hopping window**)

```
@Name('Q6')
select sensor, avg(temperature)
from TemperatureSensorEvent.win:time(4 seconds)
group by sensor
output last every 2 seconds;
```

#### Deep dive into the reporting policy specified by the `output ... every` clause

first some data

```
TemperatureSensorEvent={sensor='S1', temperature=30}
TemperatureSensorEvent={sensor='S1', temperature=31}
TemperatureSensorEvent={sensor='S1', temperature=32}
t=t.plus(1 seconds)
TemperatureSensorEvent={sensor='S1', temperature=40}
TemperatureSensorEvent={sensor='S1', temperature=41}
TemperatureSensorEvent={sensor='S1', temperature=42}
t=t.plus(1 seconds)
```

Let's see the different behavior of the following queries.

```
@Name('Q2')
select sensor, avg(temperature)
from TemperatureSensorEvent.win:time(4 seconds)
group by sensor;

@Name('Q2.first')
select sensor, avg(temperature)
from TemperatureSensorEvent.win:time(4 seconds)
group by sensor
output first every 1 second ;

@Name('Q2.last')
select sensor, avg(temperature)
from TemperatureSensorEvent.win:time(4 seconds)
group by sensor
output last every 1 second ;

@Name('Q2.all')
select sensor, avg(temperature)
from TemperatureSensorEvent.win:time(4 seconds)
group by sensor
output all every 1 second ;

```

![](./img/EPL09.png)

As you can see, `last` and `all` have the same answers. If you want to see a difference between `last` and `all`, we can try to look into the window's content.

```
@Name('Q.default')
select *
from TemperatureSensorEvent.win:time(4 seconds)
;

@Name('Q.first')
select *
from TemperatureSensorEvent.win:time(4 seconds)
output first every 1 second ;

@Name('Q.last')
select*
from TemperatureSensorEvent.win:time(4 seconds)
output last every 1 second ;

@Name('Q.all')
select*
from TemperatureSensorEvent.win:time(4 seconds)
output all every 1 second ;
```

`all` returns the entire content of the window. If you want to dive further, check out [section 5.7.1 of the EPL documentation](http://esper.espertech.com/release-8.8.0/reference-esper/html/epl_clauses.html#epl-output-options).


#### Q7

Let's move on to the pattern matching part (a.k.a., the part of the language for Complex Event Processing)

Remember the running example: find every smoke event followed by a temperature above 50 °C within 2 minutes.

There is a particular operator to say *followed by* (syntactically  `->`) to use within the [`pattern` clause](http://esper.espertech.com/release-8.8.0/reference-esper/html/event_patterns.html) 

Let's try using it naively.

```
@Name('Q7.naive')
select *
from pattern [
  s = SmokeSensorEvent(smoke=true)
  ->
  TemperatureSensorEvent(temperature > 50, sensor=s.sensor)
]
;
```

Is this what we want?

Indeed this *tames the torrent effect*, but is there a way to have more results?

yes, using the [`every` clause](http://esper.espertech.com/release-8.8.0/reference-esper/html/event_patterns.html#pattern-logical-every)

```
@Name('Q7.every')
select *
from pattern [
 every (
  s = SmokeSensorEvent(smoke=true)
  ->
  TemperatureSensorEvent(temperature > 50, sensor=s.sensor)
)
]
;
```

![](./img/EPL10.png)

Moreover, you may not like the payload of the events generated by this query.

You can create what you want, making a *projection* as in SQL.

```
@Name('Q7.every.projection')
select s.sensor AS sensor, t.temperature AS temperature, s.smoke as smoke
from pattern [
 every (
  s = SmokeSensorEvent(smoke=true)
  ->
  t = TemperatureSensorEvent(temperature > 50, sensor=s.sensor)
)
]
;
```

Now, we need to insert the results in the FireEvent stream.

```
@Name('Q7.insert')
insert into FireEvent
select a.sensor AS sensor,
         a.smoke AS smoke,
         b.temperature AS temperature
from pattern [
   every (
                a = SmokeSensorEvent(smoke=true)
                ->
                b = TemperatureSensorEvent(temperature > 50,  sensor=a.sensor )
                )
];
```

One last step and we have Q7 finalized. Let's add the "*within 2 minutes*" constraint.


```@Name('Q7')
insert into FireEvent
select s.sensor as sensor, s.smoke as smoke, t.temperature as temperature
from pattern [
   every (
    s=SmokeSensorEvent(smoke=true)
      -> (
    t=TemperatureSensorEvent(temperature>50,sensor=s.sensor)
    where timer:within(2 seconds) 
    )
  )  
]
;
```

NOTE: alter some statements that advance the time to change the results. E.g., change one of the last three `t=t.plus(1 seconds)` in `t=t.plus(3 seconds)`

#### Q8

We are very close to the solution of the running example; we "just" need to count the number of events generated by the previous query over a sliding window of 10 seconds. So let's count the results of  `Q7`

```
@Name('Q8')
select count(*)
from FireEvent.win:time(10 seconds);
```
