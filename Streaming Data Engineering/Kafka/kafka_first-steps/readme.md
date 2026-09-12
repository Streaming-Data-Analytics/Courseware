# Kafka, first steps

*by [Emanuele Della Valle](https://emanueledellavalle.org/) and
[Claude](https://claude.com/product/overview)*

## Introduction

Twenty-five minutes with **Kafka on its own** — no ksqlDB, no Spark. One topic, three
partitions, a producer and a handful of consumers, and the five facts the rest of the Kafka
lecture assumes you have already seen:

| | the fact | the slide it makes executable |
|---|---|---|
| 1 | a topic is a **set of partitions**, and the count is the maximum parallelism | *Reconciling the two views*, *A physical view of topic partition* |
| 2 | with no key the partition is **random per batch**, not round-robin per message — so a fast producer concentrates and a slow one spreads; with a key it is `hash(key) % n` | *Reconciling the two views* |
| 3 | a **consumer group** splits the partitions between its members, one reader each | *Topic partitioning invites distributed consumption*, *Consumer Group and scalability* |
| 4 | a group is a **cursor, not a queue**: reading does not consume | *Log retention* |
| 5 | the **encoding** is a factor in MB/s: the same event is 115 bytes as JSON and 18 as Avro | *Data/Message matters!* |

It exists because of a gap. The five ksqlDB modules of this course are excellent at what
they do, and what they do is **hide all of this behind SQL**. Without this module the first
time you would see a topic being created, a keyed message produced and a consumer group
formed is inside a Spark simulator, where it is scaffolding for something else — and by then
the quiz on partitions and keys has already been asked.

Every section asks you to **predict before you run**. The predictions are the point; the
outputs only settle them.

## Resources

* [Apache Kafka documentation](https://kafka.apache.org/documentation/)
* [Apache Avro documentation](https://avro.apache.org/docs/) — the schema language and the binary encoding
* [Confluent Schema Registry](https://docs.confluent.io/platform/current/schema-registry/index.html) — what this module deliberately does *not* use
* [The client used here: confluent-kafka-python](https://docs.confluent.io/kafka-clients/python/current/overview.html)
* [Where these topics are read at scale: the elevator fleet](../../Spark/sss_elevator-fleet/readme.md)

## 1. Set up

### make sure

* you have [docker](https://docs.docker.com/get-docker/) and docker compose (a single app on
  Windows and Mac; on Linux [install docker compose separately](https://docs.docker.com/compose/install/))
* you do not have any firewall forbidding you from reaching `localhost:8888`
* **no other module of this course is running.** `Spark/sss_elevator-fleet` uses the same
  ports; `docker-compose down` in its folder first

### start up the infrastructure

```
docker-compose up -d
```

The first time it downloads a couple of GB. **Don't do it in class.** It is the same two
images as `sss_elevator-fleet`, so if you have run that module the download is already done.

### you know you succeeded if

1. you can open [http://localhost:8888](http://localhost:8888)
2. entering the token `sda` you get a [jupyter lab](https://jupyterlab.readthedocs.io/en/stable/)
   with a folder named `work`
3. `docker-compose ps` shows two services, `kafka` and `notebook`, both up

## 2. Run it

One notebook, `notebooks/1_kafka_first_steps.ipynb`, top to bottom. There is no alternation
and no second notebook: everything happens in one place, which is the difference between this
module and the Spark ones.

| section | what you will do | stop and predict |
|---|---|---|
| *A topic is a set of partitions* | create `elevator-doors` with 3 partitions, and read the metadata back | — |
| *With no key, the client spreads them itself* | produce 9 messages fast, then 9 messages 30 ms apart, and count the partition switches in each | how will nine spread over three? and what changes with a pause? |
| *With a key, the partition is a function of the key* | produce 3 messages each for three units, keyed by `unitId` | do three keys give three partitions? |
| *One consumer in a group reads every partition* | one consumer in group `dashboard` | how many of the 27 does it get? |
| *Two consumers in the same group split the partitions* | a second consumer joins and the group rebalances | how do 3 partitions divide by 2? and what about a 4th consumer? |
| *A group is a cursor, not a queue* | a brand-new group reads from `earliest` | how many messages does it see? |
| *The same event, in Avro* | encode one door event as JSON and as Avro, change the schema and watch it shrink again, then compare the batches of a thousand of each | the same event is 115 bytes as JSON — how small in Avro? |
| *Clean up* | delete the three topics | — |

The one thing that can look like a failure and is not: after the second consumer joins,
the group **rebalances**, and that takes a few seconds during which both consumers hold
nothing. The notebook polls both of them until it settles — a member that does not poll is a
member the broker does not consider present.

## 3. Stop

```
docker-compose down
```

## What to take away

**Two decisions, and you make both before a single message exists.** The **encoding** fixes the bytes per event, and the assignment of this lecture multiplies that by 150,000 units: a sixth of the payload is a different cluster, for the same information.

And **the partition count.** It caps the parallelism of every consumer group
that will ever read the topic; it is the unit inside which order is guaranteed and outside
which it is not; and because a key's partition is `hash(key) % n`, changing it later moves
keys and breaks the ordering they were bought for. You choose it before a single message
exists — which is why `Spark/sss_elevator-fleet` spends a section asking whether `unitId` is
the right key for a fleet of 150,000 units, and why the retail lecture spends its hour on
what happens when the key is not uniform.

## Acknowledgements

The module was designed for this course by [Emanuele Della Valle](https://emanueledellavalle.org/)
and [Claude](https://claude.com/product/overview). The elevator naming is the course's own
spine, and it carries through to lectures 9 and 10.

Claude's work on this course is sponsored by
[Quantia Consulting](https://www.quantiaconsulting.com/).
