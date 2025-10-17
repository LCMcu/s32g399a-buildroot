#!/bin/bash

# 脚本名称：auto_mount_mtd_loop.sh
# 描述：持续循环检查 /proc/mtd 和 /etc/fstab，根据配置文件动态挂载指定 name 的 MTD 分区到指定路径。
#       支持检测新分区并自动挂载，兼容 fstab 配置。
# 使用方法：./auto_mount_mtd_loop.sh [-u] <config_file>
#   -u: 卸载所有已挂载的分区并退出
#   <config_file>: 配置文件路径，包含 mtd_name 和 mount_point 映射
# 配置文件格式：
#   [MOUNT_RULES]
#   mtd_name1=mount_point1
#   mtd_name2=mount_point2
# 示例：
#   [MOUNT_RULES]
#   Image-Info=/mnt/image_info
#   fram1_108qn=/mnt/fram1
# 依赖：mount、umount 命令，需 root 权限
# 文件系统类型：默认 jffs2，可通过配置文件指定
# 循环间隔：默认 10 秒，可修改 INTERVAL 变量

# 默认循环间隔（秒）
INTERVAL=10

# 检查参数
if [ $# -lt 1 ] || [ $# -gt 2 ]; then
    echo "Usage: $0 [-u] <config_file>"
    echo "  -u: Unmount all mounted partitions and exit"
    echo "  <config_file>: Path to config file with mount rules"
    exit 1
fi

# 解析参数
UNMOUNT=0
CONFIG_FILE=""
if [ "$1" = "-u" ]; then
    UNMOUNT=1
    CONFIG_FILE="$2"
else
    CONFIG_FILE="$1"
fi

# 检查 root 权限
if [ "$EUID" -ne 0 ]; then
    echo "Error: This script must be run as root!"
    exit 1
fi

# 检查配置文件
if [ ! -f "$CONFIG_FILE" ]; then
    echo "Error: Config file '$CONFIG_FILE' not found!"
    exit 1
fi

# 读取配置文件
declare -A MOUNT_RULES
section_found=0
while IFS='=' read -r key value; do
    key=$(echo "$key" | xargs)
    value=$(echo "$value" | xargs)
    if [[ "$key" == "\[MOUNT_RULES\]" ]]; then
        section_found=1
        continue
    elif [[ "$key" =~ ^\[.*\]$ ]]; then
        section_found=0
        continue
    fi
    if [ $section_found -eq 1 ] && [ -n "$key" ] && [ -n "$value" ]; then
        MOUNT_RULES["$key"]="$value"
        echo "Loaded rule: $key -> $value"
    fi
done < "$CONFIG_FILE"

if [ ${#MOUNT_RULES[@]} -eq 0 ]; then
    echo "Error: No mount rules found in $CONFIG_FILE!"
    exit 1
fi

# 卸载逻辑
if [ $UNMOUNT -eq 1 ]; then
    for mtd_name in "${!MOUNT_RULES[@]}"; do
        mount_point="${MOUNT_RULES[$mtd_name]}"
        if mountpoint -q "$mount_point"; then
            echo "Unmounting $mount_point..."
            umount "$mount_point"
            if [ $? -eq 0 ]; then
                echo "Successfully unmounted $mount_point"
            else
                echo "Error: Failed to unmount $mount_point!"
            fi
        else
            echo "Warning: $mount_point is not mounted"
        fi
    done
    exit 0
fi

# 函数：获取当前挂载状态
get_mounted_mtds() {
    local mounted_mtds=()
    for mtd_name in "${!MOUNT_RULES[@]}"; do
        mount_point="${MOUNT_RULES[$mtd_name]}"
        if mountpoint -q "$mount_point"; then
            mounted_mtds+=("$mtd_name")
        fi
    done
    echo "${mounted_mtds[@]}"
}

# 主循环
echo "Starting MTD mount loop with interval $INTERVAL seconds..."
while true; do
    # 读取 /proc/mtd
    declare -A MTD_DEVICES
    while read -r dev size erasesize name; do
        if [[ $name =~ ^\"([^\"]+)\"$ ]]; then
            name_clean="${BASH_REMATCH[1]}"
            mtd_num="${dev#mtd}"
            MTD_DEVICES["$name_clean"]="/dev/mtdblock$mtd_num"
            echo "Detected MTD: $name_clean -> /dev/mtdblock$mtd_num"
        fi
    done < /proc/mtd

    # 获取当前挂载状态
    mounted_mtds=($(get_mounted_mtds))

    # 遍历配置文件规则，检查并挂载
    for mtd_name in "${!MOUNT_RULES[@]}"; do
        mount_point="${MOUNT_RULES[$mtd_name]}"
        mtd_dev="${MTD_DEVICES[$mtd_name]}"

        if [ -z "$mtd_dev" ]; then
            echo "Warning: MTD partition '$mtd_name' not found in /proc/mtd!"
            continue
        fi

        # 确保挂载点存在
        if [ ! -d "$mount_point" ]; then
            echo "Creating mount point: $mount_point"
            mkdir -p "$mount_point"
            if [ $? -ne 0 ]; then
                echo "Error: Failed to create mount point $mount_point!"
                continue
            fi
        fi

        # 检查是否已挂载
        if ! [[ " ${mounted_mtds[*]} " =~ " ${mtd_name} " ]]; then
            echo "Mounting $mtd_dev to $mount_point with jffs2 filesystem..."
            mount -t jffs2 "$mtd_dev" "$mount_point"
            if [ $? -eq 0 ]; then
                echo "Successfully mounted $mtd_dev to $mount_point"
                ls -l "$mount_point"
            else
                echo "Error: Failed to mount $mtd_dev to $mount_point!"
                echo "Check dmesg for details:"
                dmesg | tail -n 20
            fi
        else
            echo "MTD $mtd_name at $mount_point is already mounted"
        fi
    done

    # 等待下一次检查
    echo "Waiting $INTERVAL seconds for next check..."
    sleep $INTERVAL
done