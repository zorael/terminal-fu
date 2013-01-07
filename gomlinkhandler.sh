#!/bin/sh


# TL thread: http://www.teamliquid.net/forum/viewmessage.php?topic_id=312503

# -- path to log file
LOG=/tmp/gomlink-$USER			# set to /dev/null if you don't want any logfile
#LOG=/dev/null

# -- video player definitions, modify as you please. put "%s" where filename would be to open the fifo
# vlc works great. caching in milliseconds
PLAYER="vlc --filecaching=3000 "%s" vlc://quit"
# mplayer works but worse than vlc, if picture freezes try seeking to recover
#PLAYER="mplayer -cache 1024 -noconsolecontrols "%s""
# smplayer never starts playing it seems, but including for posterity
#PLAYER="smplayer --close-at-end "%s""

# -- notification manager for graphical error messages. pick one! or none! error messages (such as command not found) get saved to log
#NOTIFYSENDONERROR=1			# "GNU userland" environments, needs notify-send executable (libnotify-bin package or similar)
KDIALOGONERROR=1			# KDE kdialog
#GXMESSAGEONERROR=1			# GNOME gxmessage/gmessage
GROWLONERROR=1				# OSX Growl
#XMESSAGEONERROR=1			# basic and ugly X11 message

# -- advanced options
DRYRUN=1				# dry run; script never starts player, just prints the command it would run. for debugging
USECURL=1				# use curl instead of wget
#USEPERL=1				# use perl instead of sed
#SEDQUIRK="I"				# uncomment if the sed for your platform wants capital I instead of i for case-insensitive matching
					# http://stackoverflow.com/questions/4412945/case-insensitive-search-replace-with-sed

# -- here be dragons
VERSION="1.1"
AGENT="KPeerClient"
REGEXPFREE=".*LiveAddr=\(.*\)\" />.*"
REGEXPPAID=".*REF href=\"\(.*\)\" />"
VALIDSUBSTRING="<COPYRIGHT>(c) Gretech Corp. All Rights Reserved</COPYRIGHT>"
PATHSEPARATOR=":"


# -------------------------------


checkforosx() {
  if [ "$(uname)" = "Darwin" ] 2>>"$LOG"; then
    # operator should apparently just be = and not == under /bin/sh. log stderr here because I don't trust this to be consistent over platforms
    # anyway, we're on OSX! force curl instead of wget, perl instead of sed
    OSX=1
    USECURL=1
    USEPERL=1
  fi
}


clearlog() {
  cat /dev/null > "$LOG"
}


printhelpandexit() {
    echo "usage: $0 --install [PREFIX]"
    echo
    echo "PREFIX should be an absolute path and is usually /usr, /usr/local or ~/.local (default)"
    exit 0
}


stripurlencoding() {
  # see http://en.wikipedia.org/wiki/Percent-encoding
  local url="$*"
  local command
  local I=${SEDQUIRK:-"i"}				# if SEDQUIRK set, use its value as 'i' command. case different on platforms?
  [ "$USEPERL" ] && command="perl -pe" || command="sed"	# if USEPERL set, use perl, else sed. mainly for OSX whose sed has no case-insensitive replace. luckily they share s/1/2/ig syntax

  # add more substitutions as they pop up
  url=$(echo "$url" | $command "
  s/%25/%/${I}g;
  s/%20/ /${I}g;
  s/%21/!/${I}g;
  s/%23/#/${I}g;
  s/%24/\\$/${I}g;
  s/%22/\"/${I}g;
  s/%26/\&/${I}g;
  s/%28/\(/${I}g;
  s/%29/\)/${I}g;
  s/%3a/:/${I}g;
  s/%3d/=/${I}g;
  s/%2e/./${I}g;
  s/%2f/\//${I}g;
  s/%3f/?/${I}g;
  s/%2b/+/${I}g;
  s/%2c/,/${I}g;
  s/%5b/\[/${I}g;
  s/%5d/\]/${I}g;
  s/%5f/_/${I}g;
  s/%7e/~/${I}g;
  s/%40/@/${I}g;
  s/\&amp;/\&/${I}g;
  s/\&quot;/\"/${I}g;") 2>>"$LOG"	# error messages saved to log, because why not
  [ $? -eq 0 ] && echo "$url"
  # empty string "returned" if sed/perl returns errorlevel != 0, stage fails
}


findexec() {
    local file="$1"
    local IFS=$PATHSEPARATOR
    for path in $PATH; do
	absfile=${path}/"$file"
	if [ -x "$absfile" ]; then
	    # found~
	    echo "$absfile"
	    break
	fi
    done
}


refreshmimecache() {
    # try kbuildsycoca4 first UNLESS we're root. kbuildsycoca4 is user-specific
    # sh doesn't know of $UID ?!
    if [ $(id -u) -gt 0 ]; then
	local sycoca="$(findexec kbuildsycoca4)"
	if [ "$sycsoca" ]; then
	    # printf without linebreak to make it pretty"
	    cout stdout "found %s. trying... " kbuildsycoca4
	    # redirect stderr because kbuildsycoca4 is *ALWAYS* spammy
	    "$sycoca" 2>>/dev/null && return 0
	    cout stdout "returned errorlevel ${?}. next!\n"
	fi
    fi

    # we're still here, so we apparently couldn't find kbuildsycoca4 or we're root
    local udb="$(findexec update-desktop-database)"
    if [ "$udb" ]; then
	tryhard "$udb" && return 0
    fi

    # everything seems to have failed D:
    return 1
}


tryhard() {
    # tryhard() tries commands first as user, then with sudo, then with su
    [ ! "$1" ] && return 1
    local command="$1"

    # let's just try it first. redirect stderr. no linebreak
    cout stdout "found %s. trying... " update-desktop-database
    "$command" 2>>/dev/null && return 0
    cout stdout "returned errorlevel ${?}. next!\n"

    # we're still here, so no luck. try sudo. needs linebreak or it'll mess with the password prompt
    local abssudo="$(findexec sudo)"
    cout stdout "found %s. trying %s...\n" sudo "sudo $command"
    if [ "$abssudo" ]; then
	"$abssudo" "$command" && return 0
	echo "returned errorlevel ${?}. next!"
    fi

    # we're still here, so no sudo. try su. include linebreak here too
    local abssu="$(findexec su)"
    cout stdout "found %s. trying %s...\n" su "su -c $command"
    if [ "$abssu" ]; then
	"$abssu" -c "$udb" && return 0
	cout stdout "returned errorlevel ${?}. out of ideas!\n"
    fi

    # we're still here, so failed :<
    return 1
}


installmime() {
    cout log 0 "Mimetype registration start\n\n" # fake stage :>

    if [ "$OSX" ]; then
	cout stdout "Wait, it seems you're on OSX? I'm not sure you want to do this.\n"
	local xdgmime="$(findexec xdg-mime)"
	if [ ! "$xdgmime" ]; then
	    cout stdout "Yeah, you don't. See the TL thread.\n"
	    exit 1
	else
	    cout stdout "Well damn, let's try it.\n"
	fi
  fi
  local prefix failed
  prefix=${1:-"$HOME/.local"}
  if [ "$(echo "$prefix" | cut -c1)" = "/" ] && [ "$(echo "$prefix" | cut -c1 --complement)" ]; then
    # prefix seems okay (and isn't root directory)
    local file="$prefix/share/applications/gomlinkhandler.desktop"
    #log # padding
    cout stdout "Writing desktop file: %s... " "$file"
    [ "$DRYRUN" ] && true || generatedesktopfile > "$file"
    local errorlevel=$?
    if [ $errorlevel -gt -1 ]; then	# errorlevel >0 when writing
	cout stdout "erp.\n"
	cout stdout "Error $errorlevel encountered when trying to write %s! Insufficient permissions?\n" "$file"
	cout stdout "If %s/share/applications/ is outside of your home directory you may need root.\n" "$prefix"
	exit 1
    else
	cout stdout "Attempting mimetype cache refresh...\n"
	refreshmimecache
	local success=$?
	if [ $success -eq 0 ]; then
	    cout stdout "seems to have worked...\n"
	    # try querying xdg for the gomcmd:// protocol handler
	    local xdgmime="$(findexec xdg-mime)"
	    if [ "$($xdgmime query default x-scheme-handler/gomcmd)" = "gomlinkhandler.desktop" ]; then
		cout stdout "xdg-mime confirms mimetype association success!\n"
		exit 0
	    else
		cout stdout "hmm\n"
		exit 1
	    fi
	else
	    #mimecache refresh failed
	    printmimefailinfo "$prefix"
	fi
    fi
  else
    printhelp
  fi
}


generatedesktopfile() {
  cat << EOL
[Desktop Entry]
Name=GOM Link Handler
Type=Application
Exec="${0}" "%u"
Terminal=false
MimeType=x-scheme-handler/gomcmd;
NoDisplay=true
StartupNotify=false
X-KDE-StartupNotify=false
EOL
}

printmimefailinfo() {
    local prefix="$1"
    cat | less << EOL

Okay, so it seems you need to do stuff manually. Woe is you!

Right. What we just did was write a file, namely:
${prefix}/local/share/applications/gomlinkhandler.desktop

.desktop files, such as that one, define applications in a way that graphical
environments may understand them. All sane applications meant to be run in a
GUI have one of their own; like vlc.desktop. They contain definitions like the
applications' full name (eg. "VLC media player"), their longer descriptions
(eg. "Read, capture, broadcast your multimedia streams"), translations of those
two, what mimetypes (filetypes and what protocols) they handle, and much more.
If you want to take a look at one, open yon file manager and browse to:
/usr/bin/share/applications -- you *should* find plenty there.

So, the .desktop file that we just wrote defines the protocol gomcmd:// and
specifies this script (${0}) as its handler.

The go-live links on gomtv.net are gomcmd:// links, which -- on Windows --
get registered by the GOM Player upon installation of it. We don't have that
luxury, so let's claim the protocol for ourselves, yeah?

The thing is, reading through all these .desktop files whenever the user wants
to open a file is very slow and inefficient. What gets done instead is that
they get only read every once in a while (or at particular events) and get
*cached* in a format that komputors read faster.

All well so far -- but this script couldn't force such a refresh. The two major
tools I know of (KDE's kbuildsycoca4, the more general update-desktop-database)
could not be found or executed. You'll have to do some voodoo by yourself.

Anything that could make your environment want to reparse these files! See if
there's a "File Associations" section in your settings someplace. Logging out
and back in should almost *definitely* do it, but that seems a bit excessive.

To try it out just click one of the go-live buttons on the gomtv.net page --
but that's assuming there's a live broadcast at this very present.

Alternatively, try running 'xdg-mime query default x-scheme-handler/gomcmd'
(from a terminal, naturally) and look at its output. If it nicely echoes
'gomlinkhandler.desktop', you're done! Go you!

If it still won't work, sigh in resignation and log out and back in.
If it *STILL* won't work, you may be able to define the protocol and point to
the script manually in your browser. Look through your settings and google
around. There are some semi-helpful links in the TL thread.

http://www.teamliquid.net/forum/viewmessage.php?topic_id=312503

Bring stories!

EOL
}

cout() {
    local type="$1"
    case $type in
	log) # print and log
	    # $1 type, $2 stage, rest printf text
	    local stage="$2"
	    local prefix="$(printf "[%s] [%s]" $(date +%H:%M:%S) $stage)"
	    shift 2 # get rid of stage and type
	    local text="$(printf "$prefix ${@}")"
	    echo "$(printf "$prefix ${@}")"
	    echo "$text" >> "$LOG"
	    ;;
	stdout) # only to stdout
	    # $1 type, rest printf text
	    shift # get rid of type
	    echo "$(printf "$@")"
	    ;;
	error)
	    local stage=$2
	    local text="$3"
	    shift 2
	    cout log $stage "ERROR! "$@""
	    # log stderr because why not
	    [ "$NOTIFYSENDONERROR" ] &&	notify-send -u normal "<b>GOM Link Handler failed stage $stage</b>" "$message <sup><a href=file://"$LOG">[log]</a></sup>" 2>>"$LOG"
	    [ "$KDIALOGONERROR" ] &&	kdialog --title "<b>GOM Link Handler failed stage $stage</b>" --passivepopup "$message <sup><a href=file://"$LOG">[log]</a></sup>" 2>>"$LOG"
	    [ "$GXMESSAGEONERROR" ] &&	gxmessage --center --title "GOM Link Handler" "Failed stage $stage! $message" 2>>"$LOG"
	    [ "$GROWLONERROR" ] &&	growlnotify -t "GOM Link Handler failed stage $stage" -m "$message" 2>>"$LOG"
	    [ "$XMESSAGEONERROR" ] &&	xmessage -center "GOM Link Handler failed stage $stage! $message" 2>>"$LOG"
	    # exit with errors
	    exit 1
	    ;;
    esac
}


# ------------------------------------------------------------------


# Stage -1: terminal dogma
clearlog


# Stage 0: execution start
stage=0
cout log $stage "GOM Link Handler v%s started, logging to %s. Both of you, dance like you want to win\n" "$VERSION" "$LOG"
cout log $stage "DEBUG: dryrun=%d, curl=%d, perl=%d, sedquirk=%s, OSX=%d, player=\"%s %s\"\n" ${DRYRUN:-0} ${USECURL:-0} ${USEPERL:-0} ${SEDQUIRK:-"i"} ${OSX:-0} "${PLAYER:-"ERROR"}" "${ARGS:-"ERROR"}"
checkforosx

case "$1" in
    "-h"|"-H"|"--help"|"-?")
	printhelp
	exit 0
    ;;
    "-i"|"-I"|"--install"|"-?")
	installmime "$2"
	exit 0
    ;;
esac


# Stage 1: print gomcmd link
stage=1
[ ! "$*" ] && cout error $stage "No link supplied by browser"
cout log $stage "gomcmd link: $*"


# Stage 2: get http substring
stage=2
gomurl=$(expr "$*" : ".*http://\(.*\)")
[ ! "$gomurl" ] && cout error $stage "Failed to get http substring from browser link (regexp error)"
cout log $stage "url: http://$gomurl"


# Stage 3: fetch redirection page into variable
stage=3
[ "$USECURL" ] && redirectpage=$(curl -sL --retry 3 "http://$gomurl") || redirectpage=$(wget -qt3 -O- "http://$gomurl")
[ ! "$redirectpage" ] && cout error $stage "Failed to fetch redirect page"
cout log $stage "redirect page contents:\n$redirectpage"


# Stage 4: verify redirection page
stage=4
valid=$(echo $redirectpage | grep "$VALIDSUBSTRING")
if [ "$valid" ]; then
    cout log $stage "redirect page seems valid (contains validity string $VALIDSUBSTRING)"
else
    cout error $stage "Unexpected content when fetching redirection page (router hijack?)"
fi


# Stage 5: parse real stream URL
# different strings for paid streams and free SQ stream
stage=5
encodedurl=$(expr "$redirectpage" : "$REGEXPFREE")
if [ "$encodedurl" ]; then
  # free stream
  cout log $stage "encoded url seems to be for free stream: $encodedurl"
else
  encodedurl=$(expr "$redirectpage" : "$REGEXPPAID")
  if [ "$encodedurl" ]; then
    # paid stream
    cout log $stage "encoded url seems to be for paid stream: $encodedurl"
  else
    cout error $stage "Failed to get percent-encoded URL substring (regexp error)"
  fi
fi


# Stage 6: strip URL percent encoding
stage=6
url=$(stripurlencoding "$encodedurl")
[ ! "$url" ] && cout error $stage "Failed to strip URL of percent-encoded characters (substitution syntax error)"
cout log $stage "decoded url: $url"


# Stage 7: start downloading the stream
# output to named pipe, open stdin with the player, pipe fifo to player's stdin.
# better this way! playing fifos directly seems to work poorly
# see http://forum.videolan.org/viewtopic.php?f=13&t=98012
stage=7
[ "$LOG" ] && fifo="${LOG}-fifo" || fifo=/tmp/gomlink-fifo
[ "$USECURL" ] && streamcmd="curl -sL -A $AGENT --retry 3 "$url" -o "$fifo"" || streamcmd="wget -qt3 -U $AGENT -O "$fifo" "$url""
cout log $stage "full command: $streamcmd &; $PLAYER $ARGS < $fifo"
if [ ! "$DRYRUN" ]; then
  mknod -m 644 "$fifo" p
  $streamcmd &			# fork to background so the player can go ahead
  $PLAYER $ARGS < "$fifo"	# foreground
  err=$?
  rm "$fifo"
fi


# Stage 8: exit
stage=8
cout log $stage "exit $err"
exit $err
