# Step-by-step deployment
```sh
bash build.sh                 # once: SIF on /e/scratch
bash relay.sh                 # once: relay in tmux `otela-relay`, writes $D/relay.multiaddr
sbatch serve.sbatch           # per job: sglang on N nodes + otela worker on the head node
```

# Full deployment
```sh
bash up.sh 
```

# Check valid deployment
```sh
curl -s https://api.opentela.ai/v1/service/llm/v1/chat/completions \
  -H "Authorization: Bearer YOUR_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"model":"moonshotai/Kimi-K3","messages":[{"role":"user","content":"ping"}]}'
```

# Verify running job
```sh
srun --jobid=$JOB --overlap -N1 -w $(squeue -j $JOB -h -o %N | scontrol show hostnames | head -1) curl -s localhost:30000/health
grep -iE "regist|LEFT|error" $D/run-$JOB/otela.log
tmux attach -t otela-relay     # relay log
```