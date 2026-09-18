#!/bin/bash
#SBATCH --job-name=k3-native
#SBATCH --account=reformo
#SBATCH --partition=booster
#SBATCH --nodes=8
#SBATCH --ntasks-per-node=1
#SBATCH --gpus-per-node=4
#SBATCH --cpus-per-task=288
#SBATCH --time=12:00:00
#SBATCH --signal=B:TERM@120
#SBATCH --output=%x-%j.out

export D=${DEPLOY_DIR:-/e/scratch/reformo/$USER/k3}
export IMAGE=$D/sglang-kimi-k3-arm64.sif
export MODEL=/e/data1/datasets/products/mmlaion/shared/models/moonshotai/Kimi-K3
export PORT=30000
export HEAD_IP=$(ip -o -4 addr show ib0 | awk '{print $4}' | cut -d/ -f1)
RELAY=$(cat $D/relay.multiaddr) || exit 1
RUN=$D/run-$SLURM_JOB_ID
mkdir -p $RUN/otela

cat > $RUN/engine.sh <<'ENGINE'
#!/bin/bash
export NCCL_SOCKET_IFNAME=ib0 GLOO_SOCKET_IFNAME=ib0 NCCL_SOCKET_FAMILY=IPv4 GLOO_SOCKET_FAMILY=IPv4 NCCL_IB_GID_INDEX=3 NCCL_IB_RETRY_CNT=7 NCCL_IB_TIMEOUT=22
export SGLANG_HOST_IP=$(ip -o -4 addr show ib0 | awk '{print $4}' | cut -d/ -f1)
export HF_HUB_OFFLINE=1 PYTHONNOUSERSITE=1 HF_HOME=$D/cache/hf XDG_CACHE_HOME=$D/cache/xdg TRITON_CACHE_DIR=$D/cache/triton TVM_FFI_CACHE_DIR=$D/cache/tvm-ffi/rank-$SLURM_PROCID
mkdir -p $HF_HOME $XDG_CACHE_HOME $TRITON_CACHE_DIR $TVM_FFI_CACHE_DIR
exec apptainer exec --nv --bind /e/scratch,/e/data1 $IMAGE sglang serve \
  --model-path $MODEL --served-model-name moonshotai/Kimi-K3 --trust-remote-code \
  --tp-size 4 --pp-size $SLURM_JOB_NUM_NODES --ep-size 4 \
  --nnodes $SLURM_JOB_NUM_NODES --node-rank $SLURM_PROCID --dist-init-addr $HEAD_IP:20000 --dist-timeout 60 \
  --prefill-attention-backend flashmla --decode-attention-backend flashmla \
  --moe-runner-backend marlin \
  --mem-fraction-static 0.90 --reasoning-parser kimi_k3 --tool-call-parser kimi_k3 \
  --host 0.0.0.0 --port $PORT
ENGINE

cat > $RUN/otela/cfg.yaml <<YAML
port: "8092"
security:
  require_signed_binary: false
YAML

stop() { kill -TERM $OTELA 2>/dev/null; wait $OTELA 2>/dev/null; }
trap stop EXIT TERM
( until curl -sf localhost:$PORT/health >/dev/null; do sleep 30; done
  exec $D/opentela start --config-dir $RUN/otela --bootstrap.static "$RELAY" \
    --solana.skip_verification --service.name llm --service.port $PORT ) >$RUN/otela.log 2>&1 &
OTELA=$!

srun bash $RUN/engine.sh &
wait $!