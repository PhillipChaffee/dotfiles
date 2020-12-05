#
# ~/.bashrc
#

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

alias ls='ls --color=auto'
PS1='[\u@\h \W]\$ '

## 
# SSH config
##

# Start ssh-agent if it isn't running
SSH_ENV="$HOME/.ssh/environment"

function start_agent {
    echo "Initialising new SSH agent..."
    /usr/bin/ssh-agent | sed 's/^echo/#echo/' > "${SSH_ENV}"
    echo succeeded
    chmod 600 "${SSH_ENV}"
    . "${SSH_ENV}" > /dev/null
    /usr/bin/ssh-add;
}

# Source SSH settings, if applicable

if [ -f "${SSH_ENV}" ]; then
    . "${SSH_ENV}" > /dev/null
    #ps ${SSH_AGENT_PID} doesn't work under cywgin
    ps -ef | grep ${SSH_AGENT_PID} | grep ssh-agent$ > /dev/null || {
        start_agent;
    }
else
    start_agent;
fi

## 
# PATH additions
##

# EB Executables Path
export PATH="/home/phillip/.ebcli-virtual-env/executables:$PATH"

# Powerline
powerline-daemon -q
POWERLINE_BASH_CONTINUATION=1
POWERLINE_BASH_SELECT=1
. /usr/lib/python3.8/site-packages/powerline/bindings/bash/powerline.sh

# Ruby ENV
export PATH=/home/phillip/.rbenv/shims:$PATH

# Rust
export PATH=$HOME/.cargo/env:$PATH

# Personal Path Stuff
export PATH=/home/phillip/path:$PATH

# Add .NET Core SDK tools
export PATH="$PATH:/home/phillip/.dotnet/tools"

## 
# Random scripts
##

complete -C /usr/bin/terraform terraform

##
# Source
##

# Source secrets
source ~/.secrets
