#!/bin/busybox sh

# LOG_TAG=$(basename "$0")

# # 使用当前终端，如果没有可写终端则退回 /dev/console
# TERM_DEV="/dev/tty"
# [ ! -w "$TERM_DEV" ] && TERM_DEV="/dev/console"

# # 全局重定向 stdout 和 stderr
# exec > >(tee -a "$TERM_DEV" | logger -t "$LOG_TAG") 2>&1

LOG_TAG="SysMon"
exec > >(tee -a /dev/console | logger -t "$LOG_TAG") 2>&1

INTERVAL="1"
while :; do
    # CPU 使用
    set -- $(head -1 /proc/stat)
    t1=$(( $2+$3+$4+$5+$6+$7+$8+$9+$10 )); i1=$5
    sleep 1
    set -- $(head -1 /proc/stat)
    t2=$(( $2+$3+$4+$5+$6+$7+$8+$9+$10 )); i2=$5
    cpu=$(( 100 - (i2-i1)*100/(t2-t1+1) ))

    # 内存使用率
    set -- $(grep -E 'MemTotal|MemAvailable' /proc/meminfo)
    total=$2; avail=$5
    mem=$(( 100*(total-avail)/total ))

    t1=$(cat /sys/class/hwmon/hwmon0/temp1_input 2>/dev/null | head -1 || echo 0)
    t2=$(cat /sys/class/hwmon/hwmon1/temp1_input 2>/dev/null | head -1 || echo 0)
    t3=$(cat /sys/class/hwmon/hwmon2/temp1_input 2>/dev/null | head -1 || echo 0)

    # 转摄氏度，没读到显示 --
    c1=$((t1/1000)); [ "$t1" -eq 0 ] && c1="--"
    c2=$((t2/1000)); [ "$t2" -eq 0 ] && c2="--"
    c3=$((t3/1000)); [ "$t3" -eq 0 ] && c3="--"

    # 一行显示：时间 CPU MEM T1(A53) T2(DDR) T3(SerDes)
    printf "%s CPU:%3d%% MEM:%3d%% T:%2s/%2s/%2sC\r\n" \
           "$(date +%H:%M:%S)" "$cpu" "$mem" "$c1" "$c2" "$c3"

    sleep "$INTERVAL"
done

exit 0