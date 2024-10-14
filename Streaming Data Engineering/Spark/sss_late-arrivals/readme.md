# Spark Structured Streaming - Handling Late Data and Watermarking

## 1. set up

### make sure

* you have a large enough machine (processor: 8 cores, memory: 16-32GB)
* you have [docker](https://docs.docker.com/get-docker/) and docker-compose (they are a single app in Windows and Mac. For Linux [install docker-compose separately](https://docs.docker.com/compose/install/))
* you do not have any firewall forbidding you from reaching `localhost:8888`

### start up the infrastructure

```
docker-compose up -d
```

If you do it for the first time, it takes 10 minutes using a 100 Gbit/s connection because it needs to download 7.8 GB. **Don't do it in class!** If you have a slow connection, do this overnight. 

### you know you succeeded if

1. you can open [http://localhost:8888](http://localhost:8888) 
2. entering the password `sda`, you log into a [jupyter lab environment](https://jupyterlab.readthedocs.io/en/stable/), and you have a folder named `work`

## 2. Explore the notebooks

1. start the notebooks
  1. run the appropriate cells of `notebooks/simulator_for_windowed-aggregation_late-arrival_semantics.ipynb`
  2. run the appropriate cells of `windowed-aggregation_late-arrival_semantics.ipynb`
2. Walk through the cells in the two notebooks making sure you follow the instructions

## 3. stop the infrastructure

```
docker-compose down
```

## NOTE

This guide allows you to **optionally** try the tools presented in the SDA course.

If you are not able to set up docker or you want to **jump directly to the results of the demonstration**, go into the [`notebooks`](./notebooks/) folder and check out the execution traces in `smoke_sensor_simulator.ipynb`, `temperature_sensor_simulator.ipynb`, and `spark-structured-streaming.ipynb`. 


