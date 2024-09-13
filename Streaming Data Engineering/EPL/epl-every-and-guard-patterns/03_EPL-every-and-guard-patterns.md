## every clause and the pattern guards

### preliminaries

the DDL EPL statements

```
create schema A (
n int
);

create schema B (
n int
);

create schema C (
n int
);
```

the stream to use for testing the queries

```
A={n=1}
t=t.plus(1 seconds)
B={n=1}
t=t.plus(2 seconds)
B={n=2}
t=t.plus(1 seconds)
A={n=2}
t=t.plus(1 seconds)
A={n=3}
t=t.plus(1 seconds)
B={n=3}
t=t.plus(1 seconds)
A={n=4}
t=t.plus(1 seconds)
B={n=4}
```

### the EPL queries

#### Q.9

> the basics

match the first A

```
@Name('Q.9')
select x.n
from pattern [ x=A];
```

#### Q.10

> we now introduce **every clause**

match every A

```
@Name('Q.10')
select x.n
from pattern [ every x=A];
```

which indeed is a more extended version for 

```
@Name('Q.10bis')
select n
from A;
```

NOTE: this explains the continuous semantics we introduce in **Q0**

#### Q.11

match every ( A followed by B ) 

Note, the content of the brackets is event A followed by B.

```
@Name('Q.11')
select x.n, y.n
from pattern [ every (x=A -> y=B)];
```

#### Q.12

match (every A) followed by a B

Note where we want to match every A followed by a B

```
@Name('Q.12')
select x.n, y.n
from pattern [ (every x=A ) -> y=B];
```

NOTE: the brackets do not matter because of the order of the operators

```
@Name('Q.12bis')
select x.n, y.n
from pattern [ every x=A -> y=B];
```

#### Q.13

match the first A followed by every B

```
@Name('Q.13')
select x.n, y.n
from pattern [  x=A -> every y=B];
```

#### Q.14

match every pair of A followed by a B

```
@Name('Q.14')
select x.n, y.n
from pattern [  every x=A -> every y=B];
```

NOTE: this is a temporal cross join between A and B with the "only" constraint that Bs have to follow As.

EPL tries to fight the torrent effect (`A->B` matches only the first A and the following B). If you want to be flooded, you have to ask for (`every A -> every B`)

#### Q.15

> we now introduce **pattern guards**

match (every A) followed by a B **within 2 seconds**

```
@Name('Q.15')
select x.n, y.n
from pattern [ (every x=A) -> y=B where timer:within(2 sec)];
```

and as above, the brackets do not matter because of the order of the operators

```
@Name('Q.15')
select x.n, y.n
from pattern [ every x=A -> y=B where timer:within(2 sec)];
```

#### Q.16

match (every A) followed by (a B **and not** another A)

```
@Name('Q16')
select x.n, y.n, z.n
from pattern [ every x=A -> (y=B and not z=A)];
```

### Lab 1

given the following stream

```
A={n=1} 
t=t.plus(1 seconds) 
C={n=1} 
t=t.plus(1 seconds) 
B={n=1} 
t=t.plus(1 seconds) 
B={n=2} 
t=t.plus(1 seconds) 
A={n=2} 
t=t.plus(1 seconds) 
A={n=3} 
t=t.plus(1 seconds) 
B={n=3} 
A={n=4} 
t=t.plus(4 seconds) 
B={n=4}
t=t.plus(1 seconds)
```

#### Q.Lab1

write an EPL statement that matches (every A) followed by ((a B and not a C) within 3 seconds)

```
@Name('Q.Lab1')
select x.n, y.n, z.n
from pattern [ every x=A -> ((y=B and not z=C) where timer:within(3 sec))];
```

### Lab 2

given the following event type

```
create schema StockTick( symbol string, price double );
```

and stream

```
StockTick={symbol='GE', price=20}
StockTick={symbol='IBM', price=105}

t=t.plus(2 seconds)

StockTick={symbol='YHOO', price=65}
StockTick={symbol='IBM', price=99}

t=t.plus(2 seconds)

StockTick={symbol='YHOO', price=70}
StockTick={symbol='IBM', price=104}

t=t.plus(5 seconds)

StockTick={symbol='GE', price=22}
StockTick={symbol='IBM', price=98}

t=t.plus(2 seconds)
```

#### Q.Lab2.1

report every 2 seconds the min, average, and max price of each stock tick grouped by a symbol in the last 6 seconds

```
@Name('Q1.Lab2.1') 
select symbol, min(price), avg(price), max(price) 
from StockTick.win:time(6 seconds) 
group by symbol 
output last every 2 seconds;
```

NOTE: there are differences between `output last` and `output snapshot/all`. As a rule of thumb, use `last` when you assume that those downstream are always listening and do not want to be bothered unless new information becomes available. Use `snapshot` or `all` when you think those downstream do not remember what you told the last time and prefer the upstream query to repeat the complete answer.

#### Q.Lab2.2

report when IBM's stock prices go from above 100 to below 100 in less than 5 seconds

```
@Name('Q.Lab2.2.every-last-price-above-followed-by-below')
select x.symbol AS stock, 
          x.price AS before, 
          y.price AS after
from pattern [
every 
x = StockTick(symbol='IBM', price > 100) 
-> ( y =  StockTick(symbol='IBM', price < 100) 
      where timer:within(5 seconds) 
) 
]
;
```

Notice that this solution (where we use a pattern of the type `every A -> B`) will also match if the data stream is the following.

```
StockTick={symbol='GE', price=20}
StockTick={symbol='IBM', price=105}

t=t.plus(3 seconds)

StockTick={symbol='YHOO', price=65}
StockTick={symbol='IBM', price=102}

t=t.plus(2 seconds)

StockTick={symbol='YHOO', price=70}
StockTick={symbol='IBM', price=99}

t=t.plus(1 seconds)

StockTick={symbol='GE', price=22}
StockTick={symbol='IBM', price=98}

t=t.plus(2 seconds)
```

while this other version (where we use a pattern of the type `every (A -> B)`) would not

```
@Name('Q.Lab2.2.every-pair')
select x.symbol AS stock, 
          x.price AS before, 
          y.price AS after
from pattern [
every (
x = StockTick(symbol='IBM', price > 100) 
-> ( y =  StockTick(symbol='IBM', price < 100) 
      where timer:within(5 seconds) )
) 
]
;
```
