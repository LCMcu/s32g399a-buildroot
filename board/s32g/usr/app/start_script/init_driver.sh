#!/bin/busybox sh
#######################################挂载驱动##################################################
insmod /lib/modules/6.6.52-rt43-1.0+/kernel/drivers/net/ethernet/nxp/pfe/pfeng.ko
insmod /lib/modules/6.6.52-rt43-1.0+/kernel/drivers/mailbox/llce-mailbox.ko
insmod /lib/modules/6.6.52-rt43-1.0+/kernel/drivers/mfd/llce-core.ko
insmod /lib/modules/6.6.52-rt43-1.0+/kernel/drivers/net/can/llce/llce_can.ko

#######################################配置外部输入GPIO##################################################
#外部输入GPIO C15 PJ_04
echo 148 > /sys/class/gpio/export
echo in > /sys/class/gpio/PJ_04/direction

#外部输入GPIO D15 PJ_06
echo 150 > /sys/class/gpio/export
echo in > /sys/class/gpio/PJ_06/direction

#外部输入GPIO F16 PJ_08
echo 152 > /sys/class/gpio/export
echo in > /sys/class/gpio/PJ_08/direction

#外部输入GPIO D16 PJ_10
echo 154 > /sys/class/gpio/export
echo in > /sys/class/gpio/PJ_10/direction

#######################################读取GPIO状态##################################################
cat /sys/class/gpio/PJ_04/value
cat /sys/class/gpio/PJ_06/value
cat /sys/class/gpio/PJ_08/value
cat /sys/class/gpio/PJ_10/value

#######################################CAN配置##################################################
ip link set can0 type can bitrate 500000 loopback off
ip link set can1 type can bitrate 500000 loopback off
ip link set can2 type can bitrate 500000 loopback off
ip link set can3 type can bitrate 500000 loopback off
ip link set llcecan0 type can bitrate 500000 loopback off

#######################################CAN收发##################################################
#使用candump 和 CAN盒测试



##########################以下仅A机配置！########################
#调试网口
ifconfig eth0 192.168.0.101 up
#外部网口1
ifconfig pfe0 192.168.10.101 up
#外部网口2
ifconfig pfe1 192.168.11.101 up
#AB间网口
ifconfig pfe2 192.168.12.101 up


#########################以下仅B机配置！#########################
#调试网口
ifconfig eth0 192.168.0.102 up
#外部网口1
ifconfig pfe0 192.168.10.102 up
#外部网口2
ifconfig pfe1 192.168.11.102 up
#AB间网口
ifconfig pfe2 192.168.12.102 up
