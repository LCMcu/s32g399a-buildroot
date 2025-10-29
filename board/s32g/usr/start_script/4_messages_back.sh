#!/bin/sh
# /etc/init.d/S11logbackup
# 简化版：定时拷贝 /var/log/messages* 到两个 eMMC 分区，定时周期可调整

# ================== 【可配置参数区】 ==================
SRC="/var/log/messages*"  # 源日志文件（包括 messages 和归档）
EMMC1_MOUNT="/mnt/emmc1"
EMMC1_LOG_DIR="/mnt/emmc1/log/messages"
EMMC2_MOUNT="/mnt/emmc2"
EMMC2_LOG_DIR="/mnt/emmc2/log/messages"

# 挂载检测超时（秒）
MOUNT_TIMEOUT=300
MOUNT_INTERVAL=2

# 定时拷贝间隔（秒），你可以根据需要调整
BACKUP_INTERVAL=10  # 每 10 秒拷贝一次，调整此值即可更改周期

# =====================================================

LOCK="/tmp/.logbackup.lock"

# 防止重复启动
[ -f "$LOCK" ] && exit 0
touch "$LOCK"

# ================== 定时拷贝函数 ==================
backup_to_partition() {
    local MOUNT_POINT="$1"
    local LOG_DIR="$2"
    local elapsed=0

    # 1. 检测 eMMC 挂载，带超时
    while [ $elapsed -lt $MOUNT_TIMEOUT ]; do
        mountpoint -q "$MOUNT_POINT" && break
        sleep $MOUNT_INTERVAL
        elapsed=$((elapsed + MOUNT_INTERVAL))
    done

    if ! mountpoint -q "$MOUNT_POINT"; then
        echo "$(date) [logbackup] $MOUNT_POINT not mounted, skipping backup" > /dev/console
        return 1
    fi

    # 2. 创建目标日志目录
    mkdir -p "$LOG_DIR"

    # 3. 拷贝日志文件
    # echo "$(date) [logbackup] Copying $SRC to $LOG_DIR..." > /dev/console
    cp -a $SRC "$LOG_DIR/"
    sync
    # echo "$(date) [logbackup] Backup completed to $LOG_DIR" > /dev/console
}

# ================== 定时备份 ==================
while true; do
    # echo "$(date) [logbackup] Starting backup to eMMC partitions..." > /dev/console
    backup_to_partition "$EMMC1_MOUNT" "$EMMC1_LOG_DIR" &
    backup_to_partition "$EMMC2_MOUNT" "$EMMC2_LOG_DIR" &

    # 等待定时周期结束
    sleep "$BACKUP_INTERVAL"
done

# 清理锁文件（如果脚本退出时）
rm -f "$LOCK"
