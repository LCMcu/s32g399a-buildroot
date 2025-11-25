#!/bin/bash
echo "s32g***************************************s32g********************************************s32g"

#1.放置镜像版本号
sudo cp -r /home/lc/work/s32g/s32g399a/s32g399a-buildroot/board/s32g/etc/image_version   /home/lc/work/s32g/s32g399a/s32g399a-buildroot/output/target/etc/ 

#2.配置终端显示主机名
if grep -q "\u@\h:\w" "/home/lc/work/s32g/s32g399a/s32g399a-buildroot/output/target/etc/profile"; then
    echo "profile 配置存在"
else
    echo "profile 配置不存在，追加配置"
    echo "export PS1='\u@\h:\w# '" >> /home/lc/work/s32g/s32g399a/s32g399a-buildroot/output/target/etc/profile
fi

#3.创建emmc、flash挂载点, 修改mdev配置规则，放置fstab
# if grep -q "mtd" "/home/lc/work/s32g/s32g399a/s32g399a-buildroot/output/target/etc/mdev.conf"; then
#     echo "mtd 配置存在"
# else
#     echo "mtd 配置不存在，追加配置"
#     echo "mtd[0-10]*      0:0 660" >> /home/lc/work/s32g/s32g399a/s32g399a-buildroot/output/target/etc/mdev.conf
#     echo "mtdblock[0-10]* 0:0 660" >> /home/lc/work/s32g/s32g399a/s32g399a-buildroot/output/target/etc/mdev.conf 
# fi

sudo mkdir -p /home/lc/work/s32g/s32g399a/s32g399a-buildroot/output/target/mnt/emmc1
sudo mkdir -p /home/lc/work/s32g/s32g399a/s32g399a-buildroot/output/target/mnt/emmc2

sudo mkdir -p /home/lc/work/s32g/s32g399a/s32g399a-buildroot/output/target/mnt/norflash_work
sudo mkdir -p /home/lc/work/s32g/s32g399a/s32g399a-buildroot/output/target/mnt/norflash_image_info

sudo mkdir -p /home/lc/work/s32g/s32g399a/s32g399a-buildroot/output/target/mnt/mram1
sudo mkdir -p /home/lc/work/s32g/s32g399a/s32g399a-buildroot/output/target/mnt/mram2

sudo cp -r /home/lc/work/s32g/s32g399a/s32g399a-buildroot/board/s32g/etc/fstab   /home/lc/work/s32g/s32g399a/s32g399a-buildroot/output/target/etc/fstab 

#4.创建 /etc/passwd
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
sudo mkdir -p /var/empty/

#放置ssh配置文件
#如果ssh_host_ecdsa_key.pub不存在，则复制该目录
# if [ ! -f "/home/lc/work/s32g/s32g399a/s32g399a-buildroot/output/target/etc/ssh/ssh_host_ecdsa_key.pub" ]; then
#     sudo cp -r /home/lc/work/s32g/s32g399a/s32g399a-buildroot/board/s32g/etc/ssh /home/lc/work/s32g/s32g399a/s32g399a-buildroot/output/target/etc/
# else    
#     echo "ssh目录已存在，跳过复制"
# fi

#替换chrony 配置文件，当前配置为使用lc ubuntu 虚拟机作为时间服务器
sudo cp -r /home/lc/work/s32g/s32g399a/s32g399a-buildroot/board/s32g/etc/chrony/chrony.conf /home/lc/work/s32g/s32g399a/s32g399a-buildroot/output/target/etc/chrony.conf
#替换S01syslogd脚本，修改日志轮转参数
sudo cp -r /home/lc/work/s32g/s32g399a/s32g399a-buildroot/board/s32g/etc/init.d/S01syslogd /home/lc/work/s32g/s32g399a/s32g399a-buildroot/output/target/etc/init.d/S01syslogd

#5.放置驱动
sudo cp -r  /home/lc/work/s32g/s32g399a/s32g399a-buildroot/board/s32g/modules /home/lc/work/s32g/s32g399a/s32g399a-buildroot/output/target/lib/
sudo cp -r  /home/lc/work/s32g/s32g399a/s32g399a-buildroot/board/s32g/firmware /home/lc/work/s32g/s32g399a/s32g399a-buildroot/output/target/lib/

#6.放置测试工具
sudo cp -r  /home/lc/work/s32g/s32g399a/s32g399a-buildroot/board/s32g/usr/bin/*  /home/lc/work/s32g/s32g399a/s32g399a-buildroot/output/target/usr/bin/

#7.放置应用启动脚本、app
sudo chmod 777 /home/lc/work/s32g/s32g399a/s32g399a-buildroot/board/s32g/usr/app/* -R
sudo chmod 777 /home/lc/work/s32g/s32g399a/s32g399a-buildroot/board/s32g/usr/start_script/* -R
sudo chmod 777 /home/lc/work/s32g/s32g399a/s32g399a-buildroot/board/s32g/usr/tool_script/* -R
sudo cp -r  /home/lc/work/s32g/s32g399a/s32g399a-buildroot/board/s32g/etc/init.d/S99startupapp  /home/lc/work/s32g/s32g399a/s32g399a-buildroot/output/target/etc/init.d/
sudo cp -r  /home/lc/work/s32g/s32g399a/s32g399a-buildroot/board/s32g/usr/start_script/  /home/lc/work/s32g/s32g399a/s32g399a-buildroot/output/target/usr/
sudo cp -r  /home/lc/work/s32g/s32g399a/s32g399a-buildroot/board/s32g/usr/tool_script/  /home/lc/work/s32g/s32g399a/s32g399a-buildroot/output/target/usr/
sudo cp -r  /home/lc/work/s32g/s32g399a/s32g399a-buildroot/board/s32g/usr/app/  /home/lc/work/s32g/s32g399a/s32g399a-buildroot/output/target/usr/
