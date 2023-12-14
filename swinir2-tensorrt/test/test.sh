#!/bin/bash
set -e
mkdir -p HD/frames
time curl -X POST -d@payload.json -H"Content-Type: application/json" http://localhost:8888/invocations 
