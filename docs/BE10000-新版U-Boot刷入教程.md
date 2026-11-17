# 小米万兆 BE10000 新版 U-Boot 核实与刷入教程

> 适用对象：小米万兆路由器 BE10000（含零售版 RC01 与工程版 BE10000 ES），IPQ95xx 平台
> 配套固件：VIKINGYFY/OpenWRT-CI 编译的 `factory.ubi`（内核进 UBI、`KERNEL_IN_UBI` 布局）
> 核实日期：2026-11-17　｜　压缩包：`BE10000 新版 Uboot.zip`

---

## 一、先说结论（三句话）

1. **这个能救你之前的"刷完起不来"。** 它不是 QWRT 那套旧的不死 U-Boot，而是专门配合 `factory.ubi` 的**新版 U-Boot**：内部写死了 `root=mtd:ubi_rootfs rootfstype=squashfs`、`ubi read kernel`，并明确声明「NAND flash only supports UBI/FIT/SYSUPGRADE/QSDK firmware」。也就是说，它**认识**我们编译的 UBI 固件，启动方式对得上。你之前用旧 U-Boot 刷 `factory.ubi` 无限重启，极可能就是旧 U-Boot 按独立 kernel 分区去引导、和 UBI 布局不匹配导致的。
2. **但它的芯片标识是 IPQ9574，不是零售版 RC01 的 IPQ9570**，DT 里也没有 `config@al02-c4`（零售版用的配置）。压缩包自带的刷入脚本文件名是 `openwrt-ipq9574_xiaomi_be10000-u-boot.mbn`——它更像是给 **BE10000 ES（工程板，IPQ9574）或高通 al02 参考板**编译的。能不能在零售版 RC01 上稳启，目前没有第三方成功案例佐证，**请先当工程板/参考版 U-Boot 对待，零售版务必先备份再试**。
3. **教程里的文件名和压缩包里的文件名对不上，照抄会报错。** 见第五节的文件名陷阱表——以本教程的「实际文件名」为准。

---

## 二、压缩包内容与核实依据

| 文件 | 大小 | SHA256（前16位） | 作用 |
| --- | --- | --- | --- |
| `mibib.bin` | 1,048,576 B (1 MB) | `677a2e1d89c93c3` | 分区表（MIBIB），写入 `/dev/mtd2` |
| `uboot.mbn` | 520,684 B | `86092e052a2dcc73` | U-Boot 本体，MBN/ELF 格式，写入 `/dev/mtd18` |
| `readme.txt` | 239 B | — | 原作者简版说明 |
| `万兆新uboot刷入.txt` | 687 B | — | 原作者带备份的刷入脚本 |

对 `uboot.mbn` 二进制做字符串与 ELF 结构核实，得到以下硬证据：

| 核实项 | 结果 |
| --- | --- |
| 版本串 | `U-Boot 2016.01-20261103-r9-g1f0979a (Nov 03 2026 - 22:18:11 +0800)` |
| 编译时间 | 2026-11-03（很新） |
| ELF | ELF32 ARM EABI5，入口 `0x4a400000`，DYN 类型（高通 MBN  boot loader） |
| 机型字符串 | `Xiaomi BE10000`、`IPQ9574#`（U-Boot 提示符） |
| 芯片驱动串 | `ipq9574_edma_*`、`qcom,ipq9574-nand`、`active_port must be in the range of 0 to 5 in ipq9574 platform` |
| 内置 DT 配置 | `config@al02-c5/c6/c11/c12/c14/c15/c16/c20`（**无 `config@al02-c4`**） |
| 固件格式校验 | `* NAND flash only supports UBI/FIT/SYSUPGRADE/QSDK firmware, got: %s *` |
| 启动参数 | `ubi.mtd=rootfs root=mtd:ubi_rootfs rootfstype=squashfs`、`ubi part fs && ubi read ... kernel` |
| 启动命令 | `bootcmd=bootipq`（高通标准 nand 启动流程） |
| Web 界面 | 内置 httpd，含 `/uboot.html`、`/firmware.html`、`/mibib.html`；`ipaddr=192.168.1.1` |
| 双分区 | `rootfsname=rootfs` / `rootfsname=rootfs_1`，`0:APPSBL` / `0:APPSBL_1` 双 U-Boot 槽 |
| 支持命令 | `mibib_reload`（重读分区表）、`flash 0:APPSBL`、`ubi read/create/write` |

**解读**：

- `root=mtd:ubi_rootfs` + `ubi read kernel` = 内核和 rootfs 都放在 UBI 卷里 → 与 `factory.ubi` 完全同构。这是它与旧 QWRT U-Boot 的**本质区别**。
- 内置 httpd + `/uboot.html` + `/mibib.html` = 刷入新 U-Boot 后，可以像原厂教程一样进 Web 界面更新固件/分区表，readme 里说的「刷原来的 192.168.1.1/uboot.html 更新 mbn 格式的就行了」就是指这个。
- 芯片是 IPQ9574 + al02 系列 DT，**没有**零售版 `config@al02-c4` → 面向工程版/参考板概率大。

---

## 三、刷入前必读的风险

> ⚠️ 刷 U-Boot 和分区表是最高危操作，写错分区即变砖，且**原厂保修失效**。

1. **先分清机型**：零售版 RC01 是 IPQ9570、DT `config@al02-c4`；工程版 BE10000 ES 是 IPQ9574。本包二进制指向 IPQ9574，**工程版/ES 适配度更高**。零售版不是不能用，但风险自担。
2. **必须先备份 `mtd2`（分区表）和 `mtd18`（U-Boot）**，且备份文件要传回电脑另存。没有备份就不要开始。
3. **分区表会被改写**：新 `mibib.bin` 重定义分区布局，刷完后**旧固件不能再用**，必须重新在 U-Boot 里刷入匹配新布局的 `factory.ubi`（见第六节）。
4. **断电时机**：`mtd write` 完成后不要立刻断电，等待至少 30 秒让写入落盘。
5. **准备 UART 串口**：TTL 转串口（115200）是最后一道救砖手段，强烈建议刷前接好。
6. **固件必须用 `factory.ubi`**，不能用 `sysupgrade.bin` 在 U-Boot 里刷；后者是给已进 OpenWrt 后 web 升级用的。

---

## 四、刷入前准备

1. 路由器当前能正常开机，且能 SSH 登录（原厂解锁 SSH 后是 `192.168.31.1`，旧 OpenWrt 一般是 `192.168.1.1`，账号 `root`）。
2. 电脑用网线连路由器 LAN 口。
3. 把第四节的两个文件 `mibib.bin`、`uboot.mbn` 上传到路由器的 `/tmp/` 目录（用 WinSCP/MobaXterm 的 SFTP）。
4. 准备串口线备用。

---

## 五、⚠️ 文件名陷阱（最易踩坑）

压缩包里三处文件名**互相矛盾**，照任意一份原文抄都会提示 `No such file or directory`：

| 来源 | 分区表（→ mtd2） | U-Boot（→ mtd18） |
| --- | --- | --- |
| `readme.txt` 写的 | `mibib.mbn` ❌ | `uboot.bin` ❌ |
| `万兆新uboot刷入.txt` 写的 | `mtd2_0MIBIB.bin` ❌ | `openwrt-ipq9574_xiaomi_be10000-u-boot.mbn` ❌ |
| **压缩包里真实存在的文件** | **`mibib.bin`** ✅ | **`uboot.mbn`** ✅ |

**本教程统一用真实文件名 `mibib.bin` 和 `uboot.mbn`。** 上传后请 `ls -l /tmp/` 确认文件名一致。

---

## 六、刷入步骤（SSH 命令行）

### 6.1 备份当前分区（务必先做）

```sh
# 备份当前分区表和 U-Boot
dd if=/dev/mtd2  of=/tmp/mtd2_backup_before_flash.bin
dd if=/dev/mtd18 of=/tmp/mtd18_backup_before_flash.bin

# 记录校验值，确认备份完整
md5sum /tmp/mtd2_backup_before_flash.bin /tmp/mtd18_backup_before_flash.bin
ls -l /tmp/mtd2_backup_before_flash.bin /tmp/mtd18_backup_before_flash.bin
```

> 立刻用 SFTP 把这两个 `*_backup_before_flash.bin` 下载到电脑保存。这是你唯一的后悔药。

### 6.2 核对新文件校验值

```sh
md5sum /tmp/mibib.bin /tmp/uboot.mbn
```

应得到：

```
fcb1b4273c60d0eea4608e746c688c83  /tmp/mibib.bin
6e1e9fd1dccdd8b9d202c332fcaad9fb  /tmp/uboot.mbn
```

不一致说明文件传输出错，重新上传。

### 6.3 确认分区编号

```sh
cat /proc/mtd
```

确认 `mtd2` 和 `mtd18` 存在且大小合理（分区表通常 1 MB，U-Boot 分区几百 KB～1 MB）。**不同固件/分区表下编号可能变化，务必以实际输出为准**——若 `mtd18` 不存在或大小明显不对，停止操作。

### 6.4 写入新分区表和新 U-Boot

```sh
# 1. 刷入分区表
mtd write /tmp/mibib.bin /dev/mtd2

# 2. 刷入 U-Boot 本体
mtd write /tmp/uboot.mbn /dev/mtd18

# 3. 校验写入是否成功
mtd verify /tmp/mibib.bin /dev/mtd2
mtd verify /tmp/uboot.mbn /dev/mtd18
```

`mtd verify` 无报错即写入成功。**写完后不要断电，等待 30 秒**。

---

## 七、刷完 U-Boot 后：重新刷入固件

新分区表改变了布局，旧固件不再适用，需要在 U-Boot 里重新刷入 `factory.ubi`：

1. 路由器**断电 10 秒**。
2. **按住 Reset 键不松手**，插上电源，保持按住约 15～20 秒，直到指示灯由白色闪烁变为橙色常亮/长亮后松手。
3. 电脑网线接 LAN 口，本地 IP 设为 `192.168.1.x`（如 `192.168.1.10`，掩码 `255.255.255.0`）。
4. 浏览器打开 `http://192.168.1.1`，进入 U-Boot Web 界面（内置 httpd，含 `/uboot.html`、`/firmware.html`、`/mibib.html`）。
5. 选择固件文件 **`<设备>-squashfs-factory.ubi`**（不是 sysupgrade），点击 Update，等待约 2 分钟。
6. 完成后改回自动获取 IP，浏览器打开 `http://192.168.1.1`（或 `192.168.31.1`）进入 OpenWrt，账号 `root`。

readme 里那句「写入后需要重新在 uboot 刷入固件 / 刷原来的 192.168.1.1/uboot.html 更新 mbn 格式的就行了」正是这个意思：新 U-Boot 已内置 Web 刷机界面，走原厂那套流程即可。

> 备选：若更习惯命令行，可在 U-Boot 控制台（UART）用
> `tftpboot <tftp服务器IP>:factory.ubi` → `flash rootfs` → `flash rootfs_1` → `reset`，
> 或进 initramfs 临时系统后用 `ubiformat` 写两个 rootfs 槽（详见《BE10000-U-Boot兼容性与启动故障排查.md》第七节）。

---

## 八、救砖与回退

如果刷完无法启动/进不了 U-Boot Web：

1. **先做物理排查**：断电重插、换 LAN 口、确认电脑 IP 是 `192.168.1.x`、Reset 按键时机是否正确。
2. **UART 看日志**：接串口（115200），看卡在哪一步。若提示 `ubi` 相关错误 → 固件/分区布局不匹配；若完全无输出 → U-Boot 损坏。
3. **刷回原厂 U-Boot**（用第六节备份的文件，在能进旧 U-Boot Web 或 SSH 的前提下）：
   ```sh
   mtd erase /dev/mtd2
   mtd write /tmp/MIBIB.bin  /dev/mtd2     # 原厂分区表备份
   mtd erase /dev/mtd18
   mtd write /tmp/APPSBL.bin /dev/mtd18    # 原厂 U-Boot 备份
   ```
   然后用**小米路由器修复工具**（MIWIFIRepairTool）恢复原厂固件（可恢复到最新版， telnet 仍在）。
4. **仍无法恢复**：本 U-Boot 面向 IPQ9574 al02 参考板，零售版 RC01 刷入需谨慎；建议向固件作者（恩山 thread-8497379、README 首行「IPQ 技术讨论群」QQ 群）确认有无 RC01 专用 U-Boot 与配套刷机包。

---

## 九、与旧版 U-Boot 的区别（为什么这次可能成功）

| 对比项 | 旧 QWRT 不死 U-Boot | 本新版 U-Boot |
| --- | --- | --- |
| 固件类型 | 独立 `.bin`（kernel 单独分区） | `factory.ubi`（内核进 UBI，`KERNEL_IN_UBI`） |
| 启动参数 | 独立 kernel 分区引导 | `root=mtd:ubi_rootfs` + `ubi read kernel` |
| 格式校验 | 认 `.bin` | 明确支持 `UBI/FIT/SYSUPGRADE/QSDK` |
| 分区布局 | QWRT 大分区 | 原厂双 rootfs 槽（rootfs/rootfs_1）+ 双 APPSBL |
| 刷 `factory.ubi` 结果 | 布局不匹配 → 无限重启 | 布局匹配 → 可正常引导 |

这也解释了为什么之前优先建议"不换 U-Boot，走原厂双槽布局"——本包正是那条路线所需的 U-Boot 实现。

---

## 十、文件清单

教程与 U-Boot 文件已随本仓库一并提供：

- `docs/BE10000-新版U-Boot刷入教程.md`（本文档）
- `u-boot/BE10000/mibib.bin`
- `u-boot/BE10000/uboot.mbn`
- `u-boot/BE10000/readme.txt`（原作者说明，文件名有误，仅参考）
- `u-boot/BE10000/万兆新uboot刷入.txt`（原作者脚本，文件名有误，仅参考）

本地副本：`/workspace/BE10000-新版U-Boot/`、`/workspace/BE10000-新版U-Boot刷入教程.md`

---

## 参考来源

- 用户提供的 `BE10000 新版 Uboot.zip`（二进制字符串与 ELF 结构实机核实）
- 上游源码 `VIKINGYFY/immortalwrt@owrt` `target/linux/qualcommbe/image/ipq95xx.mk`（零售版 `xiaomi_be10000` = IPQ9570 + `config@al02-c4`；ES 版 = IPQ9574）
- 恩山 [thread-8497379](https://www.right.com.cn/forum/thread-8497379-1-1.html) VIKING_YFY BE10000/BE10000 ES 首发帖
- 恩山 [thread-8410120](https://www.right.com.cn/forum/forum.php?authorid=804479&mod=viewthread&tid=8410120) 恢复原厂 U-Boot 教程
- [getpicion.com/archives/6950](https://www.getpicion.com/archives/6950) BE10000 RC01 刷机教程（uboot 版 + 恢复原厂）
- U-Boot 官方 [Qualcomm RDP 文档](https://u-boot.readthedocs.io/en/stable/board/qualcomm/rdp.html)（IPQ9574 用 `elftombn.py -v6` 生成 `u-boot.mbn`，写入 `0:APPSBL`）
