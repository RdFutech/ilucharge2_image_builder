#!/bin/bash -e
cd /home/futech/Documents/Github/ilucharge2_image_builder
sudo rm -rf work
sudo rm -rf deploy
sudo ./build.sh
# Note this actually only deploys the first one in the list, but we dont know the name here.
./upload_futech.sh deploy/*.pnx #KG temp disabled
