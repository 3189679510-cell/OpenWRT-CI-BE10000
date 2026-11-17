# 小米万兆路由器 BE10000：旧版 U-Boot 兼容性与「刷完无法启动」排查

> 核查日期：2026-11-17 · 对象：`VIKINGYFY/OpenWRT-CI` 编译的 `xiaomi_be10000` 固件
> 结论基于上游 `VIKINGYFY/immortalwrt@owrt` 源码、社区刷机教程原文、项目作者 Issue 答疑、
> 以及同平台（IPQ95XX / BE7000）官方 OpenWrt 安装说明，不是经验猜测。

---

## 一、先给结论

**问：这些固件旧版 U-Boot 能不能刷？**

**答：大概率不能直接用，而且这很可能就是你「刷好后无法启动」的主因。**

更准确地说，问题不在「U-Boot 新旧」，而在**一整套引导约定是否匹配**：
`U-Boot + mibib 分区表 + 启动参数（bootargs / nvram 启动标志）` 必须与
`固件的镜像格式 + UBI 卷布局 + 分区布局` 一致。本项目固件和社区流传的
「恩山 / QWRT 不死 U-Boot」是**两套不同的引导约定**。

| 项 | 本项目 BE10000 固件 | 社区旧版第三方 U-Boot（教程那套） |
| --- | --- | --- |
| 首次刷入文件 | `squashfs-factory.ubi`（UBI 镜像） | QWRT 格式的 `.bin`（教程写「选择 openwrt 最新固件」、恢复原厂用 `rootfs.bin`） |
| 内核位置 | **在 UBI 卷里**（`KERNEL_IN_UBI := 1`，vol0=`kernel` FIT 镜像） | 独立 `kernel` MTD 分区（原厂 mtd30） |
| 根文件系统 | `root=/dev/ubiblock0_1`（UBI vol1=`rootfs`） | 原厂 `ubi_rootfs` 卷（mtd31） |
| 分区表来源 | `qcom,smem-part`（由 bootloader/SMEM 动态提供） | 刷入的第三方 `mibib.bin` 静态改写 |
| 启动方式 | 依赖 U-Boot 传 `ubi.mtd=...`，固件侧用 `fw_setenv` 切启动槽 | QWRT 双槽 `rootfs` / `rootfs_1` + 自己的启动标志 |
| U-Boot 环境工具 | **默认内置 `uboot-envtools`** | 不一定提供 |

**三条硬证据：**

1. 上游设备定义 `target/linux/qualcommbe/image/ipq95xx.mk`：
   `xiaomi_be10000-common` 用 `Device/FitImage` + `Device/UbiFit`，
   且 `DEVICE_PACKAGES` 里带 **`uboot-envtools`**；DTS 里是
   `bootargs-append = " root=/dev/ubiblock0_1 cma=320M"`（注意是 **append**，即依赖
   U-Boot 原有启动参数），分区用 `compatible = "qcom,smem-part"`。
   → 这套固件是**按小米原厂 U-Boot / 原厂分区布局设计的**，靠 `fw_setenv` 切槽启动，
   不是给「换掉 U-Boot 的第三方不死 U-Boot」用的。

2. 上游首次加入 BE10000 支持的提交 `3205cb9a`（2026-10-26），14 个改动文件里
   **专门修改了 `package/boot/uboot-tools/uboot-envtools/files/qualcommbe_ipq95xx`**
   和 `base-files/lib/upgrade/platform.sh`（BE10000 走 `nand_do_upgrade`）。
   → 作者明确预期要读写 U-Boot 环境变量、用 UBI 方式升级。

3. 同平台官方安装说明（Xiaomi BE7000 OpenWrt Installer，同为 `qualcommbe/ipq95xx`）：
   > `factory.ubi` → **从原厂固件 SSH shell 手动刷入**（`ubiformat /dev/mtdX -y -f factory.ubi`）
   > `sysupgrade.bin` → 仅用于 OpenWrt 内 sysupgrade
   > **"Do not write sysupgrade.bin directly to rootfs or rootfs_1 from stock firmware"**
   > **"The Xiaomi web updater is not suitable for these OpenWrt images."**
   > "The Xiaomi bootloader expects a UBI image in the selected firmware slot."
   > 小米是双槽 A/B，刷完必须设 `flag_boot_rootfs=1` 等一整套 nvram 标志才会从新槽启动；
   > 文档明确建议备好 UART 以便救砖。

4. **项目作者自己的答疑**（Issue #290，AX3600 云编译固件无法启动）：
   > 「下错文件了，需要刷带 stock 的版本」
   > 「你刷的这俩都是适配原分区的，既然无法启动你得刷 ax3600-stock 大分区版」
   > 「如果刷的恩山 wwk0831 分享的 uboot 和 mibib 分区文件（此版本流传度最广），
   > **只能刷 stock 原厂分区布局格式的固件才能启动**」

   → 一句话：**刷了哪套 uboot/mibib，就只能刷对应分区布局的固件，不匹配必起不来。**

5. 项目里还有一个几乎和你情况一模一样的 Issue #426（BE6500，同 qualcommbe 平台）：
   「刷入后无法开机，LED 一直橙色，以太网显示未识别的网络，无 IP 分配，手动静态 IP 也没用，
   **Uboot 用的是恩山论坛大佬发的版本，已经刷了大佬的 MIBIB**」——提问者自行关闭，没有解法。
   Issue #322（7dr-7299 刷入后好像不能开机）同类。

---

## 二、还有一个被忽略的关键点：固件体积

这次核查发现一个之前没注意到的数字差异，很可能就是**第二个独立故障源**：

| 固件 | `factory.ubi` | `sysupgrade.bin` |
| --- | --- | --- |
| 11-15 20:44:51 标准版（你仓库里） | **64.0 MB** | 61.6 MB |
| 11-15 21:47:41 带 openclash / adguardhome / lucky | **87.2 MB** | 84.1 MB |
| 官方 11-16 Release 标准版 | 64.0 MB | 61.6 MB |

而社区教程里原厂分区表显示 `rootfs` = `0x3c00000` = **60 MB**、`rootfs_1` 同为 60 MB、
`overlay` = 70 MB。也就是说：

- 官方标准版 64 MB 是这套固件**预期的正常体积**；
- 加了三个插件后涨到 **87.2 MB，比标准版多 23 MB**，明显超出常规 rootfs 槽位容量；
- 上游 `append-ubi` 的尺寸校验（`UBI_NAND_SIZE_LIMIT`）**只在同时定义 `IMAGE_SIZE` 和
  `NAND_SIZE` 时才生效**，而 BE10000 设备定义里两者都没写 → **编译时不会拦截超大镜像**，
  87 MB 照样编出来、照样发 Release，但刷的时候可能写不下或被截断。

> 注意：刷入第三方 `mibib.bin` 后分区表会变（很多第三方 U-Boot 会改成「大分区」），
> 60 MB 是教程里在原厂系统下看到的数值，**具体容量必须以你机器重启后实际的
> `cat /proc/mtd` 为准**。但 87 MB vs 官方 64 MB 这个差距本身就是高风险信号。

**由此得到的实用建议：先用不带插件的标准版（64 MB）验证 U-Boot 能否正常引导，
确认能启动之后，再考虑插件版。** 你仓库里 `IPQ95XX-VIKINGYFY-owrt-26.11.15-20.44.51`
这个 Release 就是现成的标准版，不用重编。

---

## 三、「刷完无法启动」分步排查（按顺序做，别跳步）

### 第 0 步：先排除「假砖」——这是作者官方点名的现象

项目置顶 Issue #348《常见问题汇总》原文：

> **「UBOOT 下升级完固件后网口获取不到 IP → 断电重启即可。」**

「灯亮着但电脑拿不到 IP / 显示未识别网络」很多时候**并不是没启动**，只是这次
U-Boot 刷完后网口状态没刷新。

```
1. 拔电源，等 30 秒以上（教程要求 10 秒，保守点更好）
2. 只接一根网线到 LAN 口，电脑设静态 IP 192.168.10.2 / 255.255.255.0
3. 上电，等 3~5 分钟（首次启动要生成配置、初始化 WiFi，别急）
4. 分别试：
   - 192.168.10.1   ← 本项目固件的管理地址（无密码）
   - 192.168.1.1    ← 第三方 U-Boot 的 Web 恢复界面
   - 192.168.31.1   ← 小米原厂
5. ping 一下上述地址
```

> 别把三个地址搞混：**U-Boot 恢复界面 192.168.1.1，本项目固件 192.168.10.1，
> 原厂 192.168.31.1**。很多人「刷完进不去」其实是访问错了地址。

### 第 1 步：判断是「假砖」还是「真砖」

| 现象 | 判断 | 能不能救 |
| --- | --- | --- |
| 断电重启后能 `ping` 通、能进 `192.168.1.1` 的 U-Boot Web | 引导层还在，**假砖** | 能，直接重刷正确的文件即可 |
| 灯有规律变化、能进 U-Boot，但刷任何固件都起不来 | 固件与分区布局不匹配 | 能，换匹配布局的固件 / 换回原厂 U-Boot |
| 灯常亮橙色 / 全灭、网口完全无响应、Reset 进不去 U-Boot | 分区表或引导区被写坏 | 需要 UART 串口，或小米官方恢复工具 |

### 第 2 步：确认你上次刷的是哪个文件（最常见的错）

- ✅ 首次从 U-Boot / 原厂刷入 → 只能用 **`...-squashfs-factory-....ubi`**
- ❌ `...-squashfs-sysupgrade-....bin` **只能**在已经跑起来的 OpenWrt 里用
  （LuCI「系统 → 备份/升级」或 `sysupgrade -n /tmp/xxx.bin`）。
  把它直接写进 `rootfs` 分区是同平台官方安装说明**明确禁止**的操作，必然起不来。
- ❌ 把 `.ubi` 传给一个只认 QWRT `.bin` 的旧 U-Boot Web 界面：多数会被拒或按错误
  布局写入，刷完看起来"成功"，实际 U-Boot 找不到内核。

### 第 3 步：确认机型没刷错

| 设备 ID | SoC | 对应硬件 | 固件名特征 |
| --- | --- | --- | --- |
| `xiaomi_be10000` | IPQ9570 | 零售版 RC01（绝大多数） | 不带 `-es` |
| `xiaomi_be10000-es` | IPQ9574 | ES / 后续改动版 | 带 `-es` |

你编译的是 **`xiaomi_be10000`（零售版）**。如果机器实际是 ES 版，
DTS、WiFi 板级数据、分区都不同，**刷错基本必砖**。解锁 SSH 后 `dmesg | grep -i ipq95`
可确认。

### 第 4 步：确认 U-Boot / mibib 的分区布局

进到能操作的 shell 后：

```sh
cat /proc/mtd                     # 看实际分区名与大小，别照抄教程
nvram get flag_boot_rootfs        # 原厂双槽当前启动槽（0/1）
cat /proc/cmdline                 # 看 ubi.mtd= 指向哪个分区
fw_printenv                       # 本项目固件里可读 U-Boot 环境变量
```

**如果 `cat /proc/mtd` 里出现 `kernel` / `ubi_rootfs` / `cfg` / `user` / `plugin`
这类原厂 QSDK 卷名，说明你刷的是原厂布局或 QWRT 布局的 mibib，
与本项目的 UbiFit 布局不是一回事。**

### 第 5 步：上 UART 串口（唯一能定性的手段）

不接串口，前面所有判断都只是推测。BE10000 需拆机接 TTL（3.3V，115200 8N1），
抓 U-Boot 阶段日志，看它报的是哪一种：

| 串口日志关键字 | 含义 |
| --- | --- |
| `Bad Magic Number` / `Wrong Image Type` | 镜像格式不对，U-Boot 不认识你刷进去的文件 |
| `ubi` / `UBI error` / `no valid UBI` | UBI 镜像没写进正确分区，或分区太小被截断 |
| `Kernel panic - not syncing: VFS` | 内核起来了但挂不上 rootfs，多半是 bootargs / 卷名不匹配 |
| `Starting kernel ...` 后无输出 | 内核加载地址 / 设备树 / DDR 初始化不匹配 |

---

## 四、正确的刷入路径（两条，按你的实际情况选）

> ⚠️ 以下涉及写 flash，写错分区即砖。**务必先确认已有原厂完整备份**
> （`mtd2` MIBIB、`mtd18` APPSBL、以及各分区镜像），并确认能进恢复模式。

### 路径 A（推荐）：恢复小米原厂 U-Boot，用 SSH + ubiformat 刷

这是与本项目固件设计最匹配的方式（同平台 BE7000 官方 installer 的做法）。

```sh
# 1. 若已刷第三方 U-Boot，先按教程刷回原厂 mtd2 / mtd18 备份，重启
#    （教程里的恢复命令，文件名以你自己的备份为准）
mtd write /tmp/mtd2_0MIBIB.bin  /dev/mtd2
mtd write /tmp/mtd18_0APPSBL.bin /dev/mtd18
reboot

# 2. 解锁原厂 SSH，把 factory.ubi 传进 /tmp
#    scp -O ...-xiaomi_be10000-squashfs-factory-....ubi root@192.168.31.1:/tmp/openwrt.ubi

# 3. 核对分区与当前启动槽（关键！）
cat /proc/mtd
nvram get flag_boot_rootfs
cat /proc/cmdline

# 4. 把 UBI 镜像写入「非当前启动」的那个 rootfs 槽（保留原厂可回滚）
ubiformat /dev/mtdXX -y -f /tmp/openwrt.ubi     # mtdXX 必须按实际 /proc/mtd 填

# 5. 切换启动标志（原厂 nvram 版本）
nvram set flag_boot_rootfs=1
nvram set flag_last_success=1
nvram set flag_boot_success=1
nvram set flag_try_sys1_failed=0
nvram set flag_try_sys2_failed=0
nvram set flag_ota_reboot=0
nvram commit
reboot
```

> 上面第 5 步来自同平台 BE7000 官方 installer，**BE10000 的标志位名称未经实测确认**，
> 请以串口输出和 `fw_printenv` 实际内容为准；不确定的话先在作者 QQ 群确认。

### 路径 B：换成与本项目固件布局匹配的 U-Boot

项目 README 的 `# U-BOOT` 章节给了 4 个链接，但之前已核查过：

| 链接 | 实际支持范围 | 支持 BE10000？ |
| --- | --- | --- |
| 高通版-沉心 `chenxin527/uboot-qsdk12.5-build` | 最高 ipq807x | ❌ 无 IPQ95XX |
| 高通版-小猪 `1980490718/u-boot-2016` | 最高 IPQ9574，设备表只有 `ipq9574_xiaomi_be7000` | ❌ 无 IPQ9570 / BE10000 |
| 联发科-全新版 `VIKINGYFY/UBOOT-CI` | 仅 MEDIATEK | ❌ |
| 联发科-官方版 `drive.wrt.moe/uboot/mediatek` | 联发科 | ❌ |

**项目本身没有为 BE10000 提供配套 U-Boot**，作者唯一的官方答疑渠道是 README 首行的
「IPQ 技术讨论群」QQ 群。刷 U-Boot 前建议先去群里确认当前 BE10000 推荐用哪一套，
以及配套的 mibib 分区表——这比自己试错安全得多。

### 之后在系统内升级（这才是「升级固件」的正确动作）

一旦 OpenWrt 正常跑起来，后续升级就简单了，用 `sysupgrade.bin`：

```sh
scp ...-xiaomi_be10000-squashfs-sysupgrade-....bin root@192.168.10.1:/tmp/fw.bin
ssh root@192.168.10.1 'sysupgrade -n /tmp/fw.bin'
```

或在 LuCI「系统 → 备份/升级」上传。**千万不要再从 U-Boot 里刷 sysupgrade.bin。**

---

## 五、本次「升级固件」做了什么

已在你账号 `kyxing107/OpenWRT-CI-BE10000` 触发新编译：

| 项 | 值 |
| --- | --- |
| 运行 | [QCB-ALL #43993194873](https://github.com/kyxing107/OpenWRT-CI-BE10000/actions/runs/43993194873) |
| 触发 | 2026-11-17 09:08（北京时间），`TEST=false` 正式编译 |
| 源码 | 实时 clone 上游 `immortalwrt@owrt` HEAD `29b2b32fd0`（11-16 17:47 UTC） |
| 配置 | 零售版单设备 `xiaomi_be10000` + 三个插件（openclash / adguardhome / lucky） |
| 状态 | 编译中，约 40~60 分钟出固件 |

相对 11-15 版（`1f21e82da2`）共 **30 个新提交**，与 BE10000 实际相关的：

- `dd9292367f` 把 **NFC 标签管理**并入 `luci-app-xiaomi-control`（风扇/RGB 控制页）
- `ebd9072b33` 同步 Xiaomi Control 的 LuCI 翻译
- `2238d9bd73` 2.5G QCA8081 PHY 优先选 master；`4ae505bf2f` 修正以太网端口时钟父节点
- `dcfaa8b344` 优先使用已安装的 ath11k 校准数据
- `3b619d935a` 修正 SONiC fullcone 入站元组方向（与默认 `fullconenat-sonic` 相关）
- 一批 PPE QoS / CAKE / EDMA / TBF 性能与稳定性修复（硬件加速路径）
- 其余为 Arista AP 平台、蓝牙 UART、TPM/RTC 等，与 BE10000 无关

内核仍是 6.18.60，插件仍是 18 个 LuCI 包。

> ⚠️ **重要**：这次升级**仍带三个插件，固件体积仍会接近 87 MB**。如果第二节判断的体积
> 问题成立，新固件一样刷不进去。升级解决的是「源码版本新」，**不解决 U-Boot 兼容和体积问题**。

---

## 六、给你的下一步建议（按优先级）

1. **先按第三节第 0 步断电重启 + 试三个管理地址**，很多「无法启动」到这步就解决了。
2. **用现成的标准版固件验证**：下载 `IPQ95XX-VIKINGYFY-owrt-26.11.15-20.44.51`
   里的 `...-xiaomi_be10000-squashfs-factory-....ubi`（64 MB），重刷一次。
   如果标准版能起、插件版不能起 → 就是体积/插件问题，先别加插件。
3. **如果标准版也起不来 → 基本可确定是 U-Boot / mibib 布局不匹配**，走第四节路径 A
   或先去作者 QQ 群确认配套 U-Boot。
4. **真砖别硬刷**：接 UART 看日志，或用小米官方恢复工具刷回原厂开发版再重来。
5. 需要的话我可以**再编一份去掉三个插件的最新精简版**（约 64 MB，带 11-16 上游更新）
   作为对照固件，专用于排查启动问题——说一声即可，不会动你现有配置。

---

## 附：本次核查依据

- 上游源码：`ipq95xx.mk`、`include/image-commands.mk`（`append-ubi`）、
  `scripts/ubinize-image.sh`（卷布局）、`ipq9570-be10000.dts`（bootargs / smem-part）、
  `base-files/lib/upgrade/platform.sh`（`nand_do_upgrade`）
- 上游提交：`3205cb9a`（加入 BE10000 支持，含 uboot-envtools 配置）
- 项目作者答疑：Issue #348（常见问题汇总）、#290（AX3600 无法启动，stock/大分区结论）、
  #426（BE6500 无法开机，同为恩山 U-Boot + MIBIB）
- 社区教程：勇爱设计《BE10000 RC01 刷机教程 uboot 版 + 恢复原厂》原文
  （`mibib.bin` 写 mtd2、`uboot.bin` 写 mtd18、`cat /proc/mtd` 分区表、
  U-Boot Web 192.168.1.1、刷 `.bin`、恢复用 `rootfs.bin`）
- 同平台官方安装说明：`kravasuper/xiaomi-be7000-openwrt-installer`（factory.ubi 只能
  SSH + ubiformat 刷、禁止直写 sysupgrade.bin、双槽 A/B + nvram 启动标志、需 UART 救砖）

---

## 七、11-17 追加核查：「有没有新 U-Boot / 刷入方法」

> 触发问题：上一轮结论是「旧版不死 U-Boot 不能用」，用户追问「新 UBOOT 有刷入方法吗」。
> 本节把项目 README 里 4 个 U-Boot 链接逐个扒了设备表，并补查作者本人首发帖与社区自研进度。

### 7.1 结论

**「刷入方法」有，但「适配 BE10000 零售版（IPQ9570 / RC01）的新 U-Boot 成品」目前没有。**
更重要的是：**这套固件本来就不需要换 U-Boot**，正确解法是保留 / 恢复原厂 U-Boot，
按原厂双槽布局刷 `factory.ubi`。继续找「新 U-Boot」是走偏了。

### 7.2 README 四个链接逐个核实（2026-11-17）

| 来源 | 实际支持范围 | BE10000 零售版？ |
| --- | --- | --- |
| 高通版-沉心 `chenxin527/uboot-qsdk12.5-build`（uBootKit） | 平台仅 `ipq50xx / ipq53xx / ipq60xx / ipq807x` | ❌ 连 IPQ95xx 平台都没有 |
| 高通版-小猪 `1980490718/u-boot-2016` | 有 **IPQ9574** 平台；设备表只有 `ipq9574_xiaomi_be7000` 与 `ipq9574` 公版基础 | ❌ 无 `ipq9570` / `xiaomi_be10000`；最近 30 个 commit 全是 ipq5332 / BE3600 相关工作 |
| 联发科-全新版 `VIKINGYFY/UBOOT-CI` | README 明写「MEDIATEK 系列」，源码 `Yuzhii0718/bl-mt798x-dhcpd`，MT7981/7986/7987 | ❌ 与高通无关 |
| 联发科-官方版 `drive.wrt.moe/uboot/mediatek` | 联发科 | ❌ |

**修正此前表述**：沉心 uBootKit 与小猪 u-boot-2016 的 README 都写了
「NAND 固件 → OpenWrt Factory **一般为 UBI 固件，整个固件刷写到 rootfs 分区，无需区分
kernel 大小**」，小猪版还把 `UBI` 列入固件类型校验（FIT / SYSUPGRADE / QSDK / UBI）。
→ **新一代高通 U-Boot 在镜像格式上是认 `factory.ubi` 的**（比旧 QWRT 只认 `.bin` 强），
缺的只是 BE10000 零售版的板级配置。但零售版是 IPQ9570，小猪版只做到 IPQ9574
（对应 BE7000 / BE10000 **ES 版**），不能给 RC01 刷。

### 7.3 其他两条一手线索

- **作者本人首发帖**：VIKING_YFY 2026-11-11 恩山
  [thread-8497379《【首发】小米万兆 BE10000、BE10000 ES，ipq95xx 满血开源 AI 速成固件》](https://www.right.com.cn/forum/thread-8497379-1-1.html)。
  「现成固件」与「项目源码-OWRT 分支」为回复可见隐藏内容，**主楼无公开刷机 / U-Boot 说明**，
  回帖有人问「能免拆吗」。这帖 + README 首行「IPQ 技术讨论群」QQ 群是拿配套刷机包 / U-Boot 的正规渠道。
- **社区自研进度**：恩山 8487973（嘉嘉祥《BE10000 ImmortalWrt v26 深度适配》，2026-9-2）
  后续计划原文列有「**研究自研 U-Boot 及恢复系统**」→ 截至该日仍只在研究阶段，未发布。
  该帖 15# 有人报告：RC01 + 恩山 10G OpenWRT 帖的 U-Boot + 之前 QWRT 系统，
  「在 uboot 刷了 factory 固件，然后就**无限重启进不去系统**」，作者回复
  「确认下型号、或是否修改了路由器分区」——**与用户现象几乎完全一致**，
  进一步坐实「旧 U-Boot + 被改过的分区表」是已知问题。

### 7.4 三条刷入路径

> ⚠️ 均涉及写 flash，刷错即砖。`mtd2` / `mtd18` 来自 BE10000 社区教程，
> **必须以本机 `cat /proc/mtd` 为准**；恩山 8276907 的 `mtd8/mtd9` 是红米 AX6000
> （联发科），**不可套用到 BE10000**。

**路径 0（推荐）：不换 U-Boot，走原厂双槽布局**

同架构高通设备官方安装范式（OpenWrt PR 19712 / Yuncore AX850 commit message）：

```sh
# 方式 A：U-Boot CLI（需 UART 中断启动）
tftpboot <tftp服务器IP>:factory.ubi
flash rootfs
flash rootfs_1
reset

# 方式 B：initramfs 过渡（先内存启动临时系统，再格式化两个槽）
# U-Boot CLI: tftpboot <ip>:initramfs.bin ; bootm
export rootfs=$(cat /proc/mtd | grep rootfs | cut -d: -f1)
export rootfs_1=$(cat /proc/mtd | grep rootfs_1 | cut -d: -f1)
ubiformat /dev/${rootfs}   -y -f factory.ubi
ubiformat /dev/${rootfs_1} -y -f factory.ubi
reboot
```

小米双槽切启动标志（`cat /proc/cmdline` 看 `firmware=0/1` 决定写哪个槽）：

```sh
nvram set boot_wait=on
nvram set uart_en=1
nvram set flag_boot_rootfs=1        # 当前 0 写 1，当前 1 写 0
nvram set flag_last_success=1
nvram set flag_boot_success=1
nvram set flag_try_sys1_failed=0
nvram set flag_try_sys2_failed=0
nvram commit
ubiformat /dev/mtdXX -y -f /tmp/factory.ubi    # mtdXX 按实际 /proc/mtd 填
reboot -f
```
临时系统里还可用 `fw_setenv` 写同样的标志位（`fw_setenv flag_boot_rootfs 0` 等）。

**路径 1：把旧 U-Boot 刷回原厂**（恩山 8410120，BE10000 专用，有人回帖确认恢复成功）

```sh
mtd erase /dev/mtd2
mtd write /tmp/MIBIB.bin  /dev/mtd2     # 原厂分区表备份
mtd erase /dev/mtd18
mtd write /tmp/APPSBL.bin /dev/mtd18    # 原厂 U-Boot 备份
```
再用**小米路由器修复工具**（MIWIFIRepairTool）恢复原厂固件，可直接恢复到最新版。
恢复后走路径 0。

**路径 2：刷社区不死 U-Boot（不推荐 —— 这正是起不来的原因）**

```sh
md5sum /tmp/mibib.bin && md5sum /tmp/uboot.bin
mtd write /tmp/mibib.bin /dev/mtd2
mtd write /tmp/uboot.bin /dev/mtd18
mtd verify /tmp/mibib.bin /dev/mtd2
mtd verify /tmp/uboot.bin /dev/mtd18
# 断电 → 按住 Reset 上电 → 灯变色松手 → 电脑设 192.168.1.x → 浏览器 192.168.1.1 进 Web
```
这套改分区表为 QWRT 大分区布局、只认 `.bin` 固件，与本项目 `factory.ubi` 不匹配。

### 7.5 新增依据

- 上游 `target/linux/qualcommbe/image/ipq95xx.mk` 完整 `xiaomi_be10000-common` 定义：
  `Device/FitImage` + `Device/UbiFit`、`DEVICE_DTS_CONFIG := config@al02-c4`、
  `BLOCKSIZE := 128k`、`PAGESIZE := 2048`、
  `DEVICE_PACKAGES := ath12k-firmware-qcn9274-ddwrt kmod-phy-aquantia kmod-sfp
  kmod-usb-storage uboot-envtools`；零售版 `SOC := ipq9570`、ES 版 `SOC := ipq9574`。
- `chenxin527/uboot-qsdk12.5-build`、`1980490718/u-boot-2016`、`VIKINGYFY/UBOOT-CI` 三份 README 的支持设备表。
- OpenWrt PR 19712（qualcommax/ipq50xx Yuncore AX850）commit message 里的 INSTALLATION /
  STOCK FIRMWARE RECOVERY 段落（同架构高通 NAND UBI 双槽范式，非 BE10000 专属，仅作方法参考）。
- 恩山 8276907（红米 AX6000 刷回官方布局，nvram 双槽命令）、8410120（BE10000 刷回原厂）、
  8487973（BE10000 ImmortalWrt v26，自研 U-Boot 计划 + 无限重启案例）、
  8497379（作者本人 11-11 首发帖）。
- 上游 11-16 `IPQ95XX` Release：`xiaomi_be10000-squashfs-factory-...ubi` = 67,108,864 B（64 MB）；
  用户仓库 11-15 插件版同文件 = 91,488,256 B（87.2 MB）。

---

## 八、11-17 实机核实：用户提供的「新版 U-Boot」包

用户提供 `BE10000 新版 Uboot.zip`，内含 `mibib.bin`（1 MB，分区表）+ `uboot.mbn`（520,684 B，ELF32 ARM 的 MBN）。对二进制逐项核实，**与第七节查到的社区旧 U-Boot 完全不同**：

| 核实项 | 结果 | 意义 |
| --- | --- | --- |
| 版本 | `U-Boot 2016.01-20261103-r9-g1f0979a (Nov 03 2026)` | 高通 QSDK 2016.01，2026-11-03 新编译 |
| 机型串 | `Xiaomi BE10000`，提示符 `IPQ9574#` | 明确 BE10000 |
| 芯片串 | `ipq9574_edma_*`、`qcom,ipq9574-nand` | **IPQ9574**，非零售版 RC01 的 IPQ9570 |
| 内置 DT | `config@al02-c5/c6/c11/c12/c14/c15/c16/c20`，**无 `config@al02-c4`** | 面向工程版/参考板概率大 |
| 格式校验 | `NAND flash only supports UBI/FIT/SYSUPGRADE/QSDK firmware` | **认 UBI**，与 `factory.ubi` 同构 |
| 启动参数 | `ubi.mtd=rootfs root=mtd:ubi_rootfs rootfstype=squashfs`、`ubi read kernel` | 内核进 UBI，`KERNEL_IN_UBI` 布局 |
| Web | 内置 httpd，`/uboot.html`、`/firmware.html`、`/mibib.html`，`ipaddr=192.168.1.1` | 刷后可进 Web 重刷固件 |

**这很可能就是"刷完起不来"的正解**：旧 QWRT 不死 U-Boot 按独立 kernel 分区引导、只认 `.bin`，与本项目的 `factory.ubi`（内核进 UBI）不匹配 → 无限重启；本新版 U-Boot 恰恰按 UBI 布局引导，能对上。

**但两个风险仍要记住**：① 芯片是 IPQ9574 / al02 参考板，无零售版 `config@al02-c4`，RC01 上能否稳启无第三方成功案例，务必先备份 mtd2/mtd18；② 87.2 MB 插件版 factory.ubi 仍超原厂 60 MB 槽，建议先用 64 MB 标准版验证。

**文件名陷阱**：包内三处命名互相矛盾——`readme.txt` 写 `mibib.mbn`/`uboot.bin`，`万兆新uboot刷入.txt` 写 `mtd2_0MIBIB.bin`/`openwrt-ipq9574_xiaomi_be10000-u-boot.mbn`，而真实文件是 **`mibib.bin`（→ mtd2）+ `uboot.mbn`（→ mtd18）**。照原文抄会报文件不存在。

**刷入链**（以真实文件名为准）：SSH 下 `dd` 备份 mtd2/mtd18 → `mtd write mibib.bin /dev/mtd2` + `mtd write uboot.mbn /dev/mtd18` → `mtd verify` 双校验 → 等 30 秒不断电 → 断电按 Reset 上电进 `192.168.1.1/uboot.html` → **重新刷 `factory.ubi`**（分区表变了，旧固件不可用）。救砖用备份的 MIBIB/APPSBL 刷回 + 小米修复工具。

完整教程已写入 `docs/BE10000-新版U-Boot刷入教程.md` 并推送到仓库 `kyxing107/OpenWRT-CI-BE10000`（commit `8b49f82`），U-Boot 文件在 `u-boot/BE10000/`。

### 顺带：升级编译已完成

`43993194873` 已 `completed/success`，产物 Release `IPQ95XX-VIKINGYFY-owrt-26.11.17-09.09.36`：

- `...xiaomi_be10000-squashfs-factory-...26.11.17-09.09.36.ubi` = 91,488,256 B（87.2 MB）
- `...xiaomi_be10000-squashfs-sysupgrade-...26.11.17-09.09.36.bin` = 88,279,308 B（84.2 MB）
- 配置含 openclash / adguardhome / lucky 四行 `=y`。

87.2 MB 依旧超原厂槽——配合本新版 U-Boot 重刷时，仍建议先拿 64 MB 标准版（`...26.11.15-20.44.51.ubi`）验证引导。
