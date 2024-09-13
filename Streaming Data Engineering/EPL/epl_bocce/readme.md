# Bocce EPL problem
## Resources

- [espertech](https://www.espertech.com/)
- [EPL documentation](http://esper.espertech.com/release-8.9.0/reference-esper/html/index.html)
- [EPL playground](http://esper-epl-tryout.appspot.com/epltryout/mainform.html)

## The problem

> We want to monitor a Bocce game for two players. Bocce is a famous Italian game played with eight metal balls (called bocce, singular boccia) on a smooth, prepared court. The game also requires a smaller target ball, known as the boccino. The player who starts the game throws the boccino and one of his boccia, aiming to get it as close to the boccino as possible. The opposing player then tries to throw his boccia closer to the boccino or knock the opponent's boccia away.

> In the Bocce game, once the players have thrown all bocce, the round ends, and the scoring is determined. The player with the boccia closest to the boccino earns points. He receives one point for each boccia closer to the boccino than his opponent's closest boccia to the boccino.

> Suppose a camera mounted above the court can detect when a round starts (i.e., the boccino is the only ball on the court). Morevoer, whenever a player throws a boccia, it waits for all the bocce to stop, and then, for each moved boccia, it tells the position in the court and how far it is from the boccino.

<img width="962" src="https://github.com/emanueledellavalle/streaming-data-analytics/assets/5645019/0c54d35b-7d94-4d8b-95f2-d04cf6973ad2">
<a href="https://vimeo.com/873244267">BALINO - Bocce in circolo</a> from <a href="https://vimeo.com/user198205737">benedetta bellucci</a> on <a href="https://vimeo.com">Vimeo</a>.</p>

### Modeling
> Formalize the schema of one or more streams necessary to perform the query in EPL.

Reading the description carefully, it is possible to derive the following schemas:

```  
create schema Boccia(
    playerID int,
    number int,
    distance double, 
    status string
);

create schema Boccino(
    round int
);
```

An event is inserted into the **Boccia** stream once a certain Boccia stops moving after being thrown or hit by another Boccia.

An event is inserted into **Boccino** stream when a new round starts.

### Assumptions
Before delving into the problem, let's define some assumptions to model the data stream and the queries better:

- The status of the Boccia distinguishes if an event is inserted into the **Boccia** stream because the Boccia stops moving after being thrown or after being hit by another Boccia. Specifically, `status = "thrown"` if the boccia is thrown, `status = "hit"` if the boccia is hit.
- Between one throw of the boccia and another, 10 seconds pass.
- The streams start at the beginning of the match.
- The players know how to play and play along the rules.

### Data stream generation
In order to test the queries that will be later presented, let's use the following data stream. Modifying it using different configurations is suggested to test whether your queries will work in different settings.

``` 
Boccino = {round = 1}

t=t.plus(10 seconds)

Boccia = {playerID = 1, number=1, distance=2, status = "thrown"}

t=t.plus(10 seconds)

Boccia = {playerID = 2, number=1, distance=3, status = "thrown"}

t=t.plus(10 seconds)

Boccia = {playerID = 1, number = 2, distance = 3, status = "thrown"}
Boccia = {playerID = 1, number = 1, distance = 1.5, status = "hit"}
Boccia = {playerID = 2, number = 1, distance = 5, status = "hit"}

t=t.plus(10 seconds)

Boccia = {playerID = 2, number=2, distance=0.5, status = "thrown"}
Boccia = {playerID = 1, number = 1, distance = 3.5, status = "hit"}


t=t.plus(10 seconds)
Boccia = {playerID = 1, number=3, distance=2, status = "thrown"}

t=t.plus(10 seconds)
Boccia = {playerID = 2, number=3, distance=5, status = "thrown"}

t=t.plus(10 seconds)
Boccia = {playerID = 1, number=4, distance=7, status = "thrown"}

t=t.plus(10 seconds)
Boccia = {playerID = 2, number=4, distance=8, status = "thrown"}

t=t.plus(10 seconds)

```

### Assignment Q1

> Q1) Determine the total number of Bocce that have been thrown since the beginning of the **match**
>
> Q1 bis) Determine how many Bocce each player has thrown since the beginning of the **match**

#### Solution
Let's start assuming that the data streams contain only the events of a single round. 

The following queries answer to the above requests:

```  
@Name('Q1')
SELECT COUNT(*)
FROM pattern[
every b = Boccino() 
-> 
every B = Boccia(B.status="thrown")
];
```

```  
@Name('Q1bis')
SELECT B.playerID as playerID, COUNT(*)
FROM pattern[
every b = Boccino() 
-> 
every B = Boccia(B.status="thrown")
]
GROUP BY B.playerID
;
```

But what happens if the data streams contain the events of multiple rounds? 

```
Boccino = {round = 1}

t=t.plus(10 seconds)

Boccia = {playerID = 1, number=1, distance=2, status = "thrown"}

t=t.plus(10 seconds)

Boccia = {playerID = 2, number=1, distance=3, status = "thrown"}

t=t.plus(10 seconds)

Boccia = {playerID = 1, number = 2, distance = 3, status = "thrown"}
Boccia = {playerID = 1, number = 1, distance = 1.5, status = "hit"}
Boccia = {playerID = 2, number = 1, distance = 5, status = "hit"}

t=t.plus(10 seconds)

Boccia = {playerID = 2, number=2, distance=0.5, status = "thrown"}
Boccia = {playerID = 1, number = 1, distance = 3.5, status = "hit"}


t=t.plus(10 seconds)
Boccia = {playerID = 1, number=3, distance=2, status = "thrown"}

t=t.plus(10 seconds)
Boccia = {playerID = 2, number=3, distance=5, status = "thrown"}

t=t.plus(10 seconds)
Boccia = {playerID = 1, number=4, distance=7, status = "thrown"}

t=t.plus(10 seconds)
Boccia = {playerID = 2, number=4, distance=8, status = "thrown"}

t=t.plus(10 seconds)

Boccino = {round = 2}

t=t.plus(10 seconds)

Boccia = {playerID = 1, number=1, distance=3, status = "thrown"}

t=t.plus(10 seconds)

//the stream goes on...

```

The clause `every b -> every B` matches an event _everytime_ we have an event Boccino followed by an event Boccia (thrown). Hence, the event Boccino(round=1) will also match the second round's event Boccia(playerID = 1). 

The solution to this problem can be modeled in the following way:

```  
@Name('Q1_new')
SELECT COUNT(*)
FROM pattern[
every b = Boccino() 
-> 
every B = Boccia(B.status="thrown")
and not b2 = Boccino()
];
```

```  
@Name('Q1bis_new')
SELECT B.playerID as playerID, COUNT(*)
FROM pattern[
every b = Boccino() 
-> 
(every B = Boccia(B.status="thrown")
and not b2 = Boccino())
]
GROUP BY B.playerID
;
```

### Assignment Q2

An alternative request for this type of problem can be:

> Q2) Determine the total number of Bocce that have been thrown since the beginning of the **round**  
> Q2-bis) Determine how many Bocce each player has thrown  
> Q2-extra) Determine the total number of Bocce that have been thrown since the beginning of the i-th **round**  

### Solution

The Q1 solution is not an option anymore because it counts the entire amount of Bocce that has been thrown since the start of the match.

We can then solve the problem in the following way:

```  
@Name('Q2')
SELECT b.round as round, COUNT(*)
FROM pattern[
every b = Boccino() 
-> 
every B = Boccia(B.status="thrown")
and not b2 = Boccino()
]
GROUP BY b.round;
```

Try to solve Q2-Bis by yourself... :-)

Moreover, we can answer to the question Q2-extra considering, e.g, i=2, using the [HAVING clause](http://esper.espertech.com/release-8.9.0/reference-esper/html_single/#epl-grouping-having):

```
@Name('Q2-extra')
SELECT b.round as round, COUNT(*)
FROM pattern[
every b = Boccino() 
-> 
every B = Boccia(B.status="thrown")
and not b2 = Boccino()
]
GROUP BY b.round
HAVING b.round = 2;
```


### Assignment Q3
> Q3-easy) State the average distance from the Boccino for the last three Bocce  
> Q3) State the average distance from the Boccino for the last three  _thrown_ Bocce *per round*  


### Solution

```
@Name('Q3-easy')
SELECT AVG(distance)
FROM Boccia.win:length(3);
```
**Note**: Since the text does not specify "in the current round", the above is the correct solution. An alternative rational solution could have been:

```
create schema ThrownBoccia(
    playerID int,
    number int,
    distance double,
    round int
);

@Name('Q3_support')
INSERT INTO ThrownBoccia
SELECT B.playerID as playerID, B.number as number, B.distance as distance, b.round as round
FROM pattern[
    every b = Boccino()
    ->
    every B = Boccia()
    and not b2 = Boccino
]
WHERE B.status="thrown"; 

@Name('Q3')
SELECT round, AVG(distance)
FROM ThrownBoccia.win:length(3)
GROUP BY round
```

### Assignment Q4 (too tricky for an exam ... won't ask)

> Q4) Identify the player leading the game, i.e., the player whose Boccia is closest to the Boccino

### Solution

In order to meet this requirement, we need to associate a time stamp with the events, as the actual position of the Bocce is that given by the last event generated for the individual Boccia. All events in the game window must therefore be taken into account:

```  
create schema Boccia(
playerID int,
number int,
distance double,
status string,
timestamp int
);

create schema Boccino(
    round int,
    timestamp int
);

```

```
Boccino = {round = 1, timestamp = 0}

t=t.plus(10 seconds)

Boccia = {playerID = 1, number=1, distance=2, status = "thrown", timestamp = 10}

t=t.plus(10 seconds)

Boccia = {playerID = 2, number=1, distance=3, status = "thrown", timestamp = 20}

t=t.plus(10 seconds)

Boccia = {playerID = 1, number = 2, distance = 3, status = "thrown", timestamp = 30}
Boccia = {playerID = 1, number = 1, distance = 1.5, status = "hit", timestamp = 30}
Boccia = {playerID = 2, number = 1, distance = 5, status = "hit", timestamp = 30}

t=t.plus(10 seconds)

Boccia = {playerID = 2, number=2, distance=0.5, status = "thrown", timestamp = 40}
Boccia = {playerID = 1, number = 1, distance = 3.5, status = "hit", timestamp = 40}


t=t.plus(10 seconds)
Boccia = {playerID = 1, number=3, distance=2, status = "thrown", timestamp = 50}

t=t.plus(10 seconds)
Boccia = {playerID = 2, number=3, distance=5, status = "thrown", timestamp = 60}
Boccia = {playerID = 2, number = 1, distance = 1, status = "hit", timestamp = 60}


t=t.plus(10 seconds)
Boccia = {playerID = 1, number=4, distance=7, status = "thrown", timestamp = 70}

t=t.plus(10 seconds)
Boccia = {playerID = 2, number=4, distance=4, status = "thrown", timestamp = 80}
Boccia = {playerID = 1, number = 3, distance = 0.5, status = "hit", timestamp = 80}


t=t.plus(10 seconds)

Boccino = {round = 2, timestamp = 90}

t=t.plus(10 seconds)

Boccia = {playerID = 1, number=1, distance=3, status = "thrown", timestamp = 100}

t=t.plus(10 seconds)

```

Under the *unrealistic* assumption of a Boccia thrown every 10 seconds (thus, 80 seconds per round), we can verify which boccia is closest to the Boccino with the following query:

```
create schema FinalPos(
    playerID int,
    number int,
    distance double,
    timestamp int
);

@Name('Q4support')
INSERT INTO FinalPos
SELECT playerID, number, distance, timestamp
FROM Boccia.win:time_batch(80 seconds)
GROUP BY playerID, number
HAVING timestamp = max(timestamp)
ORDER BY playerID, number // just for result readability
;

@Name('Q4')
SELECT playerID, number, distance
FROM FinalPos.win:length_batch(8) 
HAVING distance = min(distance)
;
```
