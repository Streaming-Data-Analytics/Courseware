# Spark Structured Streaming - Handling Late Data and Watermarking

## 1. set up

### make sure

* you have [docker](https://docs.docker.com/get-docker/) and docker-compose (they are a single app in Windows and Mac. For Linux [install docker-compose separately](https://docs.docker.com/compose/install/))
* you do not have any firewall forbidding you from reaching `localhost:8888`
* no other module of this course is running: `Kafka/kafka_first-steps` and
  `Spark/sss_elevator-fleet` use the same ports. `docker-compose down` in their folder first

### start up the infrastructure

```
docker-compose up -d
```

The first time it downloads a couple of GB. **Don't do it in class!** If you have a slow connection, do it overnight. It is the same two images as `Kafka/kafka_first-steps` and `Spark/sss_elevator-fleet`, so if you have run either of those the download is already done.

### you know you succeeded if

1. you can open [http://localhost:8888](http://localhost:8888) 
2. entering the token `sda`, you log into a [jupyter lab environment](https://jupyterlab.readthedocs.io/en/stable/), and you have a folder named `work`
3. `docker-compose ps` shows **two** services, `kafka` and `notebook`, both up

### two services, not five

This module used to run five containers on `linux/amd64`-only images. Both images it uses
now are **multi-architecture**, so docker pulls the variant of your machine and nothing is
emulated — which matters on an Apple Silicon laptop, where the notebook kernel wedges the
moment a cell shells out. That is also why there is no `pip` cell any more: the Kafka client
is installed by `setup/20-kafka-client.sh` when the container starts.

Kafka runs in KRaft mode, so there is no ZooKeeper, no schema registry and no `kafkacat` —
this module never used them.

## 2. Explore the notebooks

1. start the notebooks
  1. run the appropriate cells of `notebooks/simulator_for_windowed-aggregation_late-arrival_semantics.ipynb`
  2. run the appropriate cells of `windowed-aggregation_late-arrival_semantics.ipynb`
2. Walk through the cells in the two notebooks making sure you follow the instructions

The two notebooks alternate: the simulator sends a section of the trace, the other one shows
what the two queries — one in `update` mode, one in `append` — made of it. The interesting
moment is section 4, where one arrival is late enough to be dropped and one is not.

Two things that are easy to skip. After each section, the monitoring notebook asks each query
for its `status` **before** reading the sink tables: wait until both report
`'Waiting for data to arrive'` with `isDataAvailable: False` and `isTriggerActive: False`,
or you will be reading a half-processed picture and mistaking a timing accident for a
difference in semantics. And at the end, run the **Clean up** cell that stops both queries —
a streaming query keeps its state and its Kafka consumer alive until you stop it.

## 3. stop the infrastructure

```
docker-compose down
```

## NOTE

This guide allows you to **optionally** try the tools presented in the SDA course.

If you are not able to set up docker or you want to **jump directly to the results of the demonstration**, go into the [`notebooks`](./notebooks/) folder: both notebooks are committed **as they ran**, with their outputs. You can read the whole demonstration — every table, every status — without starting anything.
