#!/bin/sh


# settings
DEV_NAME="AlpsPS/2 ALPS DualPoint TouchPad"
#PROP_DELAY=0.05
#EXIT_ON_ERROR=1


# functions

say() {
	[ $# -gt 0 ] || err NUM_ARGS say $# 1+
	local IFS msg

	case "$1" in
		ERR_NUM_ARGS) msg="[!] invalid number of args passed to '%s'; got %d expected %s" ;;
		ERR_SET_PROP) msg="[!] could not set prop %s to values '%s'" ;;
		ERR_UNKNOWN_ERRCODE) msg="[!] unknown error code '%s'" ;;
		ERR_UNKNOWN_DEVICE) msg="[!] unknown device '%s'" ;;
		INTRO) msg='%s\n------------------------------------------------' ;;
		PROP_SET) msg='[*] %s\n    ... %s' ;;
		LITERAL|ERR_LITERAL) msg="$1" ;;
		*) err UNKNOWN_ERRCODE "$1" ;;
	esac
	shift

	printf -- "${msg}\n" "$@"
}

err() {
	[ $# -gt 0 ] || err NUM_ARGS err $# 1+
	local IFS first
	first="$1"
	shift

	say "ERR_$first" "$@"
	[ "$EXIT_ON_ERROR" ] && exit
}

set_prop() {
	[ $# -gt 1 ] || err NUM_ARGS setProp $# 2+
	local IFS prop
	prop="$1"
	shift

	xinput set-prop "$DEV_NAME" "$prop" "$@" 2>/dev/null \
		&& say PROP_SET "$prop" "$*" \
		|| err SET_PROP "$prop" "$*"
	[ "$PROP_DELAY" ] && sleep $PROP_DELAY
}

verify_device() {
	local IFS retcode
	xinput list "$DEV_NAME" 1>/dev/null 2>/dev/null
	retcode=$?
	[ $retcode -eq 0 ] || err UNKNOWN_DEVICE "$DEV_NAME"
	return $retcode
}

main() {
	local IFS

	verify_device || exit

	say INTRO "$DEV_NAME"

	#set_prop "Device Accel Profile" -1
	set_prop "Device Accel Constant Deceleration" 2.7
	set_prop "Device Accel Velocity Scaling" 13
	set_prop "Synaptics Tap Time" 100
	set_prop "Synaptics Edge Scrolling" 1 1 1
	set_prop "Synaptics Noise Cancellation" 8 8
	set_prop "Synaptics Tap Durations" 50 120 128
	set_prop "Synaptics Coasting Speed" 40 80
	#set_prop "Synaptics Tap Action" 1 1 1 1 1 2 3
	set_prop "Synaptics Finger" 40 40 40
#	set_prop "Synaptics Finger" 49 50 128

	#set_prop "Synaptics"
	return 0
}


# execution start

main "$@"
exit $?
