#!/bin/bash
echo "s32g***************************************s32g********************************************s32g"
sudo cp -r  /home/lc/work/s32g/s32g399a/s32g399a-buildroot/board/s32g/modules /home/lc/work/s32g/s32g399a/s32g399a-buildroot/output/target/lib/
sudo cp -r  /home/lc/work/s32g/s32g399a/s32g399a-buildroot/board/s32g/firmware /home/lc/work/s32g/s32g399a/s32g399a-buildroot/output/target/lib/

# 创建 /etc/passwd 片段
if grep -q "sshd:x:74:" "/home/lc/work/s32g/s32g399a/s32g399a-buildroot/output/target/etc/group_sshd"; then
    echo "ssh 配置存在"
else
    echo "ssh 配置不存在，追加配置"
    echo "sshd:x:74:74:SSH daemon:/var/empty:/sbin/nologin" >> /home/lc/work/s32g/s32g399a/s32g399a-buildroot/output/target/etc/passwd_sshd
    echo "sshd:x:74:" >> /home/lc/work/s32g/s32g399a/s32g399a-buildroot/output/target/etc/group_sshd
    echo "nobody:x:65534" >> /home/lc/work/s32g/s32g399a/s32g399a-buildroot/output/target/etc/group
    echo "sshd:x:74:74:Privilege-separated SSH:/var/empty/sshd:/sbin/nologin" >> /home/lc/work/s32g/s32g399a/s32g399a-buildroot/output/target/etc/passwd
    echo "PermitRootLogin yes" >> /home/lc/work/s32g/s32g399a/s32g399a-buildroot/output/target/etc/ssh/sshd_config
fi
mkdir -p /var/empty/


