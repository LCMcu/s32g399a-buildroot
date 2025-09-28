#!/bin/busybox sh
# 脚本：自动将 eMMC 分成两个等大的分区
# 警告：此脚本会删除 /dev/mmcblk0 上的现有分区表，请备份数据！

# 检查是否以 root 权限运行
if [ "$EUID" -ne 0 ]; then
  echo "错误：请以 root 权限运行此脚本（使用 sudo）"
  exit 1
fi

# 目标设备
DEVICE="/dev/mmcblk0"

# 检查设备是否存在
if [ ! -b "$DEVICE" ]; then
  echo "错误：设备 $DEVICE 不存在"
  exit 1
fi

# 获取总扇区数（从 fdisk -l 获取：124321792）
TOTAL_SECTORS=124321792

# 计算每个分区的大小（扇区数）
HALF_SECTORS=$((TOTAL_SECTORS / 2))

# 计算分区结束扇区（第一个分区从 2048 开始，考虑对齐）
START_SECTOR=2048
END_SECTOR1=$((START_SECTOR + HALF_SECTORS - 1))
END_SECTOR2=$((END_SECTOR1 + HALF_SECTORS))

echo "总扇区数：$TOTAL_SECTORS"
echo "每个分区大小（扇区）：$HALF_SECTORS"
echo "分区 1：从扇区 $START_SECTOR 到 $END_SECTOR1"
echo "分区 2：从扇区 $((END_SECTOR1 + 1)) 到 $END_SECTOR2"

# 使用 fdisk 创建分区
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
) | fdisk $DEVICE

# 检查 fdisk 执行结果
if [ $? -ne 0 ]; then
  echo "错误：分区创建失败"
  exit 1
fi

# 同步磁盘
sync
partprobe $DEVICE

# 格式化分区为 ext4
echo "正在格式化分区..."
mkfs.ext4 ${DEVICE}p1
if [ $? -ne 0 ]; then
  echo "错误：格式化 ${DEVICE}p1 失败"
  exit 1
fi

mkfs.ext4 ${DEVICE}p2
if [ $? -ne 0 ]; then
  echo "错误：格式化 ${DEVICE}p2 失败"
  exit 1
fi

# 验证分区
echo "分区完成！当前分区表："
fdisk -l $DEVICE

echo "分区成功创建并格式化："
echo "- ${DEVICE}p1: ext4 文件系统"
echo "- ${DEVICE}p2: ext4 文件系统"
echo "请手动挂载分区或配置 /etc/fstab"