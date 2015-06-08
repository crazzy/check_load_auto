#!/bin/sh
#
# @descr check_load_auto - Automatically figures out alert limits for system load
# @author Johan Hedberg <mail@johan.pp.se>
#

export PATH=/bin:/sbin:/usr/bin:/usr/sbin

os=`uname -s`

loadgetter_SunOS() {
        rawdata=`kstat -p 'unix:0:system_misc:avenrun*' | awk '{printf "%s %.2f\n", $1, $2 / 256.0}'`
        m15=`echo "$rawdata" | grep avenrun_15min | awk '{print $NF;}'`
        m5=`echo "$rawdata" | grep avenrun_5min | awk '{print $NF;}'`
        m1=`echo "$rawdata" | grep avenrun_1min | awk '{print $NF;}'`
        echo "$m1 $m5 $m15"
}
loadgetter_Linux() {
        awk '{print $1" "$2" "$3}' /proc/loadavg
}
loadgetter_FreeBSD() {
        sysctl vm.loadavg | awk '{print $3" "$4" "$5}'
}
loadgetter_OpenBSD() {
        sysctl vm.loadavg | awk -F = '{print $2" "$3" "$4}'
}

coregetter_SunOS() {
        kstat -m cpu_info | grep -c '^module:.*cpu_info'
}
coregetter_Linux() {
        grep -c '^processor' /proc/cpuinfo
}
coregetter_FreeBSD() {
        sysctl hw.ncpu | awk '{print $NF;}'
}
coregetter_OpenBSD() {
        sysctl hw.ncpu | awk -F = '{print $2;}'
}

load=`loadgetter_${os}`
cores=`coregetter_${os}`

load1=`echo "$load" | awk '{print $1;}'`
load5=`echo "$load" | awk '{print $2;}'`
load15=`echo "$load" | awk '{print $3;}'`

limit_crit1=`echo $cores | awk '{print $1 * 1.2}'`
limit_crit5=$cores
limit_crit15=`echo $cores | awk '{print $1 * 0.95}'`

limit_warn1=`echo $cores | awk '{print $1 * 0.85}'`
limit_warn5=`echo $cores | awk '{print $1 * 0.80}'`
limit_warn15=`echo $cores | awk '{print $1 * 0.75}'`

check_warn() {
        if [ -z "$3" ]; then
                curstat=0
        else
                curstat=$3
        fi
        echo "$1 $2 $curstat" | awk '{if ($1 >= $2) print 1; else print $3;}'
}
check_crit() {
        echo "$1 $2 $3" | awk '{if ($1 >= $2) print 2; else print $3;}'
}

status=`check_warn $load1 $limit_warn1`
status=`check_warn $load5 $limit_warn5 $status`
status=`check_warn $load15 $limit_warn15 $status`
status=`check_warn $load1 $limit_crit1 $status`
status=`check_warn $load5 $limit_crit5 $status`
status=`check_warn $load15 $limit_crit15 $status`

if [ $status -eq 0 ]; then
        status_str="OK"
elif [ $status -eq 1 ]; then
        status_str="WARNING"
elif [ $status -eq 2 ]; then
        status_str="CRITICAL"
else
        status_str="UNKNOWN"
fi

echo "${status_str}: Load averages: $load | load1=$load1;$limit_warn1;$limit_crit1 load5=$load5;$limit_warn5;$limit_crit5 load15=$load15;$limit_warn15;$limit_crit15"
exit $status
