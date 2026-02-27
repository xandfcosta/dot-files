#!/bin/bash
is_playing=$(playerctl -p spotify status)
if [[ $is_playing != "Playing" ]]
then
   rm "/tmp/cover.jpeg"
   exit
fi

album_art=$(playerctl -p spotify metadata mpris:artUrl)
if [[ -z $album_art ]] 
then
   rm "/tmp/cover.jpeg"
   exit
fi
curl -s  "${album_art}" --output "/tmp/cover.jpeg"
echo "/tmp/cover.jpeg"
