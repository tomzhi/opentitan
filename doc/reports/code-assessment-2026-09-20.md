<!-- Copyright lowRISC contributors (OpenTitan project). -->
<!-- Licensed under the Apache License, Version 2.0, see LICENSE for details. -->
<!-- SPDX-License-Identifier: Apache-2.0 -->

# OpenTitan 项目代码评估报告

评估日期：2026-09-20。评估对象：本地 `master` 分支，基线提交
`9f123066c4d4a76f0bdf9d35b694b3d6bd1881c9`。
提交仓库：`git@github.com:tomzhi/opentitan.git`。

## 1. 结论

本项目是 OpenTitan 开源硅芯片信任根（Root of Trust，RoT）的软硬件一体化代码仓库。
它提供安全芯片/IP 的设计、验证、固件、制造配置和主机交互工具，主要用于建立设备的可信启动基础、保护密钥、支持设备身份与证明，以及管理芯片生命周期。
它不是一个可直接部署的普通服务端应用；使用者需要选择具体芯片顶层、工具链与目标平台。

从抽查证据看，项目具有清晰的软硬件分层、较完整的安全设计机制及多层验证基础，适合作为安全芯片研发与集成的工程基础。
主要需要关注的是不同顶层的验证覆盖不一致、合并队列验证范围，以及底层驱动在硬件异常下的恢复边界。
本次没有确认可利用的安全漏洞，也没有足够证据认定当前提交达到量产、认证或完整安全审计要求。

本结论依据仓库源码和本地有限测试，不代表上游最新发布状态，不包含远端 CI 运行结果或分支保护设置的核验。

## 2. 范围、方法与规模

采用仓库结构盘点、关键文档阅读、代表性代码路径抽查、CI 配置检查和可运行的现有单元测试。
初始工作区干净；未发现适用的 `AGENTS.md`。本次交付只新增评估报告，不修改产品代码。

以基线 `git ls-files` 为统计口径，共有 **13,918 个受版本控制的文件**：

| 目录或扩展名 | 文件数 | 说明 |
| --- | ---: | --- |
| `hw/` | 9,152 | 硬件 IP、顶层、验证、供应商代码等 |
| `sw/` | 3,747 | 设备软件、主机软件和测试等 |
| `util/` | 493 | 生成、验证、构建辅助工具等 |
| `doc/` | 159 | 集中项目文档，不含其他目录内文档 |
| `.sv` | 3,975 | SystemVerilog 文件 |
| `.c` / `.h` | 1,044 / 688 | C 实现及头文件 |
| `.py` / `.rs` | 669 / 493 | Python 工具及 Rust 实现 |
| `.hjson` / `.tpl` | 851 / 607 | 配置及模板 |

以上统计包含生成文件、测试和第三方代码；目录与扩展名是两种重叠口径，不能相加，也不能等同于原创代码量或覆盖率。
未进行逐文件审计、全量编译、硬件仿真、形式验证、依赖漏洞数据库扫描或物理攻击实验。

## 3. 主要用途与架构

项目定位见 [README](../../README.md)；安全目标见[安全文档](../security/README.md)。

| 层次 | 主要目录 | 职责与用途 |
| --- | --- | --- |
| 硬件 IP 与顶层 | `hw/ip/`、`hw/top_earlgrey/`、`hw/top_darjeeling/`、`hw/top_englishbreakfast/` | 处理器及外设集成、密码运算、随机数、密钥管理、告警及生命周期控制 |
| 硬件验证 | `hw/dv/`、各 IP 的 `dv/`、`fpv/` | 公共验证组件、仿真、断言及形式验证相关环境 |
| 安全启动与制造 | `sw/device/silicon_creator/` | ROM、ROM_EXT、启动策略、制造与设备初始化相关软件 |
| 设备运行库 | `sw/device/lib/` | MMIO 基础设施、DIF 驱动接口、密码库、运行时和测试支持 |
| 主机工具 | `sw/host/` | 芯片交互、证书、配置烧录、密码测试及渗透测试工具 |
| 生成与构建 | `util/`、`rules/`、`MODULE.bazel` | 从配置生成寄存器/IP/顶层代码，组织多语言构建及测试 |
| 规范与流程 | `doc/`、`quality/`、`ci/`、`.github/` | 安全模型、工程规范、质量检查及持续集成 |

典型使用过程是：选定顶层和硬件配置，生成并验证设计，构建固件及镜像，完成制造配置，再由芯片启动链校验后续软件并控制密钥使用。
这涉及硬件、固件和制造流程的共同约束，不能只评估密码算法源码就推断整机安全。

[顶层选择机制](../../hw/top/README.md)以 Bazel 配置区分目标，默认使用 Earlgrey，并提供不兼容目标约束。
[主机软件入口](../../sw/host/README.md)列出了 OpenTitanTool、OpenTitanLib、证书工具等；签名基础设施还有独立仓库依赖，不能只凭本仓库完成全部生产签名流程评估。

## 4. 代码质量与安全设计抽查

### 4.1 启动链具有明确的校验与加固机制

在 [rom.c](../../sw/device/silicon_creator/rom/rom.c) 的 `rom_verify()`（约第 338 行起）中，可以看到安全版本检查、manifest 检查、OTP 密钥加载、ECDSA P-256 和按配置执行的 SPHINCS+ 校验，以及 `HARDENED_*` 检查。
因此不能简单描述为“所有配置都强制执行相同的双签名策略”；生命周期和 OTP 配置会影响实际路径。

[boot_policy.c](../../sw/device/silicon_creator/rom/boot_policy.c)对镜像标识、长度、安全版本进行验证，并对 A/B 镜像排序。
相关目录提供 `boot_policy_unittest.cc`、bootstrap 单元测试、模糊测试及 ROM 端到端测试材料。
这些是良好的设计与测试基础，但本次没有运行对应的目标固件测试。

### 4.2 硬件安全措施与软件接口有分层

[aes.sv](../../hw/ip/aes/rtl/aes.sv)包含默认开启的掩码参数、完整性错误输入和告警发送器；AES 目录还包含验证环境与故障注入相关代码。
[dif_aes.c](../../sw/device/lib/dif/dif_aes.c)使用影子寄存器双写并清理内部状态，体现软件对硬件安全协议的适配。
参数默认值和相关代码的存在不等于特定芯片配置已经通过侧信道或故障注入认证。

### 4.3 工程化基础较完整，但验证效果仍需运行证据

[MODULE.bazel](../../MODULE.bazel)、`MODULE.bazel.lock`、`uv.lock`、`flake.lock`及 `.bazelversion`提供版本和依赖管理基础；当前 Bazel 版本文件为 `8.7.0`。
[CI 配置](../../.github/workflows/ci.yml)覆盖生成文件、硬件 lint、软件构建与单元测试、Verilator、FPGA 等任务。
[lint 入口](../../ci/lint/run.sh)把本地与 CI 检查集中在一处，并明确限制会清理工作区的生成文件检查在一次性 CI 环境运行。

优点是规范、生成源、实现与验证材料能够在同一仓库协同演进。
代价是工具链多、生成文件多、顶层配置差异大；“文件存在”“工作流定义存在”均不能替代该提交的执行结果。

## 5. 发现与改进建议

以下优先级表示工程处理顺序，不是漏洞等级：P1 为依赖相应功能前应处理或明确接受的风险，P2 为后续治理项。

### F1：English Breakfast 的主要硬件 lint 被跳过（P1，已确认配置行为）

证据：[ci/lint/run.sh](../../ci/lint/run.sh)约第 143–175 行，对 `englishbreakfast` 直接跳过 `rtl`、`dv`、`fpv` 循环。
脚本注释说明 lint 配置引用了不存在的核；[顶层 lint 配置](../../hw/top_englishbreakfast/lint/top_englishbreakfast_lint_cfgs.hjson)确实包含 `lowrisc:englishbreakfast_ip:otp_ctrl` 等名称。
虽然工作流矩阵包含该顶层，但不能据此认定它执行了与 Earlgrey 相同的 lint。该顶层仍运行 countermeasure 检查。

影响：使用此顶层时，相关语法、风格和集成问题不能由这些被跳过的检查阻断。
建议：修复核引用并恢复检查；恢复前在状态输出中清晰标注缺失项。
验收：三类 lint 均实际执行，故意引入受规则覆盖的错误能够使对应检查失败。

### F2：合并队列不执行主要构建与测试（P1，条件性集成风险）

证据：[ci.yml](../../.github/workflows/ci.yml)的 `sw_build_test`（第 508–513 行）、Darjeeling 构建及多个仿真/FPGA任务排除 `merge_group`，lint 则在该事件下运行。

影响：若远端启用合并队列，两项单独通过测试的变更组合后，可能出现 lint 无法发现的编译或功能问题。
这不表示 PR 完全没有测试，也不表示已确认远端启用了合并队列；后者未核验。
建议：在合并队列增加核心软件构建和最小仿真回归，结合运行成本选择范围。
验收：以真实 `merge_group` 提交验证任务执行，并确认关键检查属于实际分支门禁。

### F3：AES 部分驱动路径存在无界状态等待（P1，需验证系统恢复策略）

证据：[dif_aes.c](../../sw/device/lib/dif/dif_aes.c)第 26–29 行的 `AES_WAIT_FOR_STATUS` 仅轮询状态位，没有超时和错误退出。
`aes_clear_internal_state()`在清理前后使用该宏，`dif_aes_reset()`调用此函数；其他配置或数据处理路径也使用该宏。

影响：若外设状态因故障、时钟或相关硬件条件而永久不满足，调用可能不能返回。
这是静态可见的阻塞边界，不是已复现的芯片故障或远程拒绝服务漏洞；系统看门狗和告警策略可能提供恢复能力。
建议：明确阻塞 API 契约，核验上层看门狗及错误处理；确有可用性要求时设计有界等待或非阻塞接口，避免草率改变安全清理语义。
验收：注入状态位不变化的场景，确认在规定时间内恢复或进入预期安全状态。

### F4：全树 SystemVerilog 扫描仅提示，不构成门禁（P2，已确认策略）

证据：[ci.yml](../../.github/workflows/ci.yml)的 `lint_sv_sweep` 使用 `continue-on-error: true`；[ci/lint/run.sh](../../ci/lint/run.sh)说明扫描退出状态被忽略，且独立解析 UVM 片段会产生噪声。

影响：未被顶层 lint 配置覆盖的文件可能缺少阻断性检查；不能据此认定已有实际功能缺陷。
建议：保留对上下文依赖文件的合理处理，逐步把可独立验证的文件纳入适用的编译单元和门禁，并统计未覆盖文件及豁免。
验收：新增或修改的受管文件都有明确的检查归属和责任人。

## 6. 本地验证记录

执行环境：Python `3.12.3`。以下命令均从仓库根目录运行。

| 检查 | 命令 | 结果 |
| --- | --- | --- |
| 构建信息工具单元测试 | `PYTHONDONTWRITEBYTECODE=1 PYTHONPATH=util python3 -m unittest build_info_test -v` | 8 项通过 |
| 汇编覆盖率解析与基本块单元测试 | `PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s util/coverage/asm -p '*_test.py' -v` | 7 项通过 |
| 初次广范围测试发现 | `PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s util -p build_info_test.py -v` | 8 项通过，另有 3 个包导入错误；缺少 `hjson`、`mako`，随后改用上面的精确模块命令 |
| PRNG 直接测试发现 | `PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s util/topgen -p secure_prng_test.py -v` | 导入失败，局部 `typing.py` 遮蔽标准库；未执行测试，不计入通过数 |

已成功执行的测试合计 **15 项**，不重复计算初次发现命令中的同一组测试。
PRNG 失败发生在本次直接 discovery 的导入方式下，不能外推为项目正式构建流程必然失败。

环境 PATH 中没有 `bazel`、`bazelisk`、`nix`、`verilator`、`iverilog`、`pytest`。
仓库有 `bazelisk.sh`，但本次没有引导下载工具链或安装依赖，也没有运行完整构建、目标 C/C++/Rust 测试、RTL/UVM 回归、FPGA 或硅片实验。
因此不提供虚构的整体通过率、覆盖率、性能数据或安全认证结论。

## 7. 后续实施顺序与交付边界

1. 先确定采用的顶层、生命周期配置、实际签名/密钥策略及目标平台，建立该配置的可重复构建和回归基线。
2. 对使用 English Breakfast 或合并队列的团队，优先处理 F1、F2；收集该提交对应的真实 CI 与门禁证据。
3. 验证 F3 的故障恢复时限及安全状态，按系统要求决定是否修改接口。
4. 持续维护 F4 的覆盖范围、生成文件一致性、依赖更新和豁免记录。
5. 量产前另行审查制造配置、生命周期转换、密钥灌装、启动回滚策略和物理安全测试结果。

本报告是基于指定代码快照的工程评估，可用于项目理解、风险排期和后续验证计划；不能替代产品级安全审计或发布批准。
本次提交范围仅为此报告，远端交付以 Git 推送及远端分支提交哈希核对结果为准。
