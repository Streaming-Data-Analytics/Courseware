#!/usr/bin/env bash
# Installs the Kafka python client before the Jupyter server starts.
#
# docker-stacks images run (or source) every script in
# /usr/local/bin/before-notebook.d/ at start-up, which is where docker-compose.yml
# mounts this one. Doing it here rather than in a notebook cell means the install
# happens once, in the container's own environment, without a kernel having to
# launch a subprocess — and the first cell of the lecture is a check, not a wait.
#
# --only-binary=:all: says: use a prebuilt wheel or fail. Building librdkafka from
# source takes tens of minutes and looks exactly like a hang, so being told is
# better. confluent-kafka 2.x is the first line with wheels for python 3.10+ and
# for aarch64; the 1.7.0 pin the other modules use has neither.
pip install --quiet --only-binary=:all: confluent-kafka==2.5.0 \
  || echo "WARNING: could not install confluent-kafka. From a terminal on your host:
    docker exec -it fleet-notebook pip install confluent-kafka==2.5.0"
