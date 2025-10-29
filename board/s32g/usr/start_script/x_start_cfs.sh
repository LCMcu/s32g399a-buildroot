#!/bin/sh

#添加本地执行路径
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/root/
export PATH=$PATH:/usr/local/sbin:/usr/sbin:/sbin:/bin:

log_file="/mram/start.log"
cfg_file="/mram/start.cfg"
cnt_file="/mram/boot.cnt"
exe_file="sp1st-cfs"

eth_config="eth0 192.168.0.250 netmask 255.255.255.0 broadcast 192.168.0.255"
eth_up="eth0 up"
gw_config="add default gw 192.168.0.1"

ifconfig $eth_config
echo "ifconfig $eth_config">$log_file
ifconfig $eth_up
echo "ifconfig $eth_up">>$log_file
route $gw_config
echo "route $gw_config">>$log_file

#TODO 接管FPGA的喂狗
#gpioset 0 20=0

#设置日志容量和时间
journalctl --vacuum-size=20M
journalctl --vacuum-time=30days

chmod 777 /nand1/* -R
chmod 777 /nand2/* -R
chmod 777 /mram/* -R

cp /nand1/cfs/core-imx-linux /nand1/$exe_file
cp /nand1/cfs/cf/*.so /nand1/cf/
ln -snf /nand1/cfs/cf/*.tbl /nand1/cf/
ln -snf /nand1/cfs/cf/*.scr /nand1/cf/
ln -snf /nand1/cfs/cf/*.cfg /nand1/cf/

cp /nand2/cfs/core-imx-linux /nand2/$exe_file
cp /nand2/cfs/cf/*.so /nand2/cf/
ln -snf /nand2/cfs/cf/*.tbl /nand2/cf/
ln -snf /nand2/cfs/cf/*.scr /nand2/cf/
ln -snf /nand2/cfs/cf/*.cfg /nand2/cf/

chmod 777 /nand1/* -R
chmod 777 /nand2/* -R
chmod 777 /mram/* -R


default_part=1
if [[ -f "$cfg_file" && -r "$cfg_file" && -w "$cfg_file" ]]
    then
       default_part=$(awk -F= '{print $2}' $cfg_file)
       echo "$cfg_file exist">>$log_file       
    else
       default_part=1
       echo "$cfg_file dot exist">>$log_file
       echo "default_part=1">$cfg_file
fi 
echo "$(date "+%Y-%m-%d %H:%M:%S") : default part=$default_part.">>$log_file

part1="/nand1/"
part2="/nand2/"
if [ $default_part -eq 1 ]
    then
       part1="/nand1/"
       part2="/nand2/"    
    else
       part1="/nand2/"
       part2="/nand1/"
fi 
echo "part sequence is 1-->2:[$part1]-->[$part2] ">>$log_file

cp /mram/dmesg.log /mram/dmesg-bak.log
dmesg >/mram/dmesg.log

bootcount=1
if [[ -f "$cnt_file" && -r "$cnt_file" && -w "$cnt_file" ]]
    then
       bootcount=$(awk -F= '{print $2}' $cnt_file)
       echo "$cnt_file exist">>$log_file       
    else
       echo "$cnt_file dot exist">>$log_file
fi

part1_flag=0
part2_flag=0
tt=0
while true
do 
    if [[ -e "$part1$exe_file" && -x "$part1$exe_file" ]]
        then
            part1_flag=1;
        else
            part1_flag=0
    fi 

    if [[ -e "$part2$exe_file" && -x "$part2$exe_file" ]]
        then
            part2_flag=1;
        else
            part2_flag=0
    fi 
 
    #启动一个循环，定时检查进程是否存在
    procnum=`ps -ef|grep "sp1st-cfs"|grep -v grep|wc -l`  
    if [ $procnum -eq 0 ]
        then
            if [[ $part1_flag -eq 1 && $bootcount -lt 4 ]]
                then
                    cd $part1   
                    echo "cd $(pwd)">>$log_file  
                    tt=10
                else
                    if [ $part2_flag -eq 1 ]
                        then
                            cd $part2   
                            echo "cd $(pwd)">>$log_file  
                            tt=10
                        else
                            tt=0
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
            tt=10
            bootcount=0
    fi
    #每次循环沉睡
    echo "sleep time=$tt"
    sleep $tt
done
