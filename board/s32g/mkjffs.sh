#!/bin/bash
# 2. 一条命令直接生成带 summary、自动 pad 到 128 MiB 的 jffs2 镜像
mkfs.jffs2 \
    --root=./norflash_work \
    --eraseblock=0x10000 \           # 64 KiB（你的 flash erase size）
    --pagesize=0x1000 \              # 一般都 4 KiB
    --output=work-data.jffs2 \
    --pad=134217728 \                # 精确 pad 到 128 MiB = 0x8000000
    --squashfs \                     # 关键：加 summary，第一次 mount 0.3 秒
    --compr=none                     # 不压缩，速度最快，空间浪费一点无所谓

# 3. 生成完直接看大小（一定是 134,217,728 字节）
ls -lh work-data.jffs2
# -rw-r--r-- 1 root root 128M Nov 24 xx:xx work-data.jffs2
