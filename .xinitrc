[[ -f ~/.Xresources ]] && xrdb -merge ~/.Xresources
setxkbmap -option caps:swapescape
xlayoutdisplay
exec i3
