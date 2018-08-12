#!/bin/bash
# Tumblerdwatcher v 1.0
# Script to check and kill tumblerd process if a loop is suspected. To be automatically scheduled at user session start.
# Homemade workaround for bug: [url]http://forums.linuxmint.com/viewtopic.php?f=110&t=97079&p=767460&hilit=tumblerd#p554241[/url]
# The author has no responsibility for the execution. Feel free to distribute and modify it.
# Advice are welcome to rs2809@yahoo.it.

period=60                  # check period (sec)
process="/usr/lib/i386-linux-gnu/tumbler-1/tumblerd"   # tumblerd binary path
Pcpu=20                     # tolerated cpu usage (%)
Pmem=25                     # tolerated memory usage (%)
mountpath="/media"               # automatic mount point for removable storage
sec=10                     # time limit (sec) for opened file at $mountpath for thumbnail generation
sg="-15"                  # process termination signal (-15 is OK)
logpath="/tmp/Tumblerdwatcher.log"         # log path                     

cat /dev/null > $logpath
exec >$logpath 2>&1
# reset log file

while true
# execute endlessly

 do

 sleep $period
# wait a set period of time

 [[ `ps -ef | grep $process | grep -v 'grep' | wc -l` -eq 0 ]] && continue
# skip to next period if not executing

 ps -eo pcpu,pid,pmem,args | grep $process | grep -v 'grep' | while read dpcpu pid dpmem
# catch proccess id, cpu usage and memory usage

  do

  pcpu=`echo $dpcpu | cut -d'.' -f1`
  pmem=`echo $dpmem | cut -d'.' -f1`

  [[ $pcpu -gt $Pcpu ]] || [[ $pmem -gt $Pmem ]] && kill $sg $pid && echo "`date` PID $pid $pcpu/$Pcpu %cpu $pmem/$Pmem %mem" && continue
# if cpu usage or memory usage exceed, kill it and report values in the log file

  [[ `lsof -p $pid | grep $mountpath | wc -l` -eq 0 ]] && continue
# if no opened file by tumblerd at removable storage mountpoint, skip to next period

  lsof -p $pid | grep $mountpath | tr -s ' ' | cut -d' ' -f9 > /tmp/tumblerd.lsof.old
# list opened files

  sleep $sec
# wait for tolerated time limit

  [[ `lsof -p $pid | grep $mountpath | wc -l` -eq 0 ]] && continue
# if no more opened file skip to next period

  lsof -p $pid | grep $mountpath | tr -s ' ' | cut -d' ' -f9 > /tmp/tumblerd.lsof.new
# list opened files again

  for opened_file in `cat /tmp/tumblerd.lsof.old`
# if some file was open before....
   do

     grep $opened_file /tmp/tumblerd.lsof.new && kill $sg $pid && echo "`date` PID $pid ^^^^^^^^^^^^^^^^^^^^^^^^" && continue
# ...and it's still hung open, kill tumblerd
   done

  done

done

Last edited by wchouser3 (2014-03-21 23:56:53)

