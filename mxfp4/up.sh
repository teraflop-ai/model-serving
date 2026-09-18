#!/bin/bash
set -e
cd "$(dirname "$0")"
export DEPLOY_DIR=${DEPLOY_DIR:-/e/scratch/${PROJECT:-reformo}/$USER/k3}
[ -f $DEPLOY_DIR/sglang-kimi-k3-arm64.sif ] || bash build.sh
bash relay.sh
sbatch "$@" serve.sbatch