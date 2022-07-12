#
# ~/.bash_profile
#

[[ -f ~/.bashrc ]] && . ~/.bashrc

# Start X on login
if systemctl -q is-active graphical.target && [[ ! $DISPLAY && $XDG_VTNR -eq 1 ]]; then
  exec startx
fi


export PATH="$HOME/.cargo/bin:$PATH"

eval "$(saml2aws --completion-script-bash)"


# Added by Toolbox App
export PATH="$PATH:/home/phillip/.local/share/JetBrains/Toolbox/scripts"