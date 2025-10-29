#!/bin/busybox sh

echo "############################## 0脚本...###############################"

echo "############################## 1.挂载驱动，初始化硬件接口...###############################"
/usr/start_script/1_init_driver.sh
sleep 0.5

echo "############################## 2.检测emmc分区情况...###############################"
# /usr/start_script/2_init_driver.sh
sleep 0.5

echo "############################## 3.挂载分区partitions...###############################"
/usr/start_script/3_mount_disk.sh
sleep 0.5

echo "############################## 4.messages备份...###############################"
/usr/start_script/4_messages_back.sh
sleep 0.5

echo "############################## 5.存储分区循环检测...###############################"
# /usr/start_script/5_mount_disk.sh
sleep 0.5


#4. 启动应用程序
# /usr/app/xxx &