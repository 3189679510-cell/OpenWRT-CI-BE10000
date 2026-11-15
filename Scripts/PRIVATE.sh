#!/bin/bash
# SPDX-License-Identifier: MIT
# 自定义插件源码补充 —— 由 Scripts/Packages.sh 末尾 source，此时 UPDATE_PACKAGE 已定义
# 说明：openclash 源码由上游 Scripts/Packages.sh 预置（vernesong/OpenClash dev, pkg 模式），无需重复。

# lucky：gdy666 官方版，整仓 clone 以同时注册 lucky(核心) 与 luci-app-lucky(界面)。
# 不能用 pkg 模式：仓库名恰为 luci-app-lucky，pkg 模式会把界面子包嵌套复制后随仓库一起删除。
UPDATE_PACKAGE "lucky" "gdy666/luci-app-lucky" "main" "" "luci-app-lucky luci-i18n-lucky-zh-cn"

# AdGuard Home：kenzok78 适配版（针对 ImmortalWrt 24.10+/25.12 重构），
# 仓库根目录本身就是 package（含 Makefile），整仓 clone 到 ./package/luci-app-adguardhome 即可。
# 二进制 adguardhome 由 immortalwrt/packages feed 的 net/adguardhome 提供（feeds install -a 已装）。
UPDATE_PACKAGE "adguardhome" "kenzok78/luci-app-adguardhome" "main"
