#!/bin/sh

# 日志标签，用于系统日志（syslog）
LOG_TAG="4_system_monitoring"

# 默认间隔时间
INTERVAL="1"

# =================================================================
# 函数定义：将消息同时输出到标准输出、/dev/console 和系统日志
# 参数: $1 - 要记录的消息字符串
# =================================================================
log_message() {
    # 使用 tee 将消息同时输出到标准输出（以便在终端上看到）和 /dev/console
    # 使用 logger 将消息发送到系统日志，并附带 LOG_TAG
    local message="$1"
    # echo "$message" | tee -a /dev/console
    logger -t "$LOG_TAG" "$message"
}

# =================================================================
# 主程序入口
# =================================================================

# 初始设置：记录脚本启动信息
log_message "System monitoring script started with LOG_TAG=\"$LOG_TAG\""

# 无限循环进行监控
while :; do
    # 1. CPU 使用率计算
    # 读取 /proc/stat 初始值
    set -- $(head -1 /proc/stat)
    # t1: 总 CPU 时间 (user+nice+system+idle+iowait+irq+softirq+steal+guest+guest_nice)
    t1=$(( $2+$3+$4+$5+$6+$7+$8+$9+$10 ))
    # i1: 闲置时间 (idle)
    i1=$5
    
    # 等待 INTERVAL
    sleep "$INTERVAL"
    
    # 读取 /proc/stat 结束值
    set -- $(head -1 /proc/stat)
    t2=$(( $2+$3+$4+$5+$6+$7+$8+$9+$10 )); i2=$5
    
    # CPU 使用率计算：100 - (空闲时间增量 * 100 / 总时间增量)
    # +1 是为了避免除零错误
    cpu=$(( 100 - (i2-i1)*100/(t2-t1+1) ))

    # 2. 内存使用率计算
    set -- $(grep -E 'MemTotal|MemAvailable' /proc/meminfo)
    # $2 是 MemTotal 的值
    total=$2
    # $5 是 MemAvailable 的值 (注意 set -- 后的参数顺序)
    avail=$5
    
    # 内存使用率：(总内存 - 可用内存) * 100 / 总内存
    mem=$(( 100*(total-avail)/total ))

    # 3. 温度读取 (假设是 millidegrees Celsius)
    t1=$(cat /sys/class/hwmon/hwmon0/temp1_input 2>/dev/null | head -1 || echo 0)
    t2=$(cat /sys/class/hwmon/hwmon1/temp1_input 2>/dev/null | head -1 || echo 0)
    t3=$(cat /sys/class/hwmon/hwmon2/temp1_input 2>/dev/null | head -1 || echo 0)

    # 4. 温度值处理：转摄氏度，未读到/为零则显示 --
    c1=$((t1/1000)); [ "$t1" -eq 0 ] && c1="--"
    c2=$((t2/1000)); [ "$t2" -eq 0 ] && c2="--"
    c3=$((t3/1000)); [ "$t3" -eq 0 ] && c3="--"

    # 5. 格式化输出消息
    # 使用 printf 格式化一行输出
    output_message=$(printf "%s CPU:%3d%% MEM:%3d%% T:DDR-RAM:%2s,cluster1_cpu0:%2s,cluster1_cpu0:%2sC" \
        "$(date +%H:%M:%S)" "$cpu" "$mem" "$c1" "$c2" "$c3")

    # 6. 调用日志函数记录消息
    log_message "$output_message"

done

exit 0