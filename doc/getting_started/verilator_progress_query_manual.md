# OpenTitan Verilator 后台编译进度人工查询与排查手册

本手册汇总了在任何终端环境下（无论是人工直接在 Shell 中执行，还是未来切换到其他 Agent/模型时执行）查询 OpenTitan Verilator 后台构建状态、进度指标与系统资源的完整命令。

---

## 1. 一键全景检查命令（推荐直接复制运行）

在终端中粘贴并运行以下复合命令，即可一次性输出最核心的构建全景信息：

```bash
echo "=== 1. 活跃进程树检查 ==="
ps aux | grep -E 'verilator_bin|bazel|fusesoc|cc1plus' | grep -v grep | awk '{printf "PID: %-6s CPU: %-5s MEM: %-5s TIME: %-8s COMMAND: %s\n", $2, $3, $4, $10, $11}'

echo -e "\n=== 2. 内存与 Swap 占用 ==="
free -h

echo -e "\n=== 3. 核心进程 I/O 活跃度（累计算力与数据遍历量） ==="
V_PID=$(pgrep -f verilator_bin | head -1)
if [ -n "$V_PID" ]; then
    echo "Verilator PID: $V_PID"
    cat /proc/$V_PID/io 2>/dev/null | head -6
else
    echo "未检测到 verilator_bin 进程（可能已完成或已进入 make/C++ 编译阶段）"
fi

echo -e "\n=== 4. 构建任务日志最新动态（后 15 行） ==="
tail -n 15 /tmp/ot_verilator_retry.log 2>/dev/null || echo "无日志"
```

---

## 2. 专项查询命令分解说明

### 2.1 检查构建进程与 CPU 消耗时间
用于判断编译是否卡死、是否处于活跃计算中：
```bash
# 查看所有相关编译进程，注意观察 TIME 列（累计纯 CPU 算力时间）
ps aux | grep -E 'verilator|make|g\+\+|cc1plus|Vchip' | grep -v grep
```
* **状态判断**：
  * 如果 `TIME` 在不断增长（如 30m -> 36m），说明进程正在全力计算，绝对没有卡死。
  * `STAT` 为 `R` 表示正在执行 CPU 核心逻辑；`STAT` 为 `D` 表示正在与磁盘/Swap 交互数据。

### 2.2 检查数据吞吐量（判断阶段 2 进度）
```bash
cat /proc/$(pgrep -f verilator_bin | head -1)/io
```
* 重点观察 `read_bytes`：随着拓扑遍历轮次增加，字节数会持续递增（例如从 100GB -> 130GB+），代表算法不断推进。

### 2.3 检查内存与 Swap 余量（防范 OOM）
```bash
free -h
swapon --show
```
* 检查 `Swap` 的 `free`（剩余可用空间）。只要剩余空间在 2GB 以上，说明系统环境极度安全。

### 2.4 查看中间文件生成数量
判断 Verilator 是否开始向磁盘发射生成 C++ 仿真类文件：
```bash
find /root/.cache/bazel/_bazel_root/fda00297d7986ffc883999e01b84a565/sandbox/ -name "*.cpp" -o -name "*.mk" 2>/dev/null | wc -l
```

### 2.5 查看 Bazel 任务实时日志
```bash
# 实时跟踪滚动日志
tail -f /tmp/ot_verilator_retry.log

# 或者查看最后 50 行
tail -n 50 /tmp/ot_verilator_retry.log
```

---

## 3. 最终完成或阶段切换的判断标志

* **从阶段 2 转入阶段 3（C++ 编译）的标志**：
  * `verilator_bin` 进程退出。
  * `ps aux` 中开始出现 `make`、`g++` 或 `cc1plus` 编译进程。
* **全部构建成功的标志**：
  * `/tmp/ot_verilator_retry.log` 底部输出：
    `INFO: Build completed successfully` 或 `Target //hw:verilator up-to-date:`
  * 产物文件生成：
    `ls -lh bazel-bin/hw/build.verilator_real/lowrisc_dv_top_earlgrey_chip_verilator_sim_0.1/sim-verilator/Vchip_sim_tb`
