# 系统虚拟内存（Swap）扩容与维护指南

## 1. 背景与扩容原因

在低内存环境中，通过 Verilator 构建 OpenTitan 顶层 SoC（Earl Grey）可能因内存不足而触发 OOM，导致构建进程被终止。实际内存需求取决于构建配置和宿主机资源；Swap 可以提供额外的内存压力缓冲，但速度通常低于物理内存。

---

## 2. 当前 Swap 配置与持久化生效状态

以下配置记录适用于曾使用的构建环境，不代表其他主机的当前状态。该环境新增了 **10 GB** 的 Swap 文件：

| 交换文件/分区 | 大小 | 路径 | 作用 |
| :--- | :--- | :--- | :--- |
| **原生交换分区** | 约 1.5 GB | `/dev/vda3` | 环境记录值 |
| **首次追加 Swap** | 6.0 GB | `/swapfile_extra` | 满足基础生成阶段内存开销 |
| **二次追加 Swap** | 4.0 GB | `/swapfile_extra2` | 满足复杂芯片多模块并发分析峰值缓冲 |
| **总计 Swap 容量** | 约 **11.5 GB** | - | 环境记录值；实际容量请在目标主机检查 |

### 配置持久化
若要在重启后自动启用 Swap 文件，可在目标主机确认文件存在且配置正确后，将对应条目加入 `/etc/fstab`：
```text
/swapfile_extra none swap sw 0 0
/swapfile_extra2 none swap sw 0 0
```
添加条目前请先检查是否已有重复条目。容器或云主机的启动方式可能影响 `/etc/fstab` 的生效情况；配置后应按目标环境验证，不能假设重启后必定生效。

---

## 3. 日常维护操作（查看、启停与释放）

### 3.1 查看当前内存与 Swap 使用状态
```bash
# 查看内存总量及使用概览
free -h

# 查看各个 Swap 分区/文件的详细使用与优先级
swapon --show
```

---

### 3.2 临时关闭 / 重新开启 Swap
如果需要临时调试，可以在不删除文件的情况下启停扩展的 Swap：

* **临时停用扩展 Swap**：
  ```bash
  swapoff /swapfile_extra /swapfile_extra2
  ```
* **重新启用扩展 Swap**：
  ```bash
  swapon /swapfile_extra /swapfile_extra2
  ```

---

### 3.3 完全卸载并释放磁盘空间（如将来不再需要）
如果后续迁移至大内存服务器，或者磁盘空间紧张需要回收这 10 GB 存储空间，请按如下规范操作：

1. **先关闭 Swap 挂载**：
   ```bash
   swapoff /swapfile_extra /swapfile_extra2
   ```
2. **删除持久化配置**：
   编辑 `/etc/fstab`，删除或注释掉以下两行：
   ```text
   /swapfile_extra none swap sw 0 0
   /swapfile_extra2 none swap sw 0 0
   ```
3. **彻底删除交换文件**：
   ```bash
   rm -f /swapfile_extra /swapfile_extra2
   ```
4. **验证释放结果**：
   ```bash
   free -h
   df -h /
   ```
