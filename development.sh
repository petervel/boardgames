#!/bin/sh
sed -i.bak '/^name:/ s/\s*$/\-dev/' manifest
./deploy 8426885kuuzvkzt
rm manifest
mv manifest.bak manifest
