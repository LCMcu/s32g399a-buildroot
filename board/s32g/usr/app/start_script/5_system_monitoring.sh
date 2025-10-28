#!/bin/busybox sh

echo "############################## 0.启动脚本...###############################"

echo "############################## 1.挂载驱动，初始化硬件接口...###############################"
/usr/app/start_script/1_init_driver.sh
sleep 0.5

echo "############################## 2.检测emmc分区情况...###############################"
/usr/app/start_script/2_init_driver.sh
sleep 0.5

echo "############################## 3.挂载分区partitions...###############################"
/usr/app/start_script/3_mount_disk.sh
sleep 0.5

echo "############################## 4.存储分区循环检测...###############################"
/usr/app/start_script/4_check_disk.sh 
sleep 0.5

echo "############################## 4.存储分区循环检测...###############################"
/usr/app/start_script/5_system_monitoring.sh 
sleep 0.5

echo "############################## x.启动应用程序...###############################"
#/usr/app/start_script/xxx.sh
sleep 0.5

#4. 启动应用程序
# /usr/app/xxx &