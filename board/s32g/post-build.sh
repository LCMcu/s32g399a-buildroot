#!/bin/bash
echo "s32g***************************************s32g********************************************s32g"

#放置镜像版本号
sudo cp -r /home/lc/work/s32g/s32g399a/s32g399a-buildroot/board/s32g/etc/image_version   /home/lc/work/s32g/s32g399a/s32g399a-buildroot/output/target/etc/ 

#配置终端显示主机名
if grep -q "\u@\h:\w" "/home/lc/work/s32g/s32g399a/s32g399a-buildroot/output/target/etc/profile"; then
    echo "profile 配置存在"
else
    echo "profile 配置不存在，追加配置"
    echo "export PS1='\u@\h:\w# '" >> /home/lc/work/s32g/s32g399a/s32g399a-buildroot/output/target/etc/profile
fi

# 放置驱动
sudo cp -r  /home/lc/work/s32g/s32g399a/s32g399a-buildroot/board/s32g/modules /home/lc/work/s32g/s32g399a/s32g399a-buildroot/output/target/lib/
sudo cp -r  /home/lc/work/s32g/s32g399a/s32g399a-buildroot/board/s32g/firmware /home/lc/work/s32g/s32g399a/s32g399a-buildroot/output/target/lib/

# 创建 /etc/passwd
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
#
# echo "GSSAPIAuthentication no" >> /home/lc/work/s32g/s32g399a/s32g399a-buildroot/output/target/etc/ssh/sshd_config
mkdir -p /var/empty/





#放置测试工具
sudo cp -r  /home/lc/work/s32g/s32g399a/s32g399a-buildroot/board/s32g/usr/bin/*  /home/lc/work/s32g/s32g399a/s32g399a-buildroot/output/target/usr/bin/



#放置应用app
sudo cp -r  /home/lc/work/s32g/s32g399a/s32g399a-buildroot/board/s32g/etc/init.d/S99startupapp  /home/lc/work/s32g/s32g399a/s32g399a-buildroot/output/target/etc/init.d/
sudo cp -r  /home/lc/work/s32g/s32g399a/s32g399a-buildroot/board/s32g/usr/app/  /home/lc/work/s32g/s32g399a/s32g399a-buildroot/output/target/usr/
