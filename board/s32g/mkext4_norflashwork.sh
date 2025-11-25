#!/bin/bash

# --- ext4 镜像制作脚本 ---

# 检查参数数量
if [ "$#" -ne 3 ]; then
    echo "使用方法: $0 <镜像大小MB> <源文件夹路径> <输出镜像名称>"
    echo "示例: $0 256 /path/to/source_dir my_rootfs.ext4"
    exit 1
fi

# 1. 解析参数
IMAGE_SIZE_MB=$1
SOURCE_DIR=$2
OUTPUT_IMAGE=$3

# 检查源文件夹是否存在
if [ ! -d "$SOURCE_DIR" ]; then
    echo "错误: 源文件夹 '$SOURCE_DIR' 不存在或不是一个目录。"
    exit 1
fi

# 检查源文件夹是否为空
if [ -z "$(ls -A "$SOURCE_DIR")" ]; then
    echo "警告: 源文件夹 '$SOURCE_DIR' 为空。"
fi

# 确保以绝对路径使用，并移除末尾斜杠
SOURCE_DIR=$(realpath "$SOURCE_DIR")

# 2. 创建空白镜像文件
echo "--- 步骤 1/4: 创建空白镜像文件 (大小: ${IMAGE_SIZE_MB}MB) ---"
# 使用 dd 创建指定大小的零填充文件
dd if=/dev/zero of="$OUTPUT_IMAGE" bs=1M count="$IMAGE_SIZE_MB" status=progress
if [ $? -ne 0 ]; then
    echo "错误: 创建空白镜像文件失败。"
    exit 1
fi

# 3. 格式化为 ext4 文件系统
echo "--- 步骤 2/4: 格式化镜像为 ext4 ---"
# -F: 强制执行，用于非块设备
# -t ext4: 指定文件系统类型
# -L: 设置卷标 (可选)
# -b 4096: 设置块大小
mke2fs -F -t ext4 -b 4096 "$OUTPUT_IMAGE"
if [ $? -ne 0 ]; then
    echo "错误: 格式化为 ext4 文件系统失败。"
    # 清理创建的文件
    rm -f "$OUTPUT_IMAGE"
    exit 1
fi

# 4. 挂载镜像并复制文件
echo "--- 步骤 3/4: 挂载镜像并复制文件 ---"
# 创建一个临时挂载点
TEMP_MOUNT_POINT=$(mktemp -d)
echo "临时挂载点: $TEMP_MOUNT_POINT"

# 使用 loop 设备挂载镜像文件
sudo mount -t ext4 "$OUTPUT_IMAGE" "$TEMP_MOUNT_POINT" -o loop
if [ $? -ne 0 ]; then
    echo "错误: 挂载镜像失败，可能需要 sudo 权限或 loop 模块未加载。"
    rmdir "$TEMP_MOUNT_POINT"
    exit 1
fi

# 复制文件
echo "正在从 '$SOURCE_DIR' 复制文件..."
# 使用 rsync 复制所有内容，并保持权限和软链接等
sudo rsync -a --exclude '.*' "$SOURCE_DIR"/ "$TEMP_MOUNT_POINT"/
if [ $? -ne 0 ]; then
    echo "警告: 文件复制过程中可能出现问题，请检查 rsync 输出。"
fi

# 5. 清理和卸载
echo "--- 步骤 4/4: 清理和卸载 ---"

# 强制同步数据到磁盘
sync

# 卸载 loop 设备
sudo umount "$TEMP_MOUNT_POINT"
if [ $? -ne 0 ]; then
    echo "错误: 卸载镜像失败。请手动执行 'sudo umount $TEMP_MOUNT_POINT'。"
    exit 1
fi

# 删除临时挂载点
rmdir "$TEMP_MOUNT_POINT"

echo "✅ ext4 镜像 '$OUTPUT_IMAGE' 制作完成！"
echo "镜像大小: ${IMAGE_SIZE_MB}MB"
echo "内容来源: $SOURCE_DIR"
echo "-------------------------------------"
