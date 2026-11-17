把文件上传到路由器，使用如下命令刷入即可
mtd write mibib.mbn /dev/mtd2
mtd write uboot.bin /dev/mtd18

注意：写入后需要重新在uboot刷入固件


刷原来的 192.168.1.1/uboot.html
更新mbn格式的就行了