#!/bin/bash
set -e
mkdir -p HD/frames
curl -X POST -d@payload.json -H"Content-Type: application/json" http://localhost:8889/invocations 
