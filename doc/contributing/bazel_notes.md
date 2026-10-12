# Bazel 使用说明

OpenTitan 的硬件和软件均使用 Bazel 构建。
[入门指南](../../doc/getting_started/README.md)介绍了构建这两类产物时会用到的一些 Bazel 命令。本文进一步说明：
* 本项目的 Bazel 配置；以及
* 常用 Bazel 查询、构建和测试命令示例。

# OpenTitan Bazel 工作区

Bazel 规则使用 Starlark 编写，语法与 Python 很相似。

`//WORKSPACE` 文件将 `$REPO_TOP` 目录定义为 Bazel 工作区。
`BUILD` 文件描述 Bazel 如何构建目录中的目标，也负责管理没有独立 `BUILD` 文件的子目录。

OpenTitan 使用 `.bzl` 文件定义自定义构建规则，用于处理需要专门配置的产物，例如设备测试规则和项目专用二进制文件。

## WORKSPACE 文件

`WORKSPACE` 文件管理外部依赖，以保证构建可复现且相互隔离。
Bazel 会加载指定的外部依赖，例如各种语言工具链，并用它们构建 OpenTitan 目标（例如 `bazel_embedded`）或满足目标依赖（例如 `abseil`）。
为提高版本发布的稳定性，`WORKSPACE` 中加载的外部依赖会尽量将所有 `http_archive` 固定到特定 SHA。
随着工作区纳入更多依赖，构建和测试会更少受到外部更新的影响，[入门指南](../../doc/getting_started/README.md)也能相应简化。

## BUILD 文件

OpenTitan 仓库中的 `BUILD` 文件描述当前目录中的目标及其依赖，也涵盖没有独立 `BUILD` 文件的子目录。
大多数 `BUILD` 文件由开发者手动维护。
为避免手写文件被放进自动生成目录，仓库会用 `BUILD` 文件描述如何构建和依赖 `autogen` 子目录中的自动生成文件。

# 常用命令

- 构建所有内容（软件和 Verilator 硬件）：
  ```sh
  bazel build //...
  ```
- 构建并运行所有测试（主机端测试，以及 Verilator/FPGA 设备端测试）：
  ```sh
  bazel test --test_tag_filters=-broken,-dv //sw/...
  ```
  注意：此命令可能需要运行数小时。
- 清理所有构建产物，并清除 Bazel 实例产生的磁盘和内存痕迹：
  ```sh
  bazel clean --expunge
  ```
  注意：通常很少需要运行此命令。什么情况下可能需要运行，请参见[下文](#构建故障排查)。

# 查找构建产物

构建目标及其依赖时，Bazel 会将产物放入自己管理的输出目录，因此手动查找并不方便。
下文会介绍如何通过 Bazel 查询已构建产物的位置。
注意：下文的 `outquery-*` 是由项目脚本 `bazelisk.sh` 解析的特殊命令，不能直接作为独立的 `bazel ...` 命令运行。

## `opentitan_binary` 产物

- 查询 `opentitan_binary` 宏为所有 OpenTitan 设备构建的产物位置：
  ```sh
  ./bazelisk.sh outquery-all <target>
  ```

> 关于 `opentitan_binary` 规则的更多信息，请参阅 [OpenTitan 二进制文件和测试规则](../../rules/opentitan/README.md)。

如[构建和测试软件](../getting_started/build_sw.md#device-artifacts)所述，使用 OpenTitan 专用的 Bazel 宏，可以为多种 OpenTitan 设备和存储器构建设备软件。

## `opentitan_test` 产物

如[构建和测试软件](../getting_started/build_sw.md#device-artifacts)所述，使用 OpenTitan 专用的 Bazel 宏，可以为多种 OpenTitan 设备和存储器构建设备软件。
在多种 OpenTitan 设备上运行测试（包括 DV、Verilator 仿真和 FPGA）时，需要为多种存储器构建多个软件映像，因此项目提供了名为 `opentitan_test` 的 Bazel 宏。

- 列出 `opentitan_test` 实例化的所有 `sh_test` 目标，例如 UART 冒烟测试：
  ```sh
  bazel query 'labels(tests, //sw/device/tests:uart_smoketest)'
  ```

> 关于 `opentitan_test` 规则的更多信息，请参阅 [OpenTitan 二进制文件和测试规则](../../rules/opentitan/README.md)。

# 构建软件

* 构建 OpenTitan 软件的方法请参阅[此处](../getting_started/build_sw.md#building-software-with-bazel)，也可以运行：
  ```sh
  bazel build <target>
  ```

# 测试软件

## 主机端测试

* 查询或运行主机端软件测试的方法请参阅[此处](../getting_started/build_sw.md#running-tests-with-bazel)。

## 设备端测试

所有设备的软件都使用 Bazel 构建。
目前只有 Verilator 仿真和 FPGA 设备软件测试可以通过 Bazel 运行。

### ROM 测试

* 查询所有 FPGA ROM 功能测试和端到端（E2E）测试：
  ```sh
  bazel query 'filter(".*_fpga_cw340", kind(".*test rule", //sw/device/silicon_creator/...))'
  ```
  Verilator 测试的查询命令：
  ```sh
  bazel query 'filter(".*_sim_verilator", kind(".*test rule", //sw/device/silicon_creator/...))'
  ```
* 在 FPGA 上运行所有 ROM 功能测试和端到端（E2E）测试：
  ```sh
  bazel test --test_tag_filters=cw340 //sw/device/silicon_creator/...
  ```
  Verilator 测试的运行命令：
  ```sh
  bazel test --test_tag_filters=verilator //sw/device/silicon_creator/...
  ```
* 在 FPGA 上运行单个 ROM 功能测试或端到端测试，并实时查看输出：
  ```sh
  bazel test \
    --define DISABLE_VERILATOR_BUILD=true \
    --test_tag_filters=cw340 \
    --test_output=streamed \
    //sw/device/silicon_creator/lib:boot_data_functest
  ```
  或者移除 define 和筛选参数，并在目标名称后追加 `<device>`，例如：
  ```sh
  bazel test --test_output=streamed //sw/device/silicon_creator/lib:boot_data_functest_fpga_cw340
  ```
  Verilator 测试的运行命令：
  ```sh
  bazel test --test_output=streamed //sw/device/silicon_creator/lib:boot_data_functest_sim_verilator
  ```

### 芯片级测试

* 查询所有 FPGA 芯片级测试：
  ```sh
  bazel query 'filter(".*_fpga_cw340", kind(".*test rule", //sw/device/tests/...))'
  ```
  Verilator 测试的查询命令：
  ```sh
  bazel query 'filter(".*_sim_verilator", kind(".*test rule", //sw/device/tests/...))'
  ```
* 在 FPGA 上运行所有芯片级测试：
  ```sh
  bazel test --define DISABLE_VERILATOR_BUILD=true --test_tag_filters=cw340 //sw/device/tests/...
  ```
  Verilator 测试的运行命令：
  ```sh
  bazel test --test_tag_filters=verilator //sw/device/tests/...
  ```
* 在 FPGA 上运行单个芯片级测试，并实时查看输出：
  ```sh
  bazel test \
    --define DISABLE_VERILATOR_BUILD=true
    --test_tag_filters=cw340 \
    --test_output=streamed \
    //sw/device/tests:uart_smoketest
  ```
  或者移除 define 和筛选参数，并在目标名称后追加 `<device>`，例如：
  ```sh
  bazel test --test_output=streamed //sw/device/tests:uart_smoketest_fpga_cw340
  ```
  Verilator 测试的运行命令：
  ```sh
  bazel test --test_output=streamed //sw/device/tests:uart_smoketest_sim_verilator
  ```

# 软件代码检查

项目提供了多条 Bazel 规则，用于运行代码质量检查和自动修复工具。运行以下命令可列出这些规则：
```sh
bazel query //quality:all
```
下文各小节介绍这些工具的用法。
所有这些工具都会在每个 Pull Request 的 CI 中运行，因此建议在提交代码前先运行。

## 检查 C/C++ 代码

OpenTitan 使用 `clang-format` 检查和格式化 C/C++ 文件。可通过以下 Bazel 命令运行。

运行以下命令，检查 C/C++ 代码的格式是否正确：
```sh
bazel test //quality:clang_format_check --test_output=streamed
```
如果格式不正确，运行以下命令进行修复：
```sh
bazel run //quality:clang_format_fix
```

## 格式化 Rust 代码

OpenTitan 使用 `rustfmt` 格式化 Rust 代码。可通过以下 Bazel 命令运行。

运行以下命令，检查 Rust 代码的格式是否正确：
```sh
bazel test //quality:rustfmt_check --test_output=streamed
```
如果格式不正确，运行以下命令进行修复：
```sh
bazel run //quality:rustfmt_fix
```

## 格式化 Bazel 文件

OpenTitan 使用 `buildifier` 自动格式化 Bazel 文件。

运行以下命令，检查所有 `BUILD` 文件的格式是否正确：
```sh
bazel test //quality:buildifier_check --test_output=streamed
```
如果格式不正确，运行以下命令进行修复：
```sh
bazel run //quality:buildifier_fix
```

## 检查 Starlark

OpenTitan 使用 `buildifier` 检查 Bazel 文件。可通过以下 Bazel 命令运行。

运行以下命令，检查所有 `WORKSPACE`、`BUILD` 和 `.bzl` 文件的格式是否正确：
```sh
bazel test //quality:buildifier_check --test_output=streamed
```
如果格式不正确，运行以下命令进行修复：
```sh
bazel run //quality:buildifier_fix
```

## 检查许可证头

最后，可运行以下命令，检查每个源代码文件是否包含许可证头：
```sh
bazel run //quality:license_check --test_output=streamed
```

# 构建硬件

注意：在上述 OpenTitan 硬件平台上运行（软件）测试前，**不需要**先执行下面这些 Bazel 命令。
Bazel 会根据依赖关系自动构建运行测试所需的前置目标。

- 构建包含（测试）ROM 的 FPGA 基础 bitstream，请参阅[此处](../getting_started/setup_fpga.md#build-an-fpga-bitstream)。
- 为 FPGA 构建正式 ROM 和 OTP 映像，请参阅[此处](../getting_started/setup_fpga.md#programming-the-fpga-with-rom--otp-images)。
- 构建 Verilator 仿真二进制文件：
  ```sh
  bazel build //hw:verilator
  ```

## Verilator 测试的构建配置

即使单独构建过 `//hw:verilator`，运行 Verilator 测试时仍可能再次构建该目标。
Bazel 为测试工具构建仿真器时，可能使用与默认 `bazel build //hw:verilator` 不同的配置：
例如测试工具使用 `k8-opt-exec`，而默认构建使用 `k8-fastbuild`。
这两种配置会产生不同的输出，仿真二进制文件不能互相复用。

首次运行时，直接执行测试，让 Bazel 按测试所需配置构建仿真器。这样可以避免先单独完整
构建一个测试无法复用的仿真器：

```sh
bazel test --test_output=streamed \
  --//hw:verilator_options=--threads,2 \
  --//hw:make_options=-j,1 \
  //sw/device/tests:uart_smoketest_sim_verilator
```

若要延长测试时限，可在 test 命令中传入 `--test_timeout`。逗号分隔的四个值分别设置
`short`、`moderate`、`long` 和 `eternal` 类别的时限，单位为秒。例如，下面的命令将
`moderate` 时限从通常的 300 秒提高到 3000 秒：

```sh
bazel test --test_output=streamed --test_timeout=60,3000,15000,72000 \
  --//hw:verilator_options=--threads,2 \
  --//hw:make_options=-j,1 \
  //sw/device/tests:uart_smoketest_sim_verilator
```

注意，`//sw/device/tests:uart_smoketest_sim_verilator` 在
`sw/device/tests/BUILD` 中设置为 `eternal` 类别，因此实际使用 `--test_timeout` 的
第四个值。项目 `.bazelrc` 中该类别默认值为 7200 秒；如果希望为此测试设置 3000 秒，
应将第四个值设为 `3000`，例如 `--test_timeout=60,300,1500,3000`。

覆盖测试时限不需要重新构建仿真器。重复运行测试时，保持仿真器构建设置（例如
`--//hw:verilator_options` 和 `--//hw:make_options`）一致，以便复用 Bazel 缓存。
如果要预先单独构建仿真器，请确认构建配置与测试工具使用的配置相同；仅运行默认的
`bazel build //hw:verilator` 并不能保证配置一致。

### UART 冒烟测试运行记录（2026-10-12）

`//sw/device/tests:uart_smoketest_sim_verilator` 首次记录到的成功运行耗时约
792 秒。UART 控制台依次输出了以下信息：

```text
Running sw/device/tests/uart_smoketest.c
Finished sw/device/tests/uart_smoketest.c
PASS!
```

`opentitantool` 匹配到 `PASS!` 并返回 `ExitSuccess`，Bazel 也报告测试通过。此前
一次运行在默认的 `moderate` 时限（300 秒）到期后超时。因此，本次结果说明在当前
环境中该测试可能需要超过 300 秒；但它本身不能确定此前没有 UART 输出的具体原因。
成功运行时使用了 `--test_timeout=60,3000,15000,72000`；由于该目标属于 `eternal`
类别，实际 Bazel 上限是第四个值 72000 秒（20 小时）。测试本身运行约 792 秒后通过。

本次先执行了 `bazel build //hw:verilator`，随后 Bazel 在运行测试时又启动了
`Vchip_sim_tb [for tool]` 构建。测试使用的执行配置（`k8-opt-exec`）没有复用单独
构建得到的产物。第一次构建耗时约 4 小时 27 分钟；由测试触发的构建耗时约 4 小时
18 分钟。首次运行建议直接执行测试，让 Bazel 按测试需要构建模型；只有在单独
构建的配置与测试工具配置一致时，预先构建才有助于复用缓存。

运行日志提示 UART 输出也写入了 `uart0.log`，但测试结束后，Bazel 保留的测试输出中
没有该文件。保存的 `test.log` 包含控制台文本（包括 `PASS!`），但没有逐字节 UART
数据或波形。今后若需分析 UART 数据流，应在运行时设法保留仿真器 UART 日志或
采集信号轨迹。

本次调查期间加入的仿真进度心跳每 10,000,000 个周期输出一次。本次通过运行的保存
日志中没有心跳记录，因此这次运行没有通过该监控提供周期速度数据。

# 其他说明

<a id="troubleshooting-builds"></a>
## 构建故障排查

如果构建或运行任何 `bazel` 命令时遇到无法解释的错误，可以运行 `bazel clean` 清理已有构建目录，然后重新构建。
根据 Bazel 的[文档](https://docs.bazel.build/versions/main/user-manual.html#clean)，运行
```sh
bazel clean
```
会删除所有构建输出目录；运行
```sh
bazel clean --expunge
```
会清除 Bazel 生成的所有磁盘和内存痕迹（即缓存的中间文件）。只有在当前配置严重损坏且其他方法无效时，才应使用后一种彻底清理方式。

<a id="create-a-bazelrc-file"></a>
## 创建 `.bazelrc` 文件

可以在用户主目录中创建 `.bazelrc` 文件，以简化 Bazel 命令的执行。例如，可用它来：
* 设置[磁盘缓存](#disk-cache)；或
* 在没有 CW340 FPGA 时跳过对应测试。

实现上述配置的 `.bazelrc` 文件示例如下：
```
# Make Bazel use a local directory as a remote cache.
build --disk_cache=~/bazel_cache

# Skip CW340 FPGA tests, since I do not have said FPGA.
test --test_tag_filters=-cw340
```

更多示例请参阅 OpenTitan 仓库中的 [`.bazelrc`](https://github.com/lowRISC/opentitan/blob/master/.bazelrc) 文件。
其他信息请参阅 Bazel 的[文档](https://bazel.build/run/bazelrc)。

### 站点专用的 `.bazelrc-site` 选项

本文用“计算站点”指代某个开发主机，或更广义地指代由某个组织管理的一组计算节点；这些环境通常有各自的计算需求或 IT 策略。
此类环境的使用方式可能不同于常见的标准 Linux 发行版，因此在某些计算站点工作的团队成员可能需要使用略有不同的 Bazel 选项。

除了每位用户的 `$HOME/.bazelrc` 和项目级配置 [`$REPO_TOP/.bazelrc`](https://github.com/lowRISC/opentitan/blob/master/.bazelrc) 外，也可以在 `$REPO_TOP/.bazelrc-site` 文件中添加站点专用配置。

`.bazelrc-site` 文件可用于设置站点专用策略，例如：
- 指定构建产物的默认位置（例如，将 `--output_user_root` 或 `--output_base` 默认设置到 `$HOME` 文件系统之外）。
- 指定构建工具、库或软件包配置数据的非标准路径。

将 Bazel 选项写入该文件，可增加一层配置，方便同一计算站点的团队成员共享站点专用默认选项。

用户仍可在 `$HOME/.bazelrc` 中设置更细粒度的选项，并覆盖 `.bazelrc-site` 和 `$REPO_TOP/.bazelrc` 中的设置。
不过，`$HOME/.bazelrc` 并非 OpenTitan 专用配置，因此同时参与多个项目的用户可能会因此产生混淆。

不同贡献站点的策略和路径可能差异很大。
为避免站点之间意外冲突，`.bazelrc-site` 文件明确不纳入 Git 仓库；OpenTitan CI 脚本也会拒绝包含该文件的提交。

<a id="disk-cache"></a>
## 磁盘缓存

Bazel 可以将文件系统中的目录用作远程缓存。
这样可以在同一项目的多个 [`git` worktree](https://git-scm.com/docs/git-worktree) 或多个工作区（例如多个检出目录）之间共享构建产物。
切换芯片配置时也可以借助磁盘缓存保留构建产物；如果没有配置磁盘缓存，Bazel 往往需要从头重新构建。

使用 `--disk_cache=<filename>` 指定缓存目录。例如，运行
```sh
bazel build //... --disk_cache=~/.cache/bazel-disk-cache
```
会缓存所有已构建的产物。也可以像[上文](#创建-bazelrc-文件)所示，将以下内容加入 `$HOME/.bazelrc`，这样每次运行 Bazel 时都会自动使用磁盘缓存。

注意，Bazel 不会自动清理磁盘缓存。
可设置 cron 任务，定期删除一段时间内未访问过的缓存文件。
例如，使用 `crontab -e` 将以下命令及磁盘缓存路径加入 crontab，即可删除最后访问时间超过 60 天的文件。

```sh
0 0 * * 0 /usr/bin/find /path/to/disk/cache -type f -atime +60 -delete
```

关于 Bazel 磁盘缓存的更多说明，请参阅[官方文档](https://docs.bazel.build/versions/main/remote-caching.html#disk-cache)。

## 跳过 Verilator 仿真二进制文件构建

许多设备软件目标依赖 Verilator 仿真二进制文件，而该文件的构建耗时较长。
若要跳过仿真二进制文件的构建，可使用 `--define DISABLE_VERILATOR_BUILD=true` 选项。
例如，若要构建 UART 冒烟测试产物但跳过 Verilator 仿真二进制文件，可运行：
```sh
bazel build --define DISABLE_VERILATOR_BUILD=true //sw/device/tests:uart_smoketest
```

## 实时显示测试输出

默认情况下，Bazel 不会将测试输出写入 STDOUT。
若要实时查看测试输出，可使用 `--test_output=streamed` 参数，例如：
```sh
bazel test --test_output=streamed //sw/device/tests:uart_smoketest_fpga_cw340
```

## 筛选已知有问题的测试

有些测试被标记为已知有问题，正在等待分析处理。
批量运行测试时，可使用 `test_tag_filters=-broken` 跳过这些测试。
例如，在 FPGA 上运行除已知问题项外的所有芯片级测试：
```sh
bazel test --test_tag_filters=cw340,-broken //sw/device/tests/...
```

## 在 Git Worktree 中使用 Bazel

Bazel 并未针对 `git` worktree 工作流进行优化，不过 worktree 有助于管理分支，也可以同时运行多个 Bazel 作业。
以下建议可改善在 worktree 中使用 Bazel 的体验。

1. 按照[上文](#磁盘缓存)的说明启用磁盘缓存。
  Bazel 会在动作缓存中使用工作区路径。每个 worktree 都是路径不同的独立工作区，因此不同 worktree 不能共享动作缓存。
  但它们可以共享磁盘缓存，从而避免在不同 worktree 中重复构建相同产物。
  仓库缓存默认由所有工作区共享，无需额外配置。
1. 删除 worktree 前，务必运行 `bazel clean --expunge` 清理 Bazel 生成的文件。
  否则，旧 worktree 的文件可能会累积在用户输出根目录中（默认位于 `~/.cache/bazel/_bazel_${USER}/`）。

## 常见问题

### 找不到 ld

使用 Bazel 构建时可能遇到以下错误：
```sh
  = note: collect2: fatal error: cannot find 'ld'
          compilation terminated.
```

该问题与以下问题跟踪记录有关：
* [OpenTitan issue](https://github.com/lowRISC/opentitan/issues/12448)
* [Rust issue](https://github.com/bazelbuild/rules_rust/issues/1114)

具体来说，调用 `rustc` 编译器时会使用不受 Bazel 流程管理的 LLVM 链接器。
因此 Bazel 无法保证链接器安装在特定位置，只能使用主机上现有的版本。
上面的问题跟踪记录指出，`rustc` 预期链接器与 `gcc` 位于同一目录；如果主机不满足这一条件，构建就可能失败。

可通过以下任一方式解决：
1. 安装 LLVM 链接器，例如运行 `sudo apt install lld`。
2. 在 `gcc` 安装目录下为 `lld` 创建符号链接。

或者：
1. 将构建参数 `--@rules_rust//:extra_rustc_toolchain_dirs=/path/to/somewhere/else` 加入 `.bazelrc-site`，以指定系统中主机工具链工具所在的其他目录。

在 `rules_rust` 相关问题修复前，需要使用上述某种变通方案。
