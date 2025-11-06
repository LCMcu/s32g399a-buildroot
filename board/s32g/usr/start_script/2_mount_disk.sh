#!/bin/busybox sh

# 脚本名称：auto_mount_mtd_loop.sh
# 描述：持续循环检查 /proc/mtd 和 eMMC 分区，直接挂载预定义的 MTD 和 eMMC 分区到指定路径。
# 使用方法：./auto_mount_mtd_loop.sh [-u]
#   -u: 卸载所有预定义的挂载点并退出
# 预定义规则：
#   MTD 分区: Work=/mnt/norflash_work, Image-Info=/mnt/norflash_image_info
#   eMMC 分区: mmcblk0p1=/mnt/emmc1, mmcblk0p2=/mnt/emmc2
# 依赖：mount、umount 命令，需 root 权限
# 文件系统类型：MTD 默认 jffs2，eMMC 默认 ext4
# 循环间隔：默认 5 秒

LOG_TAG=$(basename "$0")

# 使用当前终端，如果没有可写终端则退回 /dev/console
TERM_DEV="/dev/tty"
[ ! -w "$TERM_DEV" ] && TERM_DEV="/dev/console"

# 全局重定向 stdout 和 stderr
exec > >(tee -a "$TERM_DEV" | logger -t "$LOG_TAG") 2>&1
echo "$(date) [INFO] Starting auto mount MTD and eMMC loop script..."

# 默认循环间隔（秒）
INTERVAL=5

# 检查参数
if [ $# -gt 1 ]; then
    echo "Usage: $0 [-u]"
    echo "  -u: Unmount all predefined mount points and exit"
    exit 1
fi

# 解析参数
UNMOUNT=0
if [ "$1" = "-u" ]; then
    UNMOUNT=1
fi

# 检查 root 权限
if [ "$(id -u)" -ne 0 ]; then
    echo "Error: This script must be run as root!"
    exit 1
fi

# 预定义挂载规则
work_mnt="/mnt/norflash_work"
image_info_mnt="/mnt/norflash_image_info"
mmc1_mnt="/mnt/emmc1"
mmc2_mnt="/mnt/emmc2"

# 卸载逻辑
if [ $UNMOUNT -eq 1 ]; then
    for mnt in "$work_mnt" "$image_info_mnt" "$mmc1_mnt" "$mmc2_mnt"; do
        if [ -n "$mnt" ] && mountpoint -q "$mnt"; then
            echo "Unmounting $mnt..."
            umount -l "$mnt" || umount "$mnt"
            if [ $? -eq 0 ]; then
                echo "Successfully unmounted $mnt"
            else
                echo "Error: Failed to unmount $mnt!"
            fi
        elif [ -n "$mnt" ]; then
            echo "Warning: $mnt is not mounted"
        fi
    done
    exit 0
fi

# 函数：获取当前挂载状态
get_mounted_mtds() {
    local mounted_mtds=""
    for mnt in "$work_mnt" "$image_info_mnt" "$mmc1_mnt" "$mmc2_mnt"; do
        if [ -n "$mnt" ] && mountpoint -q "$mnt"; then
            case $mnt in
                "$work_mnt") mounted_mtds="$mounted_mtds Work ";;
                "$image_info_mnt") mounted_mtds="$mounted_mtds Image-Info ";;
                "$mmc1_mnt") mounted_mtds="$mounted_mtds mmcblk0p1 ";;
                "$mmc2_mnt") mounted_mtds="$mounted_mtds mmcblk0p2 ";;
            esac
        fi
    done
    echo "$mounted_mtds"
}

# 主循环
echo "Starting mount loop with interval $INTERVAL seconds..."
while true; do
    # 初始化 MTD 设备路径变量
    work_dev=""
    image_info_dev=""

    # 读取 /proc/mtd 并分配设备路径
    mtd_num=0
    while read -r line; do
        name=$(echo "$line" | awk -F'"' '{print $2}')
        if [ -n "$name" ]; then
            case $name in
                Work)
                    work_dev="/dev/mtdblock$mtd_num"
                    echo "Detected MTD: $name -> $work_dev"
                    ;;
                Image-Info)
                    image_info_dev="/dev/mtdblock$mtd_num"
                    echo "Detected MTD: $name -> $image_info_dev"
                    ;;
                *)
                    echo "Detected MTD: $name -> /dev/mtdblock$mtd_num"
                    ;;
            esac
            mtd_num=$((mtd_num + 1))
        fi
    done < /proc/mtd

    # 存储 eMMC 设备路径
    mmc1_dev="/dev/mmcblk0p1"
    mmc2_dev="/dev/mmcblk0p2"

    # 获取当前挂载状态
    mounted_mtds=$(get_mounted_mtds)

    # 遍历预定义规则，检查并挂载
    for mtd_name in Work Image-Info mmcblk0p1 mmcblk0p2; do
        mount_point=""
        mtd_dev=""
        case $mtd_name in
            Work) mount_point="$work_mnt"; mtd_dev="$work_dev"; fs_type="jffs2";;
            Image-Info) mount_point="$image_info_mnt"; mtd_dev="$image_info_dev"; fs_type="jffs2";;
            mmcblk0p1) mount_point="$mmc1_mnt"; mtd_dev="$mmc1_dev"; fs_type="ext4";;
            mmcblk0p2) mount_point="$mmc2_mnt"; mtd_dev="$mmc2_dev"; fs_type="ext4";;
        esac

        if [ -z "$mtd_dev" ]; then
            echo "Warning: Partition '$mtd_name' not found or device path invalid!"
            continue
        fi

        # 确保挂载点存在
        if [ -n "$mount_point" ] && [ ! -d "$mount_point" ]; then
            echo "Creating mount point: $mount_point"
            mkdir -p "$mount_point"
            if [ $? -ne 0 ]; then
                echo "Error: Failed to create mount point $mount_point!"
                continue
            fi
        fi

        # 检查是否已挂载
        if [ -n "$mount_point" ] && ! echo " $mounted_mtds " | grep -q " $mtd_name "; then
            echo "Mounting $mtd_dev to $mount_point with $fs_type filesystem..."
            mount -t "$fs_type" "$mtd_dev" "$mount_point"
            if [ $? -eq 0 ]; then
                echo "Successfully mounted $mtd_dev to $mount_point"
                ls -l "$mount_point"
            else
                echo "Error: Failed to mount $mtd_dev to $mount_point!"
                echo "Check dmesg for details:"
                dmesg | tail -n 20
            fi
        elif [ -n "$mount_point" ]; then
            echo "Partition $mtd_name at $mount_point is already mounted"
        fi
    done
    exit 0
    # 等待下一次检查
    echo "Waiting $INTERVAL seconds for next check..."
    sleep $INTERVAL
done