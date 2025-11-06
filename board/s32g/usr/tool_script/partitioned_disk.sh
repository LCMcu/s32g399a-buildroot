#!/bin/busybox sh

# 脚本：自动将 eMMC 分成两个等大的分区（若分区不存在）
# 警告：若分区不存在，此脚本会删除 /dev/mmcblk0 上的现有分区表，请备份数据！


LOG_TAG=$(basename "$0")

# 使用当前终端，如果没有可写终端则退回 /dev/console
TERM_DEV="/dev/tty"
[ ! -w "$TERM_DEV" ] && TERM_DEV="/dev/console"

# 全局重定向 stdout 和 stderr
exec > >(tee -a "$TERM_DEV" | logger -t "$LOG_TAG") 2>&1
echo "$(date) [INFO] Starting eMMC partitioning script..."

# 检查是否以 root 权限运行
if [ "$EUID" -ne 0 ]; then
  echo "错误：请以 root 权限运行此脚本"
  exit 1
fi

# 目标设备
DEVICE="/dev/mmcblk0"

# 检查设备是否存在
if [ ! -b "$DEVICE" ]; then
  echo "错误：设备 $DEVICE 不存在"
  exit 1
fi

# 获取总扇区数
TOTAL_SECTORS=124321792
echo "调试：总扇区数 $TOTAL_SECTORS"
if [ -z "$TOTAL_SECTORS" ] || [ "$TOTAL_SECTORS" -le 0 ]; then
  echo "错误：无效的总扇区数"
  exit 1
fi

# 计算每个分区的大小
HALF_SECTORS=$((TOTAL_SECTORS / 2))
echo "调试：每个分区大小 $HALF_SECTORS 扇区"
if [ -z "$HALF_SECTORS" ] || [ "$HALF_SECTORS" -le 0 ]; then
  echo "错误：无效的分区大小"
  exit 1
fi

# 定义检查一致性的次数
CHECK_COUNT=3
CHECK_SUCCESS_COUNT=0

# 检查现有分区，最多检查 3 次
while [ $CHECK_SUCCESS_COUNT -lt $CHECK_COUNT ]; do
  echo "检查现有分区，尝试第 $((CHECK_SUCCESS_COUNT + 1)) 次..."
  PART_INFO=$(fdisk -l $DEVICE 2>/dev/null)
  PART_COUNT=$(echo "$PART_INFO" | grep -c "^${DEVICE}p[0-9]")

  if [ "$PART_COUNT" -eq 2 ]; then
    PART1_INFO=$(echo "$PART_INFO" | grep "^${DEVICE}p1" | head -n 1)
    PART2_INFO=$(echo "$PART_INFO" | grep "^${DEVICE}p2" | head -n 1)

    PART1_START=$(echo $PART1_INFO | awk '{print $2}')
    PART1_END=$(echo $PART1_INFO | awk '{print $3}')
    if [ -n "$PART1_START" ] && [ -n "$PART1_END" ] && [ "$PART1_START" -le "$PART1_END" ] 2>/dev/null; then
      PART1_SECTORS=$((PART1_END - PART1_START + 1))
    else
      PART1_SECTORS=0
      echo "调试：p1 解析失败，START=$PART1_START, END=$PART1_END"
    fi

    PART2_START=$(echo $PART2_INFO | awk '{print $2}')
    PART2_END=$(echo $PART2_INFO | awk '{print $3}')
    if [ -n "$PART2_START" ] && [ -n "$PART2_END" ] && [ "$PART2_START" -le "$PART2_END" ] 2>/dev/null; then
      PART2_SECTORS=$((PART2_END - PART2_START + 1))
    else
      PART2_SECTORS=0
      echo "调试：p2 解析失败，START=$PART2_START, END=$PART2_END"
    fi

    echo "检测到分区："
    echo "  p1: 起始 $PART1_START，结束 $PART1_END，扇区数 $PART1_SECTORS"
    echo "  p2: 起始 $PART2_START，结束 $PART2_END，扇区数 $PART2_SECTORS"

    # 允许 ±5000 扇区的误差
    if [ "$PART1_SECTORS" -ge $((HALF_SECTORS - 5000)) ] && [ "$PART1_SECTORS" -le $((HALF_SECTORS + 5000)) ] && \
       [ "$PART2_SECTORS" -ge $((HALF_SECTORS - 5000)) ] && [ "$PART2_SECTORS" -le $((HALF_SECTORS + 5000)) ]; then
      echo "检测到两个等大分区（大小约 $((HALF_SECTORS * 512 / 1024 / 1024 / 1024)) GiB），无需重新分区"
      echo "当前分区表："
      fdisk -l $DEVICE
      exit 0
    else
      echo "现有分区大小不匹配预期 ($HALF_SECTORS 扇区)，将重新分区"
      CHECK_SUCCESS_COUNT=$((CHECK_SUCCESS_COUNT + 1))
    fi
  else
    echo "未检测到两个分区，将重新分区"
    CHECK_SUCCESS_COUNT=$((CHECK_SUCCESS_COUNT + 1))
  fi

  # 如果3次结果相同，都不一致，执行格式化
  if [ $CHECK_SUCCESS_COUNT -ge $CHECK_COUNT ]; then
    echo "三次检测结果不一致，将执行重新分区"
    break
  fi

  # 等待1秒后重新检查
  sleep 1
done

# 计算分区结束扇区
START_SECTOR=2048
END_SECTOR1=$((START_SECTOR + HALF_SECTORS - 1))
END_SECTOR2=$((END_SECTOR1 + HALF_SECTORS))

echo "总扇区数：$TOTAL_SECTORS"
echo "每个分区大小（扇区）：$HALF_SECTORS"
echo "分区 1：从扇区 $START_SECTOR 到 $END_SECTOR1"
echo "分区 2：从扇区 $((END_SECTOR1 + 1)) 到 $END_SECTOR2"

# 使用 fdisk 创建分区（单一管道输入，确保顺序）
echo "正在创建分区表..."
(
  echo o      # 创建新分区表
  echo n      # 新分区
  echo p      # 主分区
  echo 1      # 分区 1
  echo $START_SECTOR  # 起始扇区
  echo $END_SECTOR1   # 结束扇区
  echo n      # 新分区
  echo p      # 主分区
  echo 2      # 分区 2
  echo $((END_SECTOR1 + 1))  # 起始扇区
  echo        # 默认直到磁盘末尾
  echo w      # 写入分区表
) | fdisk $DEVICE || { echo "错误：fdisk 执行失败"; exit 1; }

# 同步磁盘
sync

# 格式化分区为 ext4，强制覆盖现有文件系统
echo "正在格式化分区..."
MKFS_CMD=$(which mkfs.ext4)
if [ -n "$MKFS_CMD" ] && [ -x "$MKFS_CMD" ]; then
  $MKFS_CMD -F ${DEVICE}p1
  if [ $? -ne 0 ]; then
    echo "错误：格式化 ${DEVICE}p1 失败"
    exit 1
  fi
  $MKFS_CMD -F ${DEVICE}p2
  if [ $? -ne 0 ]; then
    echo "错误：格式化 ${DEVICE}p2 失败"
    exit 1
  fi
else
  echo "错误：未找到可执行的 mkfs.ext4，请确认路径"
  exit 1
fi

# 验证分区
echo "分区完成！当前分区表："
fdisk -l $DEVICE

echo "分区成功创建并格式化："
echo "- ${DEVICE}p1: ext4 文件系统"
echo "- ${DEVICE}p2: ext4 文件系统"
echo "请手动挂载分区或配置 /etc/fstab"
