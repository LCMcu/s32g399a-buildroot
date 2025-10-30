#!/bin/sh

LOG_TAG=$(basename "$0")
# 使用当前终端，如果没有可写终端则退回 /dev/console
TERM_DEV="/dev/tty"
[ ! -w "$TERM_DEV" ] && TERM_DEV="/dev/console"
# 全局重定向 stdout 和 stderr
exec > >(tee -a "$TERM_DEV" | logger -t "$LOG_TAG") 2>&1

echo "############################## 0.第一启动脚本...###############################"

echo "############################## 1.挂载驱动，初始化硬件接口...###############################"
/usr/start_script/1_init_driver.sh
sleep 0.5

echo "############################## 2.挂载分区partitions...###############################"
/usr/start_script/2_mount_disk.sh
sleep 0.5

echo "############################## 3.messages备份...###############################"
/usr/start_script/3_messages_back.sh
sleep 0.5

# echo "############################## 2.检测emmc分区情况...###############################"
# /usr/start_script/2_init_driver.sh
# sleep 0.5

# echo "############################## 5.存储分区循环检测...###############################"
# /usr/start_script/5_mount_disk.sh
# sleep 0.5

#4. 启动应用程序    
#如果emmc1分区存在，则启动emmc1分区的应用程序

if [ -e /mnt/emmc1/x_start_cfs.sh ]; then
    echo "[INFO] 启动 /mnt/emmc1/x_start_cfs.sh"
    /mnt/emmc1/x_start_cfs.sh &
elif [ -e /mnt/emmc2/x_start_cfs.sh ]; then
    echo "[INFO] 启动 /mnt/emmc2/x_start_cfs.sh"
    /mnt/emmc2/x_start_cfs.sh &
elif [ -e /mnt/norflash_work/x_start_cfs.sh ]; then
    echo "[INFO] 启动 /mnt/norflash_work/x_start_cfs.sh"
    /mnt/norflash_work/x_start_cfs.sh &
else
    echo "[ERROR] /mnt/emmc1/x_start_cfs.sh /mnt/emmc2/x_start_cfs.sh /mnt/norflash_work/x_start_cfs.sh do not exist, no application started!!!"
fi

exit 0