# Spark Structured Streaming - Fire alarm

Please refer to [EPL fire allarm](https://github.com/emanueledellavalle/streaming-data-analytics/tree/main/codes/epl_firealarm) for the EPL version of the following queries.

## 1. set up

### make sure

* you have [docker](https://docs.docker.com/get-docker/) and docker-compose (they are a single app in Windows and Mac. For Linux [install docker-compose separately](https://docs.docker.com/compose/install/))
* you do not have any firewall forbidding you from reaching `localhost:8888`

### start up the infrastructure

```
docker-compose up -d
```

### you know you succeeded if

1. you can open [http://localhost:8888](http://localhost:8888) 
2. entering the password `sda`, you log into a [jupyter lab environment](https://jupyterlab.readthedocs.io/en/stable/), and you have a folder named `work`

## 2. Explore Spark Structured Streaming by example

1. start the data generator
  1. run the appropriate cells of `notebooks/smoke_sensor_simulator.ipynb`
  2. run the appropriate cells of `notebooks/temperature_sensor_simulator.ipynb`
2. Walk through the cells in `notebooks/spark-structured-streaming.ipynb`

## 3. stop the infrastructure

```
docker-compose down
```

## NOTE

This guide allows you to **optionally** try the tools presented in the SDA course.

If you are not able to set up docker or you want to **jump directly to the results of the demonstration**, go into the [`notebooks`](./notebooks/) folder and check out the execution traces in `smoke_sensor_simulator.ipynb`, `temperature_sensor_simulator.ipynb`, and `spark-structured-streaming.ipynb`. 


