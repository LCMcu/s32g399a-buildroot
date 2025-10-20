#!/bin/busybox sh

#1 初始驱动、系统配置
/usr/app/start_script/init_driver.sh
#2. 自动挂载nor_flash、emmc分区
/usr/app/start_script/auto_mount_mtd_loop.sh /usr/app/start_script/auto_mount_mtd_loop.conf &
#3. 启动应用程序
# /usr/app/xxx &