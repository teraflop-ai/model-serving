#!/bin/bash
set -e
D=${DEPLOY_DIR:-/e/scratch/${PROJECT:-reformo}/$USER/glm53}
K3=/e/scratch/${PROJECT:-reformo}/$USER/k3
mkdir -p $D/tmp $D/cache
export APPTAINER_CACHEDIR=$D/cache/apptainer APPTAINER_TMPDIR=$D/tmp TMPDIR=$D/tmp
[ -e $D/opentela ] || ln -s $K3/opentela $D/opentela
# stock w4afp8 path, no patch: reuse the K3 base image if it exists
if [ -f $K3/sglang-kimi-k3-arm64.sif ]; then
  ln -sf $K3/sglang-kimi-k3-arm64.sif $D/sglang-glm53.sif
else
  apptainer build --arch arm64 $D/sglang-glm53.sif docker://lmsysorg/sglang:v0.5.20-cu130
fi