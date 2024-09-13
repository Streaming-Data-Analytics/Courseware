# Spark Structured Streaming - Robotic Arm

Please refer to [../epl_robotic-arm/readme.md](../epl_robotic-arm/readme.md) for the EPL version of the following queries.

## 1. set up

### make sure

* you have [docker](https://docs.docker.com/get-docker/) and docker compose (they are a single app in Windows and Mac. For Linux [install docker compose separately](https://docs.docker.com/compose/install/))
* you do not have any firewall forbidding you from reaching `localhost:8888`

### start up the infrastructure

```
docker-compose up -d
```

### you know you succeeded if

1. you can open [http://localhost:8888](http://localhost:8888) 
2. entering the password `sda`, you log into a [jupyter lab environment](https://jupyterlab.readthedocs.io/en/stable/), and you have a folder named `notebooks`

## 2. Explore Spark Structured Streaming by example

1. start the data generator
  1. run the appropriate cells of `work/datagen1.ipynb`
  2. run the appropriate cells of `work/datagen2.ipynb`
2. Walk through the cells in `work/spark-structured-streaming-Lab.ipynb`

## 3. stop the infrastructure

```
docker-compose down
```

