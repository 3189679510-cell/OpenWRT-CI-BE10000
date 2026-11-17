# 小米万兆 BE10000 固件快速入口

**固件版本**（每次编译同时产出，选对应 Release 下载）：

| 版本 | 配置 / Release 前缀 | 说明 |
| --- | --- | --- |
| 定制插件版 | `IPQ95XX-` | 含 openclash / adguardhome / lucky 等插件，约 87MB |
| 官方标准版 | `IPQ95XX-STD-` | 无第三方插件，约 64MB；首次刷机/验证 UBI 引导推荐此版 |

**U-Boot 下载（本包更新很少，需要时从这里直达）**：

> 新版 U-Boot Release（IPQ9574 / 支持 `factory.ubi`，长期固定链接）：
> https://github.com/kyxing107/OpenWRT-CI-BE10000/releases/tag/uboot-BE10000-20261103
>
> `mibib.bin`（分区表→mtd2）· `uboot.mbn`（U-Boot→mtd18）· 刷入教程见仓库 `docs/` 目录。

# 高质量<免费>交流群

[IPQ技术讨论群](https://qm.qq.com/q/v7nMhzB4oU)

# 高质量<付费>中转站

[Krill-Code](https://www.krill-code.com/register?invite=959NHQCZGT)

# 本地编译器

https://github.com/VIKINGYFY/OWRT-Tools.git

# 自用修改版插件

https://github.com/VIKINGYFY/packages.git

# OpenWRT-CI

官方版：

https://github.com/immortalwrt/immortalwrt.git

自用版：

https://github.com/VIKINGYFY/immortalwrt.git

# U-BOOT

## 小米万兆 BE10000 新版 U-Boot（本仓库专用，直达）

https://github.com/kyxing107/OpenWRT-CI-BE10000/releases/tag/uboot-BE10000-20261103

（支持 factory.ubi；mibib.bin→mtd2，uboot.mbn→mtd18；刷入教程见 docs/）

## 其他平台 U-Boot 开源项目

高通版-沉心：

https://github.com/chenxin527/uboot-qsdk12.5-build.git

高通版-小猪：

https://github.com/1980490718/u-boot-2016.git

联发科-全新版：

https://github.com/VIKINGYFY/UBOOT-CI/releases

联发科-官方版：

https://drive.wrt.moe/uboot/mediatek

# 固件简要说明

固件每天早上5点自动编译。

固件信息里的时间为编译开始的时间，方便核对上游源码提交时间。

MEDIATEK系列、QUALCOMMAX系列、ROCKCHIP系列、X86系列。

# 目录简要说明

workflows——自定义CI配置

Scripts——自定义脚本

Config——自定义配置

## Star History

<a href="https://www.star-history.com/?repos=vikingyfy%2Fopenwrt-ci&type=date&legend=top-left">
 <picture>
   <source media="(prefers-color-scheme: dark)" srcset="https://api.star-history.com/chart?repos=vikingyfy/openwrt-ci&type=date&theme=dark&legend=top-left" />
   <source media="(prefers-color-scheme: light)" srcset="https://api.star-history.com/chart?repos=vikingyfy/openwrt-ci&type=date&legend=top-left" />
   <img alt="Star History Chart" src="https://api.star-history.com/chart?repos=vikingyfy/openwrt-ci&type=date&legend=top-left" />
 </picture>
</a>
