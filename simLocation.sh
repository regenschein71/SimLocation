#!/bin/bash

# Add the file SimLocation (found in the same directory as this script) to your XCode project
# Make sure only the Xcode with the location simulator is running.
#
# Replace the name of the Xcode project and the start coordinates below. Write the 
# coordinates without decimal dot and all 5 decimal places 
#
# Use arrow keys to de-/increase lat and lon values (i.e. step across the map).
# Use number keys to define the step length
# Use the letter row q..t..o to adjust the stepping angle up to +/- 45 degress
# Press x to exit

# These are the default start coordinates if no previous file could be read
# Internally only integer is used for calculations, it is assumed that they always
# have 5 digits after the decimal point.
initLon=677848
initLat=5122315


# Initial step width. Can be changed with number keys 0-9
step=20

#############################################################################
# Nothing to edit below this line
#############################################################################

NEWLINE='\n'

locations=()

# locations+=("Origin,677848,5122315")

# Takes a string of digits and adds a dot at before the fifth column from the right
addDecimal() {
	echo $(sed 's/\(.*\)\(.\{5\}\)/\1.\2/g' <<< "$1")
}

loadLocations() {
	locations=()
	while read loc; do locations+=($loc); done < locations.txt
}

# Try to read coordinates from previous file
if [ -f "SimLocation.gpx" ]
then
	# Try to read the previous file and extract the last coordinates
	read -r lat lon <<< $(sed '/lat=/!d' SimLocation.gpx| awk -F "\"" '{print $2 " " $4}' | sed 's/\.//g' | tail -1)
	# Remove last digit of coordinates (it's the randomized component)
	lon=${lon%?}
	lat=${lat%?}
	echo "Read start position lat: $(addDecimal $lat) / lon: $(addDecimal $lon)"
else
	lat=$initLat
	lon=$initLon
	echo "Default start position: lat: $(addDecimal $lat) / lon: $(addDecimal $lon)"
fi

# Creates a list of waypoints with an added 6th randomized decimal digit. Xcode will
# 'walk' the list of waypoints, making some small random movements.
randomWaypoints() {

	local latOrig=$1
	local lonOrig=$2
	local __result=$3
	local wp=""

   for ((i=1; i<=50; i++))
   do
   	read -d '' line << _EOF_
  <wpt lat=\"$(addDecimal $latOrig)$(($RANDOM % 10))\" lon=\"$(addDecimal $lonOrig)$(($RANDOM % 10))\">
    <name>WP_$i</name>
  </wpt>
_EOF_

	wp="$wp$line"
   done

   eval $__result="'$wp'"

}

# Update simulator with new location
# $1 - new latitude
# $2 - new longitude1
update() {

	local latNew=$1
	local lonNew=$2

	# echo "Moving from $(addDecimal $lat) / $(addDecimal $lon)"

	echo "Moving to $(addDecimal $latNew) / $(addDecimal $lonNew)"

	randomWaypoints $latNew $lonNew waypoints

	/bin/cat <<EOF >SimLocation.gpx
<?xml version="1.0" encoding="UTF-8" standalone="no" ?>
<gpx>
  $waypoints
</gpx>
EOF

	# You may have to change these menu entries if your Xcode menu
	# entries are named differently (or in another language)
	osascript << EOF > /dev/null
tell application "System Events"
	tell application process "Xcode"
		tell menu bar 1
			tell menu bar item "Debug"
				tell menu "Debug"
					tell menu item "Simulate Location"
						tell menu "Simulate Location"
							click menu item "SimLocation"
						end tell
					end tell
				end tell
			end tell
		end tell
	end tell
end tell
EOF

	lon=$lonNew
	lat=$latNew

}

# Usage: readValue type result
# $1 - description string, "lon" or "lat"
# $2 - current value
# $3 - variable that should hold the entered value (without decimal dot)
readValue() {

	local __result=$3
	local current=$(addDecimal $2)

	echo "Enter new value for $1 ((curent: $current)"

	local user_input
	read user_input

	# Empty string: use current value
	[ -z "$user_input" ] && user_input=$current

	# Convert to 5 decimal places and remove entered decimal point
	user_input=$(awk '{printf "%0.5f\n", $1}' <<< "$user_input" | sed 's/\.//g')
	eval $__result="'$user_input'"

}

# Loop: 
# - display all locations
# - wait for key
# - a: add new: ask name, add name, current long.lat to list
# - d: delete: ask number, delete
# - g: ask number, set current location
# - q: quit to main loop
editLocations() {

	local user_input

	while true;	do

		printf "\nAvailable Locations:\n"
		for i in "${!locations[@]}"; do 
			printf "%s\t%s\n" "$i" "${locations[$i]}"
		done

		printf "Command? (a)dd, (d)elete, (g)o to, e(x)it? "
	    read -r -sn1 t
	    case $t in
		   
		    a) 	printf "\nEnter name for current location: "
		       	read user_input
		       	printf "$user_input\n"
		       	locations+=("$user_input,$lon,$lat")
		        printf '%s\n' "${locations[@]}" > locations.txt
		       	;;

		    d) 	printf "\nEnter index to delete: "
			   	read user_input
		       	printf "$user_input\n"
			   	if [ "$user_input" -ge "${#locations[@]}" ]; then
			   		echo "Invalid Index"
			   		continue
			   	fi
		   		unset 'locations[$user_input]'
		    	printf '%s\n' "${locations[@]}" > locations.txt
	        	loadLocations
			   	;;

		    g)	printf "\nEnter index to load: "
		       	read user_input
		       	printf "$user_input\n"
		       	local loc=${locations[$user_input]}

		       	# TODO: check if user input is within bounds
		       	echo "Loading from $loc"
		       	IFS=',' read -r nam1 lon1 lat1 <<< "${loc}"
		       	echo "name: $nam1 lon: ${lon1} lat: ${lat1}"
		       	lon=${lon1}
		       	lat=${lat1}
		       	return
		       	;;
		 
		    x) 	printf "\nExiting location editor\n"
				return ;;

	 	  esac

 	 done

}


loadLocations

# This is the endless loop to read a keypress and act upon it
while true
do

	offset=$((off * step / 4))
	# Introduce jitter of +/- 10% of current step
	jitMain=$(($RANDOM % (step / 2 + 1) - (step / 4)))
	jitOff=$(($RANDOM % (step / 2 + 1) - (step / 4)))
	# echo "Jitter main $jitMain jitOff $jitOff offset $offset"
    
    read -r -sn1 t
    case $t in

    	# Step right
        A) update $((lat + step + jitMain)) $((lon + offset + jitOff)) ;;

		# Step left
        B) update $((lat - step + jitMain)) $((lon - offset + jitOff)) ;;

		# Step up
        C) update $((lat - offset + jitOff)) $((lon + step + jitMain)) ;;

		# Step down
        D) update $((lat + offset + jitOff)) $((lon - step + jitMain)) ;;

		# Adjust step width
		1) step=1 ; echo Steps: $step ;;
		2) step=5 ; echo Steps: $step ;;
		3) step=10 ; echo Steps: $step ;;
		4) step=20 ; echo Steps: $step ;; 
		5) step=50 ; echo Steps: $step ;;
		6) step=100 ; echo Steps: $step ;;
		7) step=500 ; echo Steps: $step ;;
		8) step=1000 ; echo Steps: $step ;;
		9) step=10000 ; echo Steps: $step ;;
		0) step=100000 ; echo Steps: $step ;;

		# Adjust stepping angle CCW to n/4 of 45 degrees
		q) off=-4 ; echo Offset: $off ;;
		w) off=-3 ; echo Offset: $off ;;
		e) off=-2 ; echo Offset: $off ;;
		r) off=-1 ; echo Offset: $off ;;

		# Reset stepping angle
		t) off=0 ; echo Offset: $off ;;

		# Adjust stepping angle CW to n/4 of 45 degress
		y) off=1 ; echo Offset: $off ;;
		u) off=2 ; echo Offset: $off ;;
		i) off=3 ; echo Offset: $off ;;
		o) off=4 ; echo Offset: $off ;;

		# Enter new longitude value
		k) readValue "lon" $lon lonTmp ; update $lat $lonTmp ;;

		# Enter new latitude value
		l) readValue "lat" $lat latTmp ; update $latTmp $lon ;;
	
	    # Go to locations submenu
	    j) 	editLocations
		   	update $((lat)) $((lon))
			;;

		x) echo "Done." ; exit 0 ;;

   esac


done
