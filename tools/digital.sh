#!/bin/sh

# Generic script to launch a digital HF app and set the mic and speaker
# to the volume that app needs

# Required settings

# Set this to the name of your USB audio device, arecord -l lists them
# Make sure this is unique, if needed, add more to the pattern to match,
# such as if you have two C-Media USB cards or such in this example.
cardname='C-Media'

# Don't touch below here!

# Command line parameters

# Program to execute
program=$1
# Mic level
mic=$2
# Speaker level
speaker=$3
# (Optional) Output power to set on radio
power=$4

# Example to run wsjtx at mic=5, speaker=10, at 20 watts
#  digital.sh /bin/wsjtx 5 10 20

if [ "$program" == "" ] || [ "$mic" == "" ] || [ "$speaker" == "" ]; then
    echo "Program, mic, and speaker are required, exiting"
    echo "$0 program mic speaker [poweroutput]"
    exit
fi

card=`arecord -l | grep $cardname | cut -f 2 -d " " | cut -f 1 -d ":"`

# Dynamically get the card to use

if [ "$card" -eq "$card" ] 2>/dev/null; then
  echo -n
else
 echo "Did not find $cardname to determine a valid card number:  $card"
 exit
fi

if [ "$power" != "" ]; then
    echo L RFPOWER $power | rigctl -m 2
fi

$program &

sleep 5s

# Turn off AGC and set mic and speaker volumes
amixer -q -c $card sset "Auto Gain Control" off
amixer -q -c $card sset "Mic" $mic
amixer -q -c $card sset "Speaker" $speaker
