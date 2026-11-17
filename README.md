# OpenWRT-CI · 小米万兆 BE10000

![firmware](https://img.shields.io/github/v/release/kyxing107/OpenWRT-CI-BE10000?label=firmware&color=blue)
![build](https://img.shields.io/github/actions/workflow/status/kyxing107/OpenWRT-CI-BE10000/QCB-ALL.yml?branch=main&label=build)
![license](https://img.shields.io/github/license/kyxing107/OpenWRT-CI-BE10000)

基于 VIKINGYFY/OpenWRT-CI 定制，面向小米万兆路由器 BE10000（IPQ95xx）。每次编译同时产出两个固件版本。

## 固件下载

| 版本 | Release 前缀 | 说明 |
| --- | --- | --- |
| **定制插件版** | `IPQ95XX-` | 含 openclash / adguardhome / lucky 等插件，约 87 MB |
| **官方标准版** | `IPQ95XX-STD-` | 无第三方插件，约 64 MB；首次刷机、验证 UBI 引导推荐 |

进入 [Releases](https://github.com/kyxing107/OpenWRT-CI-BE10000/releases) 下载最新固件。固件信息里的时间为编译开始时间，方便核对上游源码提交。

## U-Boot

> 本包更新很少，需要时从下方直达（长期固定链接）。

[小米万兆 BE10000 新版 U-Boot（支持 factory.ubi）](https://github.com/kyxing107/OpenWRT-CI-BE10000/releases/tag/uboot-BE10000-20261103)

`mibib.bin` → mtd2（分区表） · `uboot.mbn` → mtd18（U-Boot 本体） · 刷入教程见 [docs](https://github.com/kyxing107/OpenWRT-CI-BE10000/tree/main/docs)。

## 文档

- [自行编译指南](https://github.com/kyxing107/OpenWRT-CI-BE10000/blob/main/docs/小米万兆路由器-OpenWRT-CI-自行编译指南.md)
- [U-Boot 兼容性与启动故障排查](https://github.com/kyxing107/OpenWRT-CI-BE10000/blob/main/docs/BE10000-U-Boot兼容性与启动故障排查.md)
- [新版 U-Boot 刷入教程](https://github.com/kyxing107/OpenWRT-CI-BE10000/blob/main/docs/BE10000-新版U-Boot刷入教程.md)

## 相关资源

- 交流群：[IPQ 技术讨论群](https://qm.qq.com/q/v7nMhzB4oU)
- 源码：[immortalwrt/immortalwrt](https://github.com/immortalwrt/immortalwrt) · [VIKINGYFY/immortalwrt](https://github.com/VIKINGYFY/immortalwrt)
- 工具：[VIKINGYFY/OWRT-Tools](https://github.com/VIKINGYFY/OWRT-Tools) · [VIKINGYFY/packages](https://github.com/VIKINGYFY/packages)

## 目录

`.github/workflows` 编译工作流 · `Scripts` 自定义脚本 · `Config` 设备与插件配置 · `docs` 教程文档 · `u-boot` U-Boot 文件
