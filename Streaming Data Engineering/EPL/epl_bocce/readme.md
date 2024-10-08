# Bocce EPL problem
## Resources

- [espertech](https://www.espertech.com/)
- [EPL documentation](http://esper.espertech.com/release-9.0.0/reference-esper/html_single/)
- [EPL playground](http://esper-epl-tryout.appspot.com/epltryout/mainform.html)

## The problem

> We want to monitor a Bocce game for two players. Bocce is a famous Italian game played with eight metal balls (called bocce, singular boccia) on a smooth, prepared court. The game also requires a smaller target ball, known as the boccino. The player who starts the game throws the boccino and one of his boccia, aiming to get it as close to the boccino as possible. The opposing player then tries to throw his boccia closer to the boccino or knock the opponent's boccia away.

> In the Bocce game, once the players have thrown all bocce, the round ends, and the scoring is determined. The player with the boccia closest to the boccino earns points. He receives one point for each boccia closer to the boccino than his opponent's closest boccia to the boccino.

> Suppose a camera mounted above the court can detect when a round starts (i.e., the boccino is the only ball on the court). Morevoer, whenever a player throws a boccia, it waits for all the bocce to stop (a boccia can hit another one a more than one boccia moves), and then, for each moved boccia, it tells how far it is from the boccino.

<img width="962" src="https://github.com/emanueledellavalle/streaming-data-analytics/assets/5645019/0c54d35b-7d94-4d8b-95f2-d04cf6973ad2">
<a href="https://vimeo.com/873244267">BALINO - Bocce in circolo</a> from <a href="https://vimeo.com/user198205737">benedetta bellucci</a> on <a href="https://vimeo.com">Vimeo</a>.</p>

## Modeling

### Assumptions
Before delving into the solution, let's define some assumptions to model the data stream and the queries better:
- There are only two players who play a single match.
- The streams start at the beginning of the match with the events that announce the two players.
- The players know the game and play along its rules.

Reading the description, we can derive the following event schemas:

```  
create schema Player(
    id int
);

create schema Boccino(
    round int
);

create schema Boccia(
    playerID int,
    number int,
    distance double, 
    status string
);
```

Two events are inserted into **Player** stream when a new round starts.

An event is inserted into **Boccino** stream when a new round starts.

An event is inserted into the **Boccia** stream once a certain Boccia stops moving. `thrown` is the default status. `hit` is the status of a Boccia moved by another one that hit it.


## Example of Data stream

In order to test the queries that will be later presented, let's use the following data stream. It represents the first 3 rounds of a match.

``` 
Player = {id=1}
Player = {id=2}

Boccino = {round = 1}

t = t.plus(10 seconds)

Boccia = {playerID = 1, number = 1, distance = 2.0, status = "thrown"}

t = t.plus(15 seconds)

Boccia = {playerID = 2, number = 1, distance = 3.5, status = "thrown"}

t = t.plus(10 seconds)

Boccia = {playerID = 2, number = 2, distance = 2.8, status = "thrown"}

t = t.plus(15 seconds)

Boccia = {playerID = 2, number = 3, distance = 2.1, status = "thrown"}

t = t.plus(10 seconds)

Boccia = {playerID = 2, number = 4, distance = 1.5, status = "thrown"}

t = t.plus(15 seconds)

Boccia = {playerID = 1, number = 2, distance = 1.2, status = "thrown"}

t = t.plus(10 seconds)

Boccia = {playerID = 1, number = 3, distance = 1.3, status = "thrown"}

t = t.plus(15 seconds)

Boccia = {playerID = 1, number = 4, distance = 1.0, status = "thrown"}

t = t.plus(10 seconds)

Boccino = {round = 2}

t = t.plus(10 seconds)

Boccia = {playerID = 2, number = 1, distance = 2.5, status = "thrown"}

t = t.plus(15 seconds)

Boccia = {playerID = 1, number = 1, distance = 2.0, status = "thrown"}

t = t.plus(10 seconds)

Boccia = {playerID = 2, number = 2, distance = 1.8, status = "thrown"}

t = t.plus(15 seconds)

Boccia = {playerID = 1, number = 2, distance = 1.7, status = "thrown"}

t = t.plus(10 seconds)

Boccia = {playerID = 2, number = 3, distance = 0.7, status = "thrown"}

t = t.plus(15 seconds)

Boccia = {playerID = 1, number = 3, distance = 0.9, status = "thrown"}

t = t.plus(10 seconds)

Boccia = {playerID = 1, number = 4, distance = 0.6, status = "thrown"}

t = t.plus(15 seconds)

Boccia = {playerID = 1, number = 4, distance = 5, status = "hit"}
Boccia = {playerID = 2, number = 4, distance = 4, status = "thrown"}

t = t.plus(15 seconds)

Boccino = {round = 3}

t = t.plus(12 seconds)

Boccia = {playerID = 1, number = 1, distance = 2.5, status = "thrown"}

t = t.plus(10 seconds)

Boccia = {playerID = 2, number = 1, distance = 3.0, status = "thrown"}

t = t.plus(14 seconds)

Boccia = {playerID = 2, number = 2, distance = 2.0, status = "thrown"}

t = t.plus(9 seconds)

Boccia = {playerID = 1, number = 2, distance = 1.5, status = "thrown"}

t = t.plus(11 seconds)

Boccia = {playerID = 1, number = 3, distance = 1.8, status = "hit"}  
Boccia = {playerID = 2, number = 3, distance = 2.2, status = "thrown"}

t = t.plus(15 seconds)

Boccia = {playerID = 2, number = 3, distance = 1.2, status = "thrown"}

t = t.plus(10 seconds)

Boccia = {playerID = 1, number = 4, distance = 0.8, status = "thrown"}

t = t.plus(13 seconds)

Boccia = {playerID = 1, number = 4, distance = 2.5, status = "hit"} 
Boccia = {playerID = 1, number = 1, distance = 1.5, status = "hit"}  
Boccia = {playerID = 2, number = 1, distance = 3.5, status = "hit"} 
Boccia = {playerID = 2, number = 4, distance = 1.0, status = "thrown"}

t = t.plus(15 seconds)

Boccino = {round=4}

```

## Create a context that delimits a round

A round starts when a player throws the Boccino and ends when the Boccino gets thrown again.

```
create context Round
    initiated by Boccino 
    terminated by Boccino;
```

## Identify the player who won the round

When the round ends, the player with the shortest distance between their Boccias and the Boccino wins the round.

```
@Name('RoundWinner')
context Round
insert into Winner
select playerID, number, distance 
from Boccia()#unique(playerID,number)
output snapshot when terminated
order by distance asc
limit 1
;
```

When the context `Round` ends, this query orders the last position of each Boccia (`Boccia()#unique(playerID,number)`) and takes the first row, i.e., the Boccia closest to the Boccino (assuming ties are not possible).

## Identify the player who lost the round

Assuming there are only two players, the looser is not the winner.

```
@Name('RoundLooser')
insert into Looser
select p.id as looser
from Winner#lastevent as w,
        Player#keepall as p
where w.playerID != p.id;
```

## Create a score event at the end of each round

At the end of each round, the winner receives one point for each of her balls that is closer to the Boccino than the nearest ball of the looser.

```
@Name('RoundWinnerWithScore')
insert into Score
select b.playerID as playerID, count(*) as roundScore
from Looser as l unidirectional inner join
        Boccia#unique(playerID,number) as b
where b.playerID != l.looser and
           b.distance < (select min(distance) from Boccia#unique(playerID,number) as b where b.playerID = l.looser)
group by b.playerID;
```

## Sum the score events for each player since the beginning of the stream

```
@Name('TotalRollingScore')
select playerID, sum(roundScore)
from Score
group by playerID
output all every 1 events;
```


### Acknowledgement

I kindly thank [Eugenio Varetti](https://www.linkedin.com/in/eugenio-varetti/), who first provided [a solution to this problem in EPL](https://github.com/emanueledellavalle/streaming-data-analytics/tree/main/codes/epl_bocce) as an optional project of the Streaming Data Analytics course in the academic year 2022/23.
