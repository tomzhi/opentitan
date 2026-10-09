# OpenTitan Verilator 仿真编译维护指南与故障排查记录

## 1. 项目背景与前期状态分析

### 1.1 项目环境与前期进展
* **项目名称**：OpenTitan (lowRISC)
* **核心目标**：在本地环境构建并单步运行基于 Verilator 的 Earl Grey 顶层 SoC 仿真模型 (`//hw:verilator` / `//hw/top_earlgrey:sim_verilator`)。
* **前期状态**：
  * 前期已通过包管理器补充了一部分基础开发依赖，并尝试通过 Bazel 构建仿真模型。
  * 在上一轮运行过程中，因模型配额耗尽交互中断，遗留构建错误日志。

---

## 2. 核心问题定位与根因分析

经检查历史运行记录与构建日志 (`/tmp/ot_verilator_model.log`)，发现导致构建中断的核心问题有两个：

### 2.1 Verilator 工具版本不兼容（语法与语义检查报错）
* **现象**：
  在 FuseSoC 调用 Verilator 解析 RTL 并生成 C++ 代码时，报出多处关键语法错误：
  ```text
  %Error-NEEDTIMINGOPT: src/lowrisc_systems_top_earlgrey_ast_0.1/rtl/vio_pgd.sv:25:22: Use --timing or --no-timing to specify how delays should be handled
  %Error-NEEDTIMINGOPT: src/lowrisc_systems_top_earlgrey_ast_0.1/rtl/vio_pgd.sv:34:18: Use --timing or --no-timing to specify how timing controls should be handled
  %Error: Exiting due to 6 error(s)
  make: *** [Makefile:15: Vchip_sim_tb.mk] Error 1
  ```
* **根本原因**：
  系统中原预装的 Verilator 是通过 APT 安装的较新版本 `5.020`。Verilator 5.x 引入了对时序延迟（timing control `#delay`）的严格检查，强制要求指定 `--timing` 或 `--no-timing`；而 OpenTitan 官方维护与锁定的工具链版本为 **`Verilator v4.210`**。

### 2.2 内存与系统资源受限风险（OOM 风险）
* **现状**：
  当前宿主机物理内存仅为 **3.3 GB**，默认交换分区（Swap）仅 1.5 GB。
* **风险点**：
  OpenTitan Earl Grey 是一个完整的复杂 RISC-V SoC。默认配置下 Verilator 会启用 4 线程，且后端 `make` 编译生成的上百个 C++ 源码文件时也是多并发，峰值内存极易突破 6~8 GB，从而触发 Linux 内核的 OOM-Killer（强制杀死 `cc1plus` / `verilator` 进程）。

---

## 3. 已执行的操作与修复措施

### 3.1 安装与切换至官方指定匹配版本 Verilator 4.210
1. 从官方预编译归档拉取匹配版本：
   ```bash
   mkdir -p /tools/verilator
   curl -sSfL https://storage.googleapis.com/verilator-builds/verilator-v4.210.tar.gz | tar -C /tools/verilator -xvzf -
   ```
2. 建立系统软链接并写入环境变量：
   ```bash
   ln -sf /tools/verilator/v4.210/bin/verilator* /usr/local/bin/
   echo 'export PATH=/tools/verilator/v4.210/bin:$PATH' >> /root/.bashrc
   ```
3. 验证工具版本：
   ```bash
   verilator --version
   # 输出: Verilator 4.210 2021-07-07 rev v4.210
   ```

> **注意（多项目多版本切换）**：
> 系统中已内置了切换工具 `switch-verilator`。如果后续其他项目需要切回高版本 Verilator 5.020 或在两者之间切换，详细操作请参阅独立文档：
> [verilator_version_switching_guide.md](./verilator_version_switching_guide.md)

### 3.2 扩充系统 Swap 空间防御 OOM
为避免低内存环境下编译被中断，分配并持久化了共计 10GB 的额外 Swap 文件（当前总 Swap 为 11.5GB）：
* `/swapfile_extra` (6GB)
* `/swapfile_extra2` (4GB)

> **注意（Swap 运维与开关指南）**：
> 有关 Swap 的持久化挂载状态、性能影响、日常查看、启停以及将来释放磁盘空间的完整指引，请参阅独立文档：
> [swap_configuration_guide.md](./swap_configuration_guide.md)

### 3.3 启用严格单线程低负载编译参数
通过向 Bazel 和底层硬件构建配置注入参数，严格控制并发量与资源占用：
```bash
./bazelisk.sh build \
  --jobs=1 \
  --local_resources=cpu=1 \
  --//hw:verilator_options=--threads,1 \
  --//hw:make_options=-j,1 \
  --disk_cache="$HOME/bazel_cache" \
  --verbose_failures \
  //hw:verilator
```
* `--jobs=1` / `--local_resources=cpu=1`：限制 Bazel 全局仅允许一个活动构建任务。
* `--//hw:verilator_options=--threads,1`：使生成的 Verilator C++ 仿真模型内部采用单线程逻辑，节省模型生成阶段的内存。
* `--//hw:make_options=-j,1`：让 FuseSoC 在编译 C++ 仿真目标文件时单线程执行 `make`，将内存峰值压制在 2GB 左右。

---

## 4. 后续维护与仿真测试指引

### 4.1 监控正在运行的编译任务
查看当前后台构建状态与日志：
```bash
# 查看进程状态
ps aux | grep -E 'bazel|verilator|fusesoc|cc1plus' | grep -v grep

# 查看实时构建日志
tail -f /tmp/ot_verilator_retry.log

# 查看内存与 Swap 使用变化
watch -n 5 free -h
```

### 4.2 编译产物位置
构建完成后，生成的仿真二进制文件将位于：
* `bazel-bin/hw/build.verilator_real/lowrisc_dv_top_earlgrey_chip_verilator_sim_0.1/sim-verilator/Vchip_sim_tb`

### 4.3 运行单步/冒烟测试用例
编译生成二进制后，即可运行 OpenTitan 官方的 Verilator 仿真测试（以 UART 冒烟测试为例）：
```bash
./bazelisk.sh test \
  --test_output=streamed \
  //sw/device/tests:uart_smoketest_sim_verilator
```
如需生成仿真波形（FST 格式）：
```bash
./bazelisk.sh test \
  --test_output=streamed \
  --test_timeout=1800 \
  --test_arg=--verilator-args=--trace=/tmp/sim.fst \
  //sw/device/tests:uart_smoketest_sim_verilator
```
波形可以使用 `gtkwave /tmp/sim.fst` 查看。
