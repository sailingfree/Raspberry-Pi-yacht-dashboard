#!/bin/bash
# Run the dashboard if there isnot one already running

prog=/home/pete/Raspberry-Pi-yacht-dashboard/Dashboard.pl
pgrep Dashboard.pl > /dev/null
if [ X$? == X1 ]; then
	echo Starting
	$prog &
else 
	echo Already running
fi
