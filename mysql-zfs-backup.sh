#!/usr/bin/bash 

# initial variables
ZFS=/usr/sbin/zfs 
MYSQL=/usr/local/mysql/bin/mysql
bkp_fs_list='data/mysql'
mysql_user='root'
mysql_pass=''
LOG=/var/log/mysql-zfsbackup.log

# simple retention policy: how long to store snapshots
# seconds (s, S or no suffixes), minutes (m or M), hours (h,H)
# days (d, D), weeks (w, W), years (y, Y)
keep_backup=14d

exec &> >(tee -a ${LOG})

# some checks to prevent multiplie scripts running via cron
PIDFILE=/tmp/mysql-do-zfsbackup.pid

# getopts

while getopts "s:" OPTS
do
  case ${OPTS} in
    s) 
      echo "Custom snapshot name will be used"
      sopt=${OPTARG}
      ;;
  esac
done

if [ -f $PIDFILE ]
then
    PID=`cat ${PIDFILE}`
    ps -p $PID > /dev/null 2>&1
    if [ $? -eq 0 ]
    then
        echo `date "+[%Y-%m-%d %H:%M:%S]"`" Job is already running"
        exit 1
    else
        echo $$ > $PIDFILE
        if [ $? -ne 0 ]
        then
            echo `date "+[%Y-%m-%d %H:%M:%S]"`" Could not create PID file"
            exit 1
        fi
    fi
    else
    echo $$ > $PIDFILE
    if [ $? -ne 0 ]
    then
        echo `date "+[%Y-%m-%d %H:%M:%S]"`" Could not create PID file"
        exit 1
    fi
fi

# convert retention number to sec 

keep_to_sec () {
    num=`echo $1 |sed -n 's/\([0-9]*\)[smhdwySMHDWY]*/\1/p'`
    sym=`echo $1 |sed -n 's/[0-9]*\([smhdwySMHDWY]\)/\1/p'`
    case "$sym" in
        "s" | "S")
            echo $num
        ;;
        "m" | "M")
            echo $(( $num*60 ))
        ;;
        "h" | "H")
            echo $(( $num*3600 ))
        ;;
        "d" | "D")
            echo $(( $num*3600*24 ))
        ;;
        "w" | "W")
            echo $(( $num*3600*24*7 ))
        ;;
        "y" | "Y")
            echo $(( $num*3600*24*365 ))
            ;;
        *)
            echo $num
            ;;
    esac
}

if [ -n "${sopt}" ]
  then 
    snap_name=${sopt}
  else
    keep_in_sec=$(keep_to_sec $keep_backup)
    if [[ ! $keep_in_sec =~ ^[0-9]+$ ]] 
        then 
            echo `date "+[%Y-%m-%d %H:%M:%S]"`" Retention policy is incorrect: valid format is NUM[smhdwy]" 
            rm -f $PIDFILE
            exit 1
    fi
    # prepare snapshot names
    backup_ts=`date +%s`
    snap_name=`echo $backup_ts | gawk '{print strftime("%F-%H-%M-%S", $0); }'`
fi

#
# build sql command from zfs list
#
if [ -z "$bkp_fs_list" ]
then
    echo `date "+[%Y-%m-%d %H:%M:%S]"`" No filesystem specified" 
    rm -f $PIDFILE
    exit 1
fi

#
# Check ZFS filesystems
#
for ds in $bkp_fs_list
do
  ${ZFS} list ${ds} > /dev/null
  if [ $? -ne 0 ]
  then
    echo "Check bkp_fs_list variable at the beggining of file"
    rm -f $PIDFILE
    exit 1
  fi
done

do_snap_cmd=""
for ds in $bkp_fs_list
do
    if [ -z "$do_snap_cmd" ]
    then
        do_snap_cmd="SYSTEM ${ZFS} snapshot ${ds}@${snap_name}"
        continue
    fi
    do_snap_cmd="SYSTEM ${ZFS} snapshot ${ds}@${snap_name}; $do_snap_cmd"
done

mysql_backup_cmd="set autocommit=0; FLUSH LOGS; FLUSH TABLES WITH READ LOCK; $do_snap_cmd ; UNLOCK TABLES"

${MYSQL} -u $mysql_user -E -e 'show slave status' | grep Slave_IO_Running >/dev/null
[ $? -eq 0 ] &&  mysql_backup_cmd="STOP SLAVE; ${mysql_backup_cmd} ; START SLAVE"


echo `date "+[%Y-%m-%d %H:%M:%S]"`" Running ${mysql_backup_cmd}" 

RES=`${MYSQL} -v -uroot -e "${mysql_backup_cmd}"`
if [ $? -ne 0 ]
then
    echo -e `date "+[%Y-%m-%d %H:%M:%S]"`" MySQL Query error: ${RES}"
    rm -f ${PIDFILE}
    exit 1
fi

# check if snapshots were created successfully"
for ds in $bkp_fs_list
do
    new_snap=`${ZFS} list -rH -t snapshot -o name $ds@${snap_name} 2>/dev/null`
    if [ -z ${new_snap} ]
    then
        echo `date "+[%Y-%m-%d %H:%M:%S]"`" Failed to create snapshot $ds@${snap_name}"
        rm -f $PIDFILE
        exit 1
    fi
    echo `date "+[%Y-%m-%d %H:%M:%S]"`" $new_snap was created"
done

echo "Snapshots were done successfully..."

if [ ! -n "${sopt}" ]
  then
    # do rotation
    echo "Rotation starting..."
    for ds in $bkp_fs_list
    do
        ${ZFS} list -rH -t snapshot -o name $ds \
            | while read ds_snap
        do
            old_snap_name=`echo ${ds_snap} |cut -f2 -d@`
            old_snap_ts=`echo $old_snap_name | tr - ' '| gawk '{print mktime($0); }'`
            if [ $old_snap_ts -eq -1 ]
            then
                echo `date "+[%Y-%m-%d %H:%M:%S]"`" looks like $ds_snap - was created by another program. skipping..."
                continue
            fi
            if [ $(( $backup_ts - $old_snap_ts )) -ge $keep_in_sec ]
            then
                echo `date "+[%Y-%m-%d %H:%M:%S]"`" $ds_snap will be deleted..."
                ${ZFS} destroy $ds_snap
            fi
        done
    done
fi

rm -f $PIDFILE

exit 0
