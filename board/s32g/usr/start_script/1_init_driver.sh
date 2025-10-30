#!/bin/busybox sh

LOG_TAG=$(basename "$0")

# 使用当前终端，如果没有可写终端则退回 /dev/console
TERM_DEV="/dev/tty"
[ ! -w "$TERM_DEV" ] && TERM_DEV="/dev/console"

# 全局重定向 stdout 和 stderr
exec > >(tee -a "$TERM_DEV" | logger -t "$LOG_TAG") 2>&1

echo "$(date) [INFO] Starting driver initialization script..."
#######################################公用配置##################################################

#######################################挂载驱动##################################################
insmod /lib/modules/6.6.52-rt43-1.0+/kernel/drivers/net/ethernet/nxp/pfe/pfeng.ko
insmod /lib/modules/6.6.52-rt43-1.0+/kernel/drivers/mailbox/llce-mailbox.ko
insmod /lib/modules/6.6.52-rt43-1.0+/kernel/drivers/mfd/llce-core.ko
insmod /lib/modules/6.6.52-rt43-1.0+/kernel/drivers/net/can/llce/llce_can.ko

# #######################################配置外部输入GPIO###########################################
# #外部输入GPIO C15 PJ_04
# echo 148 > /sys/class/gpio/export
# echo in > /sys/class/gpio/PJ_04/direction

# #外部输入GPIO D15 PJ_06
# echo 150 > /sys/class/gpio/export
# echo in > /sys/class/gpio/PJ_06/direction

# #外部输入GPIO F16 PJ_08
# echo 152 > /sys/class/gpio/export
# echo in > /sys/class/gpio/PJ_08/direction

# #外部输入GPIO D16 PJ_10
# echo 154 > /sys/class/gpio/export
# echo in > /sys/class/gpio/PJ_10/direction

# #######################################读取GPIO状态##############################################
# cat /sys/class/gpio/PJ_04/value
# cat /sys/class/gpio/PJ_06/value
# cat /sys/class/gpio/PJ_08/value
# cat /sys/class/gpio/PJ_10/value

#######################################CAN配置###################################################
ip link set can0 type can bitrate 500000 loopback off
ifconfig can0 up
ip link set can1 type can bitrate 500000 loopback off
ifconfig can1 up
ip link set can2 type can bitrate 500000 loopback off
ifconfig can2 up
ip link set can3 type can bitrate 500000 loopback off
ifconfig can3 up
ip link set llcecan0 type can bitrate 500000 loopback off
ifconfig llcecan0 up

#######################################AB机判定#################################################
#临时使用JTAG CLK引脚作为AB判断引脚，A机拉高，B机拉低。后续使用PCIE 读取AB 标识替代。
MACHINE_A="MACHINE_A"
MACHINE_B="MACHINE_B"

echo 4 > /sys/class/gpio/export
echo in > /sys/class/gpio/PA_04/direction
FILE_PATH="/sys/class/gpio/PA_04/value"

if [ ! -f "$FILE_PATH" ]; then
    echo "Error: File $FILE_PATH does not exist"
    exit 1
fi

VALUE=$(cat "$FILE_PATH" 2>/dev/null)
if [ $? -ne 0 ]; then
    echo "Error: Failed to read file $FILE_PATH"
    exit 1
fi

VALUE=$(echo "$VALUE" | tr -d ' \n\t')
case "$VALUE" in
    0)
        echo "**************************** This is B devices *******************************"
        echo "File $FILE_PATH has value 0, setting MACHINE=MACHINE_B"
        export MACHINE=MACHINE_B
        ;;
    1)
        echo "############################ This is A devices ###############################"
        echo "File $FILE_PATH has value 1, setting MACHINE=MACHINE_A"
        export MACHINE=MACHINE_A
        ;;
    *)
        echo "Error: File $FILE_PATH value is not 0 or 1, actual value: $VALUE"
        ;;
esac

#########################A机配置#########################
if [ "$MACHINE" = "$MACHINE_A" ]; then
    echo "Executing Operation A for $MACHINE"

    ################修改hostname##################
    hostname zhdz-a
    sleep 1

    ################配置网络##################
    ifconfig eth0 192.168.0.101 up
    ifconfig pfe0 192.168.10.101 down
    ifconfig pfe0 hw ether 00:04:9F:BE:EF:A0
    ifconfig pfe0 192.168.10.101 up
    sleep 1
    ifconfig pfe1 192.168.11.101 down
    ifconfig pfe1 hw ether 00:04:9F:BE:EF:A1
    ifconfig pfe1 192.168.11.101 up

    ifconfig pfe2 192.168.12.101 down
    ifconfig pfe2 hw ether 00:04:9F:BE:EF:A2
    ifconfig pfe2 192.168.12.101 up
fi

#########################B机配置#########################
if [ "$MACHINE" = "$MACHINE_B" ]; then
    echo "Executing Operation B for $MACHINE"
    ################修改hostname##################
    hostname zhdz-b
    sleep 1

    ################配置网络##################
    ifconfig eth0 192.168.0.102 up
    ifconfig pfe0 192.168.10.102 down
    ifconfig pfe0 hw ether 00:04:9F:BE:EF:B0
    ifconfig pfe0 192.168.10.102 up
    sleep 1
    ifconfig pfe1 192.168.11.102 down
    ifconfig pfe1 hw ether 00:04:9F:BE:EF:B1
    ifconfig pfe1 192.168.11.102 up

    ifconfig pfe2 192.168.12.102 down
    ifconfig pfe2 hw ether 00:04:9F:BE:EF:B2
    ifconfig pfe2 192.168.12.102 up
fi