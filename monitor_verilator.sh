    #!/usr/bin/env bash
    # monitor_verilator.sh  –  每 2 分钟打印一次进度概览

    LOG=/tmp/ot_verilator_retry.log
    while true; do
      echo "=== $(date -u) ==="
      # 最近的 FuseSoC 步骤
      tail -n 5 "$LOG" | grep -E "\[[0-9]+ / [0-9]+\]" || echo "No FuseSoC step found"
      # 进程信息（如果仍在运行）
      PID=$(pgrep -f "verilator_bin" | head -n1)
      if [ -n "$PID" ]; then
        ps -p "$PID" -o pid,ppid,%cpu,%mem,etime,cmd
      else
        echo "verilator_bin not running – likely finished"
      fi
      echo "Tail of log:"
      tail -n 10 "$LOG"
      echo "-----------------------------"
      sleep 120   # 2 min
    done
