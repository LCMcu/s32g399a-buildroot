#!/bin/sh

LOG_TAG=$(basename "$0")
# 使用当前终端，如果没有可写终端则退回 /dev/console
TERM_DEV="/dev/tty"
[ ! -w "$TERM_DEV" ] && TERM_DEV="/dev/console"
# 全局重定向 stdout 和 stderr
exec > >(tee -a "$TERM_DEV" | logger -t "$LOG_TAG") 2>&1

echo    "############################## 0.stop script...###############################"

