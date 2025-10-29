#!/bin/sh
# /etc/init.d/S11logbackup
# 实时、独立、断电安全、纯 BusyBox 实现
# 所有轮转参数可配置

# ================== 【可配置参数区】 ==================
SRC="/var/log/messages"                     # 源日志文件（ramdisk）

# 两个 eMMC 分区
EMMC1_MOUNT="/mnt/emmc1"
EMMC1_LOG="/mnt/emmc1/logs/messages"
EMMC2_MOUNT="/mnt/emmc2"
EMMC2_LOG="/mnt/emmc2/logs/messages"

# 挂载检测超时（秒）
MOUNT_TIMEOUT=30
MOUNT_INTERVAL=2

# 轮转配置
ROTATE_SIZE=1000                         # 触发轮转大小（字节），默认 1MB
ROTATE_KEEP=5                               # 保留归档文件个数
ROTATE_SUFFIX=".old"                        # 归档后缀（不压缩）

# 断电安全：每 N 行 sync 一次（N=1 为最高安全，N=0 禁用 sync）
SYNC_EVERY_LINES=1                          # 设为 0 可禁用 sync（不推荐）
# ===================================================

LOCK="/tmp/.logbackup.lock"

# 防止重复启动
[ -f "$LOCK" ] && exit 0
touch "$LOCK"

# ================== 独立备份函数 ==================
backup_to_partition() {
    local MOUNT_POINT="$1"
    local LOG_FILE="$2"
    local elapsed=0
    local line_count=0

    # 1. 仅检测挂载，带超时
    echo "$(date) [logbackup] Checking mount for $MOUNT_POINT..." > /dev/console
    while [ $elapsed -lt $MOUNT_TIMEOUT ]; do
        mountpoint -q "$MOUNT_POINT" && break
        sleep $MOUNT_INTERVAL
        elapsed=$((elapsed + MOUNT_INTERVAL))
    done

    if ! mountpoint -q "$MOUNT_POINT"; then
        echo "$(date) [logbackup] $MOUNT_POINT not mounted, skipping backup" > /dev/console
        return 1
    fi

    # 创建日志目录
    mkdir -p "$(dirname "$LOG_FILE")"
    echo "$(date) [logbackup] Created log directory for $LOG_FILE" > /dev/console

    # 2. 补齐挂载前日志（逐行写 + 按需 sync）
    if [ -f "$SRC" ]; then
        echo "$(date) [logbackup] Backing up pre-mounted logs from $SRC to $LOG_FILE..." > /dev/console
        while IFS= read -r line; do
            echo "$line" >> "$LOG_FILE"
            line_count=$((line_count + 1))
            if [ "$SYNC_EVERY_LINES" -gt 0 ] && [ $((line_count % SYNC_EVERY_LINES)) -eq 0 ]; then
                sync
                echo "$(date) [logbackup] Synced after $line_count lines" > /dev/console
            fi
        done < "$SRC"
        [ "$SYNC_EVERY_LINES" -gt 0 ] && sync
        echo "$(date) [logbackup] Pre-mounted logs backed up to $LOG_FILE" > /dev/console
    fi

    # 3. 实时追加新日志（tail -F）
    echo "$(date) [logbackup] Starting tail for real-time log backup from $SRC" > /dev/console
    (
        tail -n 0 -F "$SRC" 2>/tmp/tail_error.log | while IFS= read -r line; do
            echo "$line" >> "$LOG_FILE"
            line_count=$((line_count + 1))
            if [ "$SYNC_EVERY_LINES" -gt 0 ] && [ $((line_count % SYNC_EVERY_LINES)) -eq 0 ]; then
                sync
                echo "$(date) [logbackup] Synced after $line_count lines (real-time)" > /dev/console
            fi
        done
        echo "$(date) [logbackup] tail stopped for $LOG_FILE" > /dev/console
        [ "$SYNC_EVERY_LINES" -gt 0 ] && sync
    ) &

    # 4. 独立轮转（使用配置参数）
    (
        while true; do
            sleep 60
            [ -f "$LOG_FILE" ] || continue
            sz=$(stat -c %s "$LOG_FILE" 2>/dev/null || echo 0)
            echo "$(date) [logbackup] Checking size of $LOG_FILE: $sz bytes" > /dev/console
            if [ "$sz" -gt "$ROTATE_SIZE" ]; then
                ts=$(date +%Y%m%d-%H%M%S)
                echo "$(date) [logbackup] Log size exceeds threshold. Rotating $LOG_FILE..." > /dev/console
                # 在轮转前，先给 tail 进程一些时间稳定下来
                sleep 2
                # 将原日志文件重命名并创建新文件，避免替换文件
                mv "$LOG_FILE" "$LOG_FILE.$ts$ROTATE_SUFFIX" || continue
                echo "$(date) [logbackup] Log rotated to $LOG_FILE.$ts$ROTATE_SUFFIX" > /dev/console
                sync
                # 创建新文件
                touch "$LOG_FILE"
                echo "$(date) [logbackup] New $LOG_FILE created." > /dev/console
                # 保留最近 N 个归档
                ls -t "$LOG_FILE".*"$ROTATE_SUFFIX" 2>/dev/null | tail -n +$((ROTATE_KEEP + 1)) | xargs -r rm -f
                echo "$(date) [logbackup] Old archived logs cleaned up." > /dev/console
            fi
        done
    ) &

    # 启动标记
    echo "$(date) [logbackup] Started backup for $LOG_FILE (size=${ROTATE_SIZE}B, keep=${ROTATE_KEEP})" > /dev/console
    [ "$SYNC_EVERY_LINES" -gt 0 ] && sync
    return 0
}

# ================== 启动两个独立备份 ==================
echo "$(date) [logbackup] Starting backup for eMMC partitions..." > /dev/console
backup_to_partition "$EMMC1_MOUNT" "$EMMC1_LOG" &
backup_to_partition "$EMMC2_MOUNT" "$EMMC2_LOG" &

# 状态提示
sleep 2
if grep -q "STARTED" "$EMMC1_LOG" 2>/dev/null || grep -q "STARTED" "$EMMC2_LOG" 2>/dev/null; then
    echo "$(date) [logbackup] At least one backup is active" > /dev/console
else
    echo "$(date) [logbackup] WARNING: No backup partition is active" > /dev/console
fi

rm -f "$LOCK"
