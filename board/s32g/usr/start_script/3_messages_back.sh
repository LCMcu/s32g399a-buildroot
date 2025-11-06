#!/bin/busybox sh
# 简化、稳定、实时定时备份 /var/log/messages* 到两个 eMMC 分区
# 支持挂载检测、终端输出、syslog 输出

LOG_TAG=$(basename "$0")

# 使用当前终端，如果没有可写终端则退回 /dev/console
TERM_DEV="/dev/tty"
[ ! -w "$TERM_DEV" ] && TERM_DEV="/dev/console"

# 全局重定向 stdout 和 stderr
exec > >(tee -a "$TERM_DEV" | logger -t "$LOG_TAG") 2>&1

# ================== 配置区 ==================
SRC="/var/log/messages*"             # 源日志文件（包括 messages 和归档）
EMMC1_MOUNT="/mnt/emmc1"
EMMC1_LOG_DIR="/mnt/emmc1/log/messages"
EMMC2_MOUNT="/mnt/emmc2"
EMMC2_LOG_DIR="/mnt/emmc2/log/messages"

BACKUP_INTERVAL=10                   # 定时备份间隔（秒）
MOUNT_TIMEOUT=300                    # 挂载检测超时（秒）
MOUNT_INTERVAL=2                     # 挂载检测间隔（秒）

# ================== 日志输出 ==================
LOG_TAG=$(basename "$0")
TERM_DEV="/dev/tty"
[ ! -w "$TERM_DEV" ] && TERM_DEV="/dev/console"

exec > >(tee -a "$TERM_DEV" | logger -t "$LOG_TAG") 2>&1

echo "$(date) [INFO] Starting eMMC log backup script..."

# ================== 备份函数 ==================
backup_loop() {
    local MOUNT_POINT="$1"
    local LOG_DIR="$2"
    
    mv "$LOG_DIR" "$LOG_DIR.bak"
    sync
    while true; do
        # 挂载检测，带超时
        local elapsed=0
        while [ $elapsed -lt $MOUNT_TIMEOUT ]; do
            mountpoint -q "$MOUNT_POINT" && break
            sleep $MOUNT_INTERVAL
            elapsed=$((elapsed + MOUNT_INTERVAL))
        done

        if ! mountpoint -q "$MOUNT_POINT"; then
            echo "$(date) [WARN] $MOUNT_POINT not mounted, skipping backup"
        else
            mkdir -p "$LOG_DIR"
            # echo "$(date) [INFO] Backing up logs to $LOG_DIR..."
            cp -a $SRC "$LOG_DIR/" 2>/dev/null
            sync
            # echo "$(date) [INFO] Backup completed to $LOG_DIR"
        fi

        sleep "$BACKUP_INTERVAL"
    done
}

# ================== 启动两个分区的独立备份 ==================
backup_loop "$EMMC1_MOUNT" "$EMMC1_LOG_DIR" &
backup_loop "$EMMC2_MOUNT" "$EMMC2_LOG_DIR" &

echo "$(date) [INFO] eMMC log backup started for two partitions."
exit 0