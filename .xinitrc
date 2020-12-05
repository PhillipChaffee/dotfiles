[[ -f ~/.Xresources ]] && xrdb -merge ~/.Xresources
setxkbmap -option caps:swapescape
exec i3
