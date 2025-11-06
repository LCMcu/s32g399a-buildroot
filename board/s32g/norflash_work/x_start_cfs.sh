#!/bin/sh

SCRIPT_PATH="$(cd "$(dirname "$0")" && pwd)"
echo "脚本位置：$SCRIPT_PATH"
echo "当前目录：$(pwd)"

#添加本地执行路径
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/root/
export PATH=$PATH:/usr/local/sbin:/usr/sbin:/sbin:/bin:

# log_file="/mnt/mram/start.log"
part="/mnt/norflash_work/"
log_file="/mnt/norflash_work/start.log"
cfg_file="/mnt/mram/start.cfg"
cnt_file="/mnt/mram/boot.cnt"
exe_file="core-s32g3-linux"

eth_config="eth0 192.168.0.250 netmask 255.255.255.0 broadcast 192.168.0.255"
eth_up="eth0 up"
gw_config="add default gw 192.168.0.1"

# ifconfig $eth_config
# echo "ifconfig $eth_config">$log_file
# ifconfig $eth_up
# echo "ifconfig $eth_up">>$log_file
# route $gw_config
# echo "route $gw_config">>$log_file

#TODO 接管FPGA的喂狗
#gpioset 0 20=0

chmod 777 /mnt/norflash_work/* -R
chmod 777 /mnt/mram/* -R

cp /mnt/norflash_work/cfs/core-s32g3-linux /mnt/norflash_work/$exe_file
cp /mnt/norflash_work/cfs/cf/*.so /mnt/norflash_work/cf/
ln -snf /mnt/norflash_work/cfs/cf/*.tbl /mnt/norflash_work/cf/
ln -snf /mnt/norflash_work/cfs/cf/*.scr /mnt/norflash_work/cf/
ln -snf /mnt/norflash_work/cfs/cf/*.cfg /mnt/norflash_work/cf/

chmod 777 /mnt/norflash_work/* -R
chmod 777 /mnt/mram/* -R

#通过mram中的配置文件获取默认盘符
echo "$(date "+%Y-%m-%d %H:%M:%S") : default part=norflash_work.">>$log_file

#备份mram中dmesg日志
cp /mnt/mram/dmesg.log /mnt/mram/dmesg-bak.log
#备份当前dmesg日志到mram
dmesg >/mnt/mram/dmesg.log

#读取mram中boot.cnt文件中的启动计数值，如果不存在则默认为1
bootcount=1
if [[ -f "$cnt_file" && -r "$cnt_file" && -w "$cnt_file" ]]
    then
       bootcount=$(awk -F= '{print $2}' $cnt_file)
       echo "$cnt_file exist">>$log_file       
    else
       echo "$cnt_file dot exist">>$log_file
fi

#分区内可执行文件状态获取，并记录到标志位，是否存在、是否可执行。
part_flag=0
sleep_time=0
while true
do 
    if [[ -e "$part$exe_file" && -x "$part$exe_file" ]]
        then
            part_flag=1;
        else
            part_flag=0
    fi 

    #启动一个循环，定时检查进程是否存在
    procnum=`ps -ef|grep $exe_file|grep -v grep|wc -l`  
    if [ $procnum -eq 0 ]
        then
            if [[ $part_flag -eq 1 && $bootcount -lt 4 ]]
                then
                    cd $part
                    echo "cd $(pwd)">>$log_file
                    sleep_time=10
                else
                    if [ $part_flag -eq 1 ]
                    then
                        echo "$part flag is $part_flag!!!">>$log_file
                        sleep_time=10
                    fi
            fi
            cp run.log bak.log
            #如果不存在就重新启动
            nohup ./$exe_file>run.log 2>&1 &
            echo "$(date "+%Y-%m-%d %H:%M:%S") : start cfs !bootcount=$bootcount.">>$log_file
            bootcount=`expr $bootcount + 1`
            echo "bootcount=$bootcount">$cnt_file
    fi

    if [ $bootcount -gt 6 ]
        then
            sleep_time=10
            bootcount=0
    fi
    #每次循环沉睡
    echo "sleep time=$sleep_time" >>$log_file
    sleep $sleep_time
done
