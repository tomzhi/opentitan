# Verilator 多版本共存与灵活切换指南

## 1. 系统中安装的版本分布

当前系统中保留了两个完全独立的 Verilator 版本：

| 版本 | 安装路径 | 适用场景 |
| :--- | :--- | :--- |
| **Verilator 4.210** | `/tools/verilator/v4.210/bin/verilator` | **OpenTitan 专用**（解决 `%Error-NEEDTIMINGOPT` 语法冲突） |
| **Verilator 5.020** | `/usr/bin/verilator` | **其他主流芯片开源项目**（支持现代 SV 特性、时序模拟等） |

---

## 2. 全局快速切换方法（内置命令行工具）

系统中已配置全局切换脚本工具 [`/usr/local/bin/switch-verilator`](file:///usr/local/bin/switch-verilator)。在任意终端目录下均可直接执行：

### 2.1 切换到高版本（Verilator 5.020）
用于运行需要现代 Verilator 5.x 的项目：
```bash
switch-verilator 5
```
*(或者执行 `switch-verilator system`)*

### 2.2 切换回 OpenTitan 兼容版本（Verilator 4.210）
用于运行或构建 OpenTitan：
```bash
switch-verilator 4
```
*(或者执行 `switch-verilator opentitan`)*

### 2.3 查看当前激活的版本
不带参数执行即可显示当前生效的版本和使用帮助：
```bash
switch-verilator
```
或直接通过标准命令验证：
```bash
verilator --version
```

---

## 3. 项目级临时切换方法（不影响系统全局其他任务）

如果需要在不同终端窗口同时运行多个项目，不想频繁更改系统全局的 `/usr/local/bin` 软链接，可以通过指定当前 Shell 的局部 `PATH` 实现隔离：

### 3.1 仅在当前会话临时使用高版本 (v5.020)
在其他项目的终端窗口执行：
```bash
export PATH=/usr/bin:$PATH
verilator --version
```

### 3.2 仅在当前会话临时使用 OpenTitan 版本 (v4.210)
```bash
export PATH=/tools/verilator/v4.210/bin:$PATH
verilator --version
```

---

## 4. 原理说明
* Linux 执行程序时按环境变量 `$PATH` 顺序查找。默认查找顺序中 `/usr/local/bin` 优先于 `/usr/bin`。
* `switch-verilator 4` 会在 `/usr/local/bin` 下建立指向 `/tools/verilator/v4.210/bin/` 的软链接，从而拦截并优先使用 v4.210。
* `switch-verilator 5` 会移除 `/usr/local/bin` 下的软链接，系统自动回退使用 `/usr/bin/verilator`（即 apt 安装的原生 v5.020）。两个版本的二进制文件实体均完整保留，切换零损耗、秒级生效。
