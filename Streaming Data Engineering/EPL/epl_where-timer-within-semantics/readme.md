# On operator precedence in EPL
## The case of followed by (->) and where timer:within

Q4 query in [epl_robotic-arm](https://github.com/Streaming-Data-Analytics/Courseware/tree/main/Streaming%20Data%20Engineering/EPL/epl_robotic-arm) raised some doubts on the correct application of the where timer:within operator in comparison to the followed by(->) operator.
In particular there were challenges in determining which operator where timer:within would operate on.
According to the [Esper Reference pattern-op-precedence](https://esper.espertech.com/release-9.0.0/reference-esper/html_single/#pattern-op-precedence) where timer:within has an higher precedence than followed by(->).
To address these uncertainties the following examples will illustrate solutions to the possible
cases we encountered using the same schema of epl_robotic-arm.

### Schema

```
create schema RoboticArm( id string, status string, stressLevel int );
```

### Data stream

```
RoboticArm={id="1", status="ready", stressLevel=0} 
t=t.plus(1 seconds) 
RoboticArm={id="1", status="goodGrasped", stressLevel=1} 
t=t.plus(1 seconds) 
RoboticArm={id="1", status="movingGood", stressLevel=7} 
t=t.plus(1 seconds)  
RoboticArm={id="1", status="placingGood", stressLevel=3} 
t=t.plus(1 seconds) 
RoboticArm={id="1", status="moving", stressLevel=3} 
t=t.plus(1 seconds) 
RoboticArm={id="1", status="ready", stressLevel=0}  
t=t.plus(1 seconds)
RoboticArm={id="1", status="ready", stressLevel=0} 
t=t.plus(1 seconds) 
RoboticArm={id="1", status="goodGrasped", stressLevel=1} 
t=t.plus(10 seconds) 
RoboticArm={id="1", status="movingGood", stressLevel=7}  
t=t.plus(6 seconds)  
RoboticArm={id="1", status="placingGood", stressLevel=3} 
t=t.plus(1 seconds) 
RoboticArm={id="1", status="moving", stressLevel=2}  
t=t.plus(1 seconds) 
RoboticArm={id="1", status="ready", stressLevel=0}  
t=t.plus(1 seconds)
RoboticArm={id="1", status="ready", stressLevel=0} 
t=t.plus(1 seconds) 
RoboticArm={id="1", status="goodGrasped", stressLevel=1} 
t=t.plus(10 seconds) 
RoboticArm={id="1", status="movingGood", stressLevel=7}  
t=t.plus(10 seconds)  
RoboticArm={id="1", status="placingGood", stressLevel=3} 
t=t.plus(1 seconds) 
RoboticArm={id="1", status="moving", stressLevel=2}  
t=t.plus(1 seconds) 
RoboticArm={id="1", status="ready", stressLevel=0}  
t=t.plus(1 seconds)

```
### Queries

#### E1

goodGrasp followed by movingGood followed by placingGood. 
This query is used to show the followed by(->) behaviour without the use of where timer:within

```
@Name("E1") 
SELECT a.id 
FROM pattern [ 
	every	a=RoboticArm(status="goodGrasped", stressLevel < 7) ->
		b=RoboticArm(id = a.id, status="movingGood", stressLevel > 6 and stressLevel < 9) ->
		c=RoboticArm(id = a.id, status="placingGood", stressLevel < 7) 	
		] ;
```

results:

```
 At: 2001-01-01 08:00:03.000

    Insert
        E1-output={a.id='1'}

At: 2001-01-01 08:00:23.000

    Insert
        E1-output={a.id='1'}

At: 2001-01-01 08:00:47.000

    Insert
        E1-output={a.id='1'}

```

#### E2

goodGrasped followed by movingGood followed by placingGood, all within 10 s

```
@Name("E2") 
SELECT a.id 
FROM pattern [ 
	every	a=RoboticArm(status="goodGrasped", stressLevel < 7) ->
			(
				b=RoboticArm(id = a.id, status="movingGood", stressLevel > 6 and stressLevel < 9) ->
				c=RoboticArm(id = a.id, status="placingGood", stressLevel < 7) 
			)
			where timer:within(10 seconds)
		] ;
```

returns

```
At: 2001-01-01 08:00:03.000

    Insert
        E2-output={a.id='1'}

```

#### E3

goodGrasped followed by movingGood followed by placingGood, placingGood arrives within 10 s from movingGood

```
@Name("E3") 
SELECT a.id 
FROM pattern [ 
	every	a=RoboticArm(status="goodGrasped", stressLevel < 7) ->
			(
				b=RoboticArm(id = a.id, status="movingGood", stressLevel > 6 and stressLevel < 9) ->
				c=RoboticArm(id = a.id, status="placingGood", stressLevel < 7)
				where timer:within(10 seconds) 
			)	
		] ;
```

returns:

```
 At: 2001-01-01 08:00:03.000

    Insert
        E3-output={a.id='1'}

At: 2001-01-01 08:00:23.000

    Insert
        E3-output={a.id='1'}

```

#### E3bis

The E3 query can also be written without the parenthesis around event b and c as the where timer:within operator 
is applied to the first followed by operator before its use.
 
```
@Name("E3bis") 
SELECT a.id 
FROM pattern [ 
	every	a=RoboticArm(status="goodGrasped", stressLevel < 7) ->
		b=RoboticArm(id = a.id, status="movingGood", stressLevel > 6 and stressLevel < 9) ->
		c=RoboticArm(id = a.id, status="placingGood", stressLevel < 7)
		where timer:within(10 seconds) 
		] ;
```

results:

```
 At: 2001-01-01 08:00:03.000

    Insert
        E3bis-output={a.id='1'}

At: 2001-01-01 08:00:23.000

    Insert
        E3bis-output={a.id='1'}
```


#### E4

googGrasper followed by movingGood followed by placingGood all within 10 s from the start

```
@Name("E4") 
SELECT a.id 
FROM pattern [ 
	every	( 
			a=RoboticArm(status="goodGrasped", stressLevel < 7) ->			
			b=RoboticArm(id = a.id, status="movingGood", stressLevel > 6 and stressLevel < 9) ->
			c=RoboticArm(id = a.id, status="placingGood", stressLevel < 7)
		)
		where timer:within(10 seconds) 		
		] ;
```

Results:

```
At: 2001-01-01 08:00:03.000

    Insert
        E4-output={a.id='1'}

```

