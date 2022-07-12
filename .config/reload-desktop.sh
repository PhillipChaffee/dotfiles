if ! xset q &>/dev/null; then
    echo "No X server at \$DISPLAY [$DISPLAY]" >&2
    exit 1
fi

/usr/bin/xlayoutdisplay; /usr/bin/i3-msg restart;
