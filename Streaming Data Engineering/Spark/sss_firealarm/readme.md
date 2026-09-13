# Spark Structured Streaming - Fire alarm

Please refer to [`EPL/epl_firealarm`](../../EPL/epl_firealarm) for the EPL version of the
following queries.

## 1. set up

### make sure

* you have [docker](https://docs.docker.com/get-docker/) and docker-compose (they are a single app in Windows and Mac. For Linux [install docker-compose separately](https://docs.docker.com/compose/install/))
* you do not have any firewall forbidding you from reaching `localhost:8888`
* no other module of this course is running: they all publish 8888 and 29092.
  `docker-compose down` in the other module's folder first

### start up the infrastructure

```
docker-compose up -d
```

The first time it downloads a couple of GB. **Don't do it in class!** It is the same two
images as the other Spark and Kafka modules, so if you have run any of those the download
is already done.

### you know you succeeded if

1. you can open [http://localhost:8888](http://localhost:8888) 
2. entering the token `sda`, you log into a [jupyter lab environment](https://jupyterlab.readthedocs.io/en/stable/), and you have a folder named `work`
3. `docker-compose ps` shows **two** services, `kafka` and `notebook`, both up

### two services, not five

This module used to run five containers on `linux/amd64`-only images — ZooKeeper, a
schema registry and kafkacat among them, and no notebook here ever used the last two.
Both images it uses now are **multi-architecture**, so docker pulls the variant of your
machine and nothing is emulated, which matters on an Apple Silicon laptop: under
emulation the notebook kernel wedges the moment a cell shells out. That is also why
there is no `pip` cell any more — the Kafka client is installed by
`setup/20-kafka-client.sh` when the container starts.

Kafka runs in KRaft mode, so there is no ZooKeeper.


## 2. Explore Spark Structured Streaming by example

1. start the data generator
  1. run the appropriate cells of `work/smoke_sensor_simulator.ipynb`
  2. run the appropriate cells of `work/temperature_sensor_simulator.ipynb`
2. Walk through the cells in `work/spark-structured-streaming.ipynb`

## 3. stop the infrastructure

```
docker-compose down
```

## NOTE

This guide allows you to **optionally** try the tools presented in the SDA course.

If you are not able to set up docker or you want to **jump directly to the results of the demonstration**, go into the [`notebooks`](./notebooks/) folder and check out the execution traces in `smoke_sensor_simulator.ipynb`, `temperature_sensor_simulator.ipynb`, and `spark-structured-streaming.ipynb`. 


