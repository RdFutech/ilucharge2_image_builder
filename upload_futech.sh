#!/bin/bash

UPDATE_CHANNEL="unstable"

FN=${1%.*}

META="$FN.meta"
HWID=`jq -r ".update.hwid" $META`
VERSION=`jq -r ".update.version" $META`

export SSHPASS=Futech123

echo "Uploading $FN (HWID $HWID/Version $VERSION) to kristof@pt.futech.be/ilucharge2/${HWID}/${UPDATE_CHANNEL}"

lftp -u kristof,Futech123 pt.futech.be -e "set ftp:ssl-allow no;"<< EOF
   cd subdomains/pt/httpdocs/firmware/ilucharge2
   mkdir ${HWID}
   cd ${HWID}
   mkdir ${UPDATE_CHANNEL}
   cd ${UPDATE_CHANNEL}
   rm current.meta
   rm current.img.gz
   put "$FN.pnx"
   put "$FN.meta"
   put "$FN.meta" -o "current.meta"
   put "$FN.img.gz"
   put "$FN.img.gz" -o "current.img.gz"
   bye
EOF
