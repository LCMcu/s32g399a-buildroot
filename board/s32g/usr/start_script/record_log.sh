#!/bin/busybox sh

SCRIPT_DIR=`dirname  "$0"`
cd "${SCRIPT_DIR}"

mkdir -p /var/log/huituo/vte_start_cos
logFilepath=/var/log/huituo/vte_start_cos
logName=vte_start_cos
logMaxSize=2M
logMaxNum=5
logTime="date +%Y-%m-%d-%H:%M:%S"

function ininLog(){
    {
        flock -x 200
        logName=$(ls -l $logFilepath | grep "vte_start_cos_1-" | awk -F " " '{print$9}')
        [ -z "$logName" ] && logName="vte_start_cos_1-$(date +%Y-%m-%d-%H:%M:%S)" && echo "`$logTime` start log file success!" | tee -a $logFilepath/$logName
    } 200>/tmp/vte_start_cos.lock
}

function recordLog(){
    {
        flock -x 200
        [ ! -e $logFilepath/$logName ] && logName=$(ls -l $logFilepath | grep "vte_start_cos_1-" | awk -F " " '{print$9}' | head -1)
        echo "`$logTime`: $1" | tee -a $logFilepath/$logName
    } 200>/tmp/vte_start_cos.lock
    return 0
}

function do_cover(){
    local num=$logMaxNum
    while true
    do
        fileHead1="vte_start_cos_$num-"
        file1=$(ls -l $logFilepath| grep "$fileHead1" | awk -F " " '{print$9}')
        if [ -n "$file1" ];then
            [ $num -eq $logMaxNum ] && rm -f $logFilepath/$file1 && continue
            let local tmpNum=$num+1
            tmpFile1=$(echo $file1 | sed s/_$num-/_$tmpNum-/g)
            echo "mv $logFilepath/$file1 $logFilepath/$tmpFile1"  | tee -a $logFilepath/$file1 
            mv $logFilepath/$file1 $logFilepath/$tmpFile1
        fi
        let num-=1
        if [ $num -eq 0 ];then
            break
        fi
    done
    logName="vte_start_cos_1-$(date +%Y-%m-%d-%H:%M:%S)"
    echo "`$logTime` start log file success!" | tee -a $logFilepath/$logName
}

function checkLogFileSize(){
    {
        flock -x 200
        [ -z "$logName" ] && logName=$(ls -l $logFilepath | grep "vte_start_cos_1-" | awk -F " " '{print$9}' | head -1)
        size=$(ls -lh $logFilepath/$logName | awk -F " " '{print$5}')
        size=$(echo $size | grep "M" | awk -F "M" '{print$1}')
        if [ -n "$size" ];then
            #去除小数
            echo $size | grep "\."
            if [ $? -eq 0 ];then
                size=$(echo $size | awk -F "." '{print$1}')
                let size+=1
            fi

            if [ $size -ge $logMaxSize ];then
                do_cover
            fi
        else
            size=$(echo $size | grep "G" | awk -F "G" '{print$1}')
            if [ -n "$size" ];then
                #去除小数
                echo $size | grep "\."
                if [ $? -eq 0 ];then
                    size=$(echo $size | awk -F "." '{print$1}')
                fi
                
                let size=size*1024
                if [ $size -ge $logMaxSize ];then
                    do_cover
                fi
            fi
        fi
    } 200>/tmp/vte_start_cos.lock
}

ininLog
checkLogFileSize
recordLog "ininLog"