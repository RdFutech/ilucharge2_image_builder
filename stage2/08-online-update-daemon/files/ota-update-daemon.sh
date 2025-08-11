#!/bin/bash

CHANNEL="basecamp"

# Check charging state strictly equals "Charging"
MOSQ_STATE=$(mosquitto_sub -t everest_api/evse_manager/var/session_info -C 1 -W 1 | jq -r '.state')
if [ "$MOSQ_STATE" == "Charging" ]; then
  echo "System is currently charging, no updates should be performed..."
  exit 1
fi

# Determine update channel
if [ -f "/mnt/user_data/etc/update_channel" ]; then
  CHANNEL=$(cat /mnt/user_data/etc/update_channel)
fi

METAS="/etc/update.meta"
HWIDS=$(jq -r ".update.hwid" "$METAS")
VERSIONS=$(jq -r ".update.version" "$METAS")

# Temporary download location
DOWNLOADDIR="/mnt/user_data/update"
mkdir -p "$DOWNLOADDIR"

curl "http://pt.futech.be/firmware/ilucharge2/$HWIDS/$CHANNEL/current.meta?current_ver=$VERSIONS" --output "$DOWNLOADDIR/update.meta"
RET=$?
if [ $RET -ne 0 ]; then
  echo "Error: Download failed for http://pt.futech.be/firmware/ilucharge2/$HWIDS/$CHANNEL/current.meta?current_ver=$VERSIONS"
  exit 1
fi

METAU="$DOWNLOADDIR/update.meta"
HWIDU=$(jq -r ".update.hwid" "$METAU")
VERSIONU=$(jq -r ".update.version" "$METAU")
DOWNLOADURI=$(jq -r ".update.download_uri" "$METAU")

rm "$METAU"

# Check hardware ID match
if [ "$HWIDU" != "$HWIDS" ]; then
  echo "Error: Update is for $HWIDU, but our system is $HWIDS."
  exit 2
fi

echo "Update found for our hardware $HWIDS"

# Compare version numbers
if [ "$VERSIONU" -gt "$VERSIONS" ]; then
  echo "New version $VERSIONU (currently installed $VERSIONS)"
  curl "$DOWNLOADURI" --output "$DOWNLOADDIR/update.raucb"
  RET=$?
  if [ $RET -eq 0 ]; then
    echo "Download successful. Installing and rebooting..."
    install_update "$DOWNLOADDIR/update.raucb" --reboot-delete
  else
    echo "Error: File download failed from URI: $DOWNLOADURI"
    exit 1
  fi
else
  echo "Error: Update is not newer: $VERSIONU (currently installed $VERSIONS)"
  exit 0
fi
