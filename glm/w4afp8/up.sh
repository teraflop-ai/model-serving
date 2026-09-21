#!/bin/bash
set -e
cd "$(dirname "$0")"
export DEPLOY_DIR=${DEPLOY_DIR:-/e/scratch/${PROJECT:-reformo}/$USER/glm53}
[ -f $DEPLOY_DIR/sglang-glm53.sif ] || bash build.sh
bash relay.sh
sbatch "$@" serve.sbatch