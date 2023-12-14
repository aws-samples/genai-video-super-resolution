#!/bin/bash
time curl -X POST -d ''"$1"'' -H"Content-Type: application/json" http://localhost:8888/invocations
