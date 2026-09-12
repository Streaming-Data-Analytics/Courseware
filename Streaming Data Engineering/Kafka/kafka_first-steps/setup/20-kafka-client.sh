#!/usr/bin/env bash
# Installs the Kafka python client before the Jupyter server starts.
#
# docker-stacks images run (or source) every script in
# /usr/local/bin/before-notebook.d/ at start-up, which is where docker-compose.yml
# mounts this one. Doing it here rather than in a notebook cell means the install
# happens once, in the container's own environment, without a kernel having to
# launch a subprocess — which is exactly what breaks when an amd64-only image is
# emulated on an ARM laptop.
#
# --only-binary=:all: says: use a prebuilt wheel or fail, rather than starting a
# source build of librdkafka that looks exactly like a hang.
#
# [avro] is the client's own extra, and it is what the Avro section of the notebook
# needs: it brings fastavro, which is also what confluent-kafka's own AvroSerializer
# uses underneath. No separate dependency of ours.
pip install --quiet --only-binary=:all: 'confluent-kafka[avro]==2.5.0' \
  || echo 'WARNING: could not install the client. From a terminal on your host:
    docker exec -it kafka-first-steps-notebook pip install "confluent-kafka[avro]==2.5.0"'
