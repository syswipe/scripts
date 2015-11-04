#!/bin/sh

Z_FILE=$1
ALIASES=$2

DEF_CFG=`grep -A 1 "Defined configuration:" $Z_FILE | 
    grep cfg: | awk '{print $2}' | tr -d '\n\r'`

EFF_CFG=`grep -A 1 "Effective configuration:" $Z_FILE | 
    grep cfg: | awk '{print $2}'| tr -d '\n\r'`

if [ "$DEF_CFG" != "$EFF_CFG" ]
then
    echo "Defined config name is differ than Effective config name. Please, check"
    exit 1
fi

CFG_NAME=`echo $DEF_CFG`


while read SRC DST
do
    echo $SRC
    echo $DST | fold -s
#    Z_NAME=`awk '{print $1"___"$2}'`;
#    echo $Z_NAME
#    echo "zonecreate ${Z_NAME},\"${S_WWPN};${DST_WWPN}\""
#    echo "cfgadd ${CFG_NAME},${ZNAME}"
done < ${ALIASES}

echo cfgsave
echo "cfgenable ${CFG_NAME}"
