#!/bin/sh

Z_FILE=$1

DEF_CFG=`grep -A 1 "Defined configuration:" $Z_FILE | 
    grep cfg: | awk '{print $2}'`

EFF_CFG=`grep -A 1 "Effective configuration:" $Z_FILE | 
    grep cfg: | awk '{print $2}'`

echo $DEF_CFG
echo $EFF_CFG

if [[ "$DEF_CFG" != "$EFF_CFG" ]]
then
    echo "Defined config name is differ than Effective config name. Please, check"
    exit 1
fi

CFG_NAME=${DEF_CFG}


while ( read S_WWPN DST_WWPN $(<$2))
do
    Z_NAME=${S_WWPN}___${DST_WWPN}
    echo "zonecreate ${Z_NAME},\"${S_WWPN};${DST_WWPN}\""
    echo "cfgadd ${CFG_NAME},${ZNAME}"
done

echo cfgsave
echo "cfgenable ${CFG_NAME}"
