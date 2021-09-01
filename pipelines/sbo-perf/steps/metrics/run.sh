#!/bin/bash -xe

export SBO_PERF_RUN_ID=$(date +%Y-%m-%d_%H:%M:%S)-$HOSTNAME
echo $SBO_PERF_RUN_ID > $WORKSPACE/sbo-perf-run.id

$WORKSPACE/src/collect-metrics.sh 30 $ARTIFACTS/$SBO_PERF_RUN_ID/metrics
