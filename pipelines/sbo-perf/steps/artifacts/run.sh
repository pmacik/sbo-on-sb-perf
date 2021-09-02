#!/bin/bash -xe

echo $SBO_PERF_RUN_ID > $WORKSPACE/sbo-perf-run.id

cp -rvf $WORKSPACE/sbo-perf-run.id $ARTIFACTS/
cp -rvf $METRICS/* $ARTIFACTS/
