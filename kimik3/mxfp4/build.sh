#!/bin/bash
set -e
D=${DEPLOY_DIR:-/e/scratch/${PROJECT:-reformo}/$USER/k3}
mkdir -p $D/tmp $D/cache
export APPTAINER_CACHEDIR=$D/cache/apptainer APPTAINER_TMPDIR=$D/tmp TMPDIR=$D/tmp
apptainer build --force --arch arm64 $D/sglang-kimi-k3-arm64.sif docker://lmsysorg/sglang:v0.5.20-cu130