# An example of an Exam question solved in EPL (using also context)

## Introductions

Suppose you want to monitor a group of robots used for picking and placing goods in an Industry 4.0 storehouse with a stream processing engine. _Along the normal operating cycle_, each robotic arm sends events reporting its status: Each robotic arm sends events reporting its status: 

* ready to pick a good, 
* good grasped, 
* moving a good, 
* placing a good, 
* moving without any goods. 

Several Force-Sensing Resistors measure the stress levels of the robotic arm. The robot is safely operating if the stress level is between 0 and 6. A controller should raise a warning if it is between 7 and 8. A controller should stop the robot if it is above 9.

## Questions & answers

### Q1

Propose how to model the streaming data generated by the robotic arms.

#### Some thinking

There are two forces: the **reality** and the **pragmatism**

The **reality** pushes for the most detailed model. Notably, the text above may imply that the Force-Sensing Resistors are independent sensors that send their own events separately from the arms. So one may be tempted to propose the following modeling.

```
create schema RoboticArm(id int, status string); 
create schema ForceSensingResistors(idArm string, stressLvl int)
```

The **pragmatism**, on the contrary, pushes for the minimum model that allows the continuous process of the data so to satisfy the needs presented in the following point (from Q2 to Q5). If you read them, you may understand that they are possible also with a much simpler model:

```
create schema RoboticArm( id string, status string, stressLevel int );
```

The rest of the proposed solution **follow**s **the pragmatic approach**.

#### Best practices

As a best practice, I recommend **writing down a portion of the stream** modeled according to your design choice.

For instance:

```
RoboticArm={id="1", status="ready", stressLevel=0} 
t=t.plus(1 seconds) 
RoboticArm={id="1", status="goodGrasped", stressLevel=1} 
t=t.plus(1 seconds) 
RoboticArm={id="1", status="movingGood", stressLevel=7} 
RoboticArm={id="2", status="ready", stressLevel=0} 
t=t.plus(1 seconds) 
RoboticArm={id="2", status="goodGrasped", stressLevel=5} 
t=t.plus(1 seconds) 
RoboticArm={id="2", status="movingGood", stressLevel=9} 
t=t.plus(5 seconds) 
RoboticArm={id="2", status="placingGood", stressLevel=3} 
RoboticArm={id="1", status="placingGood", stressLevel=3} 
t=t.plus(4 seconds) 
RoboticArm={id="1", status="moving", stressLevel=2} 
RoboticArm={id="2", status="moving", stressLevel=1} 
t=t.plus(3 seconds) 
RoboticArm={id="1", status="ready", stressLevel=0} 
RoboticArm={id="2", status="ready", stressLevel=0} 
t=t.plus(1 seconds)
RoboticArm={id="1", status="ready", stressLevel=0} 
t=t.plus(1 seconds) 
RoboticArm={id="1", status="goodGrasped", stressLevel=1} 
t=t.plus(1 seconds) 
RoboticArm={id="1", status="movingGood", stressLevel=7} 
RoboticArm={id="2", status="ready", stressLevel=0} 
t=t.plus(1 seconds) 
RoboticArm={id="2", status="goodGrasped", stressLevel=5} 
t=t.plus(1 seconds) 
RoboticArm={id="2", status="movingGood", stressLevel=9} 
t=t.plus(5 seconds) 
RoboticArm={id="2", status="placingGood", stressLevel=3} 
RoboticArm={id="1", status="placingGood", stressLevel=3} 
t=t.plus(4 seconds) 
RoboticArm={id="1", status="moving", stressLevel=2} 
RoboticArm={id="2", status="moving", stressLevel=1} 
t=t.plus(3 seconds) 
RoboticArm={id="1", status="ready", stressLevel=0} 
RoboticArm={id="2", status="ready", stressLevel=0} 
t=t.plus(1 seconds)
```

Another best practice is always to **state your assumptions**:

* The arm sends an event only when its status changes.
* The status can only appear in the order listed in the text above.
* If an arm stops due to a fault, it stops sending events.
* When an arm restarts after a fault, it is always in the status ready.
* The stress level in each event is the maximum the arm experienced between the reported status and the previous one (for coherence with question Q2).

### Q2 

Declare a continuous query that emits the maximum stress for each arm _for each cycle_.

#### Solution

```
create context cycle
partition by id from RoboticArm
initiated by RoboticArm(status="ready")
terminated by RoboticArm(status="ready")

```

```
@Name("Q2") 
context cycle
SELECT id, max(stressLevel) 
FROM RoboticArm;
```

### Q3 

Declare a continuous query that emits the average stress level between a pick (status==goodGrasped) and a place (status==placingGood). 

#### Solution

```
@Name("Q3") 
context cycle
SELECT id, avg(stressLevel) 
FROM RoboticArm(status in ("goodGrasped","movingGood","placingGood"))
output last every 3 events;
```

### Q4

Declare a continuous query that returns the robotic arms that, 

* in less than 10 second,
* picked a good while safely operating,
* moved it while the controller was raising a warning, and
* placed it while safely operating again.

#### Solution

```
@Name("Q4") 
context cycle
insert into warning
SELECT a.id 
FROM pattern [ 
	every	a=RoboticArm(status="goodGrasped", stressLevel < 7) ->
			(
				b=RoboticArm(status="movingGood", stressLevel > 6 and stressLevel < 9) ->
				c=RoboticArm(status="placingGood", stressLevel < 7) 
			)
			where timer:within(10 seconds)
		] ;
```

### Q5

Declare a continuous query that monitors the results of the previous one (i.e., E4) and counts how many times each robotic arm is present in the stream over a window of 10 seconds updating the counting every 2 seconds.

#### Solution

```
@Name("Q5") 
select arm, count(*)
from warning.win:time(10 sec)
group by arm
output last every 2 sec;
```
