# Tomato pick EPL exam
## Resources

- [espertech](https://www.espertech.com/)
- [EPL documentation](http://esper.espertech.com/release-8.7.0/reference-esper/html/index.html)
- [EPL playground](http://esper-epl-tryout.appspot.com/epltryout/mainform.html)

## The problem

> Suppose you want to monitor a swarm of autonomous drones that pick tomatoes in a field with a stream processing engine. 
A data stream includes the information about the trees to pick tomatoes from. The most important ones are the id of the tree, its GPS position, the kind of tomatoes it produces, and the time interval in which the drones can pick the tomatoes from it. Another stream tracks each drone. It contains an event every time it picks a tomato. Each event reports the id of the drone, the id of the tree it is picking tomatoes from, and its GPS position.

> Tell every 20 seconds how many tomatoes the drones picked in the last 5 minutes grouped by their kind.

### Modeling
> Formalize in EPL the schema of the two streams.

Reading the description carefully it is possible to derive the following schemas:


```  
create schema TreeToPickTomatoesFrom(
treeID int,
type string
);

create schema DronePicking(
droneID int,
servicedTreeID int
);
```

An instance of the **TreeToPickTomatoesFrom** stream translates to a command given to the drones to pick tomatoes from it, whereas an instance of the **DronePicking** stream is issued once a certain drone has picked one tomato.

Some of the attributes described in the assignment are not necessary (position, time interval) in order to solve it, hence they are not modeled.
For now these attributes will suffice. We will modify them in the future.

### Assumptions
Before delving into the problem it is better to define some assumptions to better model the data stream and the queries:
- multiple drones can pick tomatoes after a single issue of a _TreeToPickTomatoesFrom_ instance
- multiple drones can pick tomatoes from the same tree
- the time constraints of the _TreeToPickTomatoes_ are intrinsically respected by the system (we will come back to this later)

### Data stream generation
In order to test the queries that will be later presented we will use the following data stream. It is suggested to modify it using different configurations to test wether your queries will work in different settings.

```  
TreeToPickTomatoesFrom = {treeID = 1, type = 'cherry'}


t=t.plus(20 seconds)


DronePicking = {droneID = 1, servicedTreeID = 1}

TreeToPickTomatoesFrom = {treeID = 2, type = 'yellow'}


t=t.plus(20 seconds)


DronePicking = {droneID = 2, servicedTreeID = 2}


t = t.plus(20 seconds)


DronePicking = {droneID = 1, servicedTreeID = 1}


t=t.plus(20 seconds) 


DronePicking = {droneID = 1, servicedTreeID = 1}

DronePicking = {droneID = 2, servicedTreeID = 2}


t=t.plus(20 seconds)


DronePicking = {droneID = 2, servicedTreeID = 2}


t=t.plus(20 seconds)
```

### Assignment

> Tell every 20 seconds how many tomatoes the drones picked in the last 5 minutes grouped by their kind.

A single query to tackle this problem is not enough: we first need to use a "support" stream (in this case _requestFullFilled_) that "stores" the type of the tomato that the drone just picked.

#### Solution
```  
@Name('QInsert')
INSERT INTO requestFullfilled
SELECT b.droneID as dID, a.type as type
FROM pattern[
every a = TreeToPickTomatoesFrom() 
-> 
every b = DronePicking(b.servicedTreeID = a.treeID)
];
```
This solution selects the droneID (not strictly necessary) and the type of the tomato picked by a drone which respects the pattern
> every a = TreeToPickTomatoesFrom() -> every b = DronePicking(b.servicedTreeID = a.treeID)

The two every clauses are needed since there may be multiple instances of _TreeToPickTomatoesFrom_ for different trees and we need to track ALL of the drones picks for each one of them. It is suggested to test what happens if a different pattern is chosen.

Finally, we can solve the given problem with a simple query on the newly generated class:
```  
@Name('QFinal')
SELECT type, count(*)
FROM requestFullfilled.win:time(5 minutes)
GROUP BY type
output all every 20 seconds;
```
A 5 minutes-long hopping window is implemented.

Because of the aggregating function count(), the group by clause is used (as in common SQL). 

The output **all** clause is used to show all of the elements of the counting table. Using different clauses will provide more limited results.

### Is this enough?

Let's try to change the data generation schema, using the following one: 

```  
TreeToPickTomatoesFrom = {treeID = 1 , type = 'cherry'}


t=t.plus(20 seconds)


DronePicking = {droneID = 1, servicedTreeID = 1}

TreeToPickTomatoesFrom = {treeID = 2 , type = 'yellow'}


t=t.plus(20 seconds)


DronePicking = {droneID = 2, servicedTreeID = 2}


t = t.plus(20 seconds)


DronePicking = {droneID = 1, servicedTreeID = 1}


t=t.plus(20 seconds) 


TreeToPickTomatoesFrom = {treeID = 1 , type = 'cherry'}

DronePicking = {droneID = 1, servicedTreeID = 1}

DronePicking = {droneID = 2, servicedTreeID = 2}


t=t.plus(5 minutes)


DronePicking = {droneID = 2, servicedTreeID = 2}


t=t.plus(20 seconds)
```

With this data stream multiple _TreeToPickTomatoesFrom_ instances for the same trees are issued in different points in time.

When **QInsert** is executed, the two every clauses in the pattern will insert multiple times the same object, since it will respect the pattern for both the _TreeToPickTomatoesFrom_ instances.

We can modify the query in the following way:
### New solution
```  
@Name('QInsertNEW')
INSERT INTO requestFullfilled
SELECT b.droneID as dID, a.type as type
FROM pattern[
every a = TreeToPickTomatoesFrom() 
-> 
every b = DronePicking(b.servicedTreeID = a.treeID)
and not c = TreeToPickTomatoesFrom(c.treeID = a.treeID)
];
```
By using the not clause the pattern will stop matching once a new istance of _TreeToPickTomatoesFrom_ is issued with a treeID of a request already present in the past.


## Bonus: respecting time constraints
Before writing the stream generation we made some assumptions, one of which was 
> - the time constraints of the _TreeToPickTomatoesFrom_ are intrinsically respected by the system

Let's say that we want to know the count of tomatoes picked per type only in the **time constraints** set by the _TreeToPickTomatoesFrom_.

The modeling of the class itself needs to change: we need to introduce a new attribute to the DronePicking schema represented by the timestamp, the time at which such tomato was picked. 
We will consider a working day as divided into 80 time slices, the attributes to specify the drone timestamp and the beginning and the end of the pickable tomato time will then be represented by an integer number between 1 and 80.

```  
create schema TreeToPickTomatoesFrom(
treeID int,
type string,
pick_start int,
pick_end int
);

create schema DronePicking(
droneID int,
servicedTreeID int,
timestamp int
);
```  
A modification to the data stream is also required to fit the new model.

```  
TreeToPickTomatoesFrom = {treeID = 1, type = 'cherry', pick_start = 1, pick_end = 40}


t=t.plus(20 seconds)


DronePicking = {droneID = 1, servicedTreeID = 1, timestamp = 20}

TreeToPickTomatoesFrom = {treeID = 2, type = 'yellow', pick_start = 3, pick_end = 70}


t=t.plus(20 seconds)


DronePicking = {droneID = 2, servicedTreeID = 2, timestamp = 30}


t = t.plus(20 seconds)


DronePicking = {droneID = 1, servicedTreeID = 1, timestamp = 41} // out of time pick


t=t.plus(20 seconds) 


TreeToPickTomatoesFrom = {treeID = 1, type = 'cherry', pick_start = 50, pick_end = 80}

DronePicking = {droneID = 1, servicedTreeID = 1, timestamp = 51}

t=t.plus(40 seconds)

DronePicking = {droneID = 2, servicedTreeID = 2, timestamp = 71} // out of time pick


t=t.plus(5 minutes)


DronePicking = {droneID = 2, servicedTreeID = 2, timestamp = 80} // out of time pick


t=t.plus(20 seconds)
```  
As you can see some of the tomatoes picked should not be counted having timestamps superior to the pick_end of the _TreeToPickTomatoesFrom_ instances.

The new query to fit such constraints can be written as follows:
```  
@Name('QInsertTC')
INSERT INTO requestFullfilled
SELECT b.droneID as dID, a.type as type
FROM pattern[
every a = TreeToPickTomatoesFrom() 
-> 
every b = DronePicking(b.servicedTreeID = a.treeID, b.timestamp < a.pick_end, b.timestamp > a.pick_start)
and not c = TreeToPickTomatoesFrom(c.treeID = a.treeID)
];
```  

## Another exam problem
>Tell every minute how many drones in the last 5 minutes are late in picking fruits from the trees. A drone is late, if it picks a fruit from a tree it is no longer supposed to pick the fruit from, i.e., the time it picks a fruit is not in the interval requested in the stream of commands for such a tree.

As seen before, we must create a query that updates a custom stream ( _lateTomatoes_ ) whenever a drone picks a tomatoes outside the boundaries set in the latest _TreeToPickTomatoesFrom_ issue.

In order to do that, it is possible to modify the "QInsertTC" query pattern in the following way:

```  
@Name('QLateInsert')
INSERT INTO lateTomatoes
SELECT b.droneID as dID, b.timestamp as TS
FROM pattern[
every a = TreeToPickTomatoesFrom() 
-> 
every b = DronePicking(b.servicedTreeID = a.treeID, b.timestamp > a.pick_end)
and not c = TreeToPickTomatoesFrom(c.treeID = a.treeID)
];
``` 
In this case, selecting the type is no longer necessary.

Lastly, a count of the issues of the stream is required. To do so we can use the following query:


```  
@Name('QFinalLT')
SELECT count(*)
FROM lateTomatoes.win:time(5 minutes)
output last every 1 minutes;
```

The _Group By_ clause is no longer necessary, since the assignment does not require to count the late picks for each drone, but the count of total late picks. 
For this reason the output will be a single number, hence the switch from "all" to "last" as the output clause. 


It is suggested to try out multiple queries at the same time and to check their results using the _Output Per Statement_ function of the EPL online tool to check the difference between these solutions, and the effects of the modifications.
