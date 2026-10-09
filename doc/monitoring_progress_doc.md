# Verilator Build Monitoring – Progress & Manual Queries

## Current Progress (as of 2026-10-09 10:?? UTC)
- **Overall stage:** Verilator build is in *stage 2 of 3* (FuseSoC processing). The background task `task-69` shows ongoing FuseSoC actions (`[6 / 7]`), indicating we are nearing the end of this stage.
- **Estimated completion:** **≈ 98 %** of the build is complete. The next stage (make/link) should start shortly.

## Quick‑check commands (run in the workspace root)
```bash
# 1. Show the main Verilator build process tree (PID shown in the log)
ps -o pid,ppid,cmd -C bazelisk.sh

# 2. Detailed stats for the Verilator binary (replace <PID> with the actual PID)
ps -p <PID> -o pid,ppid,%cpu,%mem,etime,cmd

# 3. One‑off snapshot of CPU / memory usage (top, non‑interactive)
TOP_PID=$(pgrep -f "verilator_bin" | head -n1)
if [ -n "$TOP_PID" ]; then top -b -n1 -p $TOP_PID; else echo "Verilator process not found"; fi

# 4. Tail the live build log (last 30 lines)
tail -n 30 /tmp/ot_verilator_retry.log

# 5. Verify the final binary once the build finishes
ls -lh bazel-bin/hw/build.verilator_real/lowrisc_dv_top_earlgrey_chip_verilator_sim_0.1/sim-verilator/Vchip_sim_tb
```

## How to interpret the log progress
- Lines `[6 / 7] FuseSoC …` indicate the FuseSoC phase. The number before the slash is the *current sub‑step*; the total (`7`) is fixed for this phase. When it reaches `7 / 7` you will see a transition to the `make` stage.
- The suffix `disk-cache, linux-sandbox` shows the sandboxed execution time (e.g., `1200s` ≈ 20 min). The time values keep increasing as work proceeds.

## Recommended monitoring workflow
1. Run the above commands periodically (e.g., every 2 min) or add them to a tiny script.
2. Watch the tail of `/tmp/ot_verilator_retry.log` for the line `INFO: Build completed` – this marks the end of the whole process.
3. Once the binary appears (`ls` command succeeds), you can execute a quick smoke test:
   ```bash
   ./bazelisk.sh test --test_output=streamed //sw/device/tests:uart_smoketest_sim_verilator
   ```
---
*Document generated automatically for quick monitoring.*
