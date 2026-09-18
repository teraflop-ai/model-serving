#!/bin/bash
set -e
D=${DEPLOY_DIR:-/e/scratch/${PROJECT:-reformo}/$USER/k3}
mkdir -p $D/tmp $D/cache
export APPTAINER_CACHEDIR=$D/cache/apptainer APPTAINER_TMPDIR=$D/tmp TMPDIR=$D/tmp
[ -f $D/sglang-kimi-k3-arm64.sif ] || apptainer build --arch arm64 $D/sglang-kimi-k3-arm64.sif docker://lmsysorg/sglang:v0.5.20-cu130
[ "$(uname -m)" = aarch64 ] || { echo "run on an aarch64 node: %post must execute natively" >&2; exit 1; }
cat > $D/k3-w4afp8.def <<DEF
Bootstrap: localimage
From: $D/sglang-kimi-k3-arm64.sif

%files
    /e/data1/datasets/playground/mmlaion/shared/enrico/models/Kimi-K3-W4AFP8/apply_patch.py /opt/apply_patch.py

%post
    python3 /opt/apply_patch.py
DEF
apptainer build --force $D/sglang-k3-w4afp8.sif $D/k3-w4afp8.def