#
# ~/.bashrc
#

# Set vim as editor
export EDITOR=vim

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

# Source dev env vars
source ~/.dev-env

# Set up Node Version Manager
source /usr/share/nvm/init-nvm.sh

# Source VoiceOps stuff
source ~/.voiceops_helpers

##
# Helper Functions
##

# HashiCorp helpers

vlogin() {
    if ! vault login -method=oidc -path=okta >/dev/null 2>&1 ; then
        printf "Error signing you in, please try manually\n"
    fi
}

ntok() {
    if ! vault token lookup >/dev/null 2>&1 ; then
        vlogin
    fi

    if ! nomad acl token self -token "$(jq -r .data.secret_id < ~/.nomad-token)" > /dev/null 2>&1 ; then
        vault read -format json nomad/creds/$NOMAD_ROLE > ~/.nomad-token
    fi

    NOMAD_TOKEN=$(jq -r .data.secret_id < ~/.nomad-token) 
    export NOMAD_TOKEN
    echo $NOMAD_TOKEN
}

nkeepalive() {
    ntok

    while vault lease renew "$(jq -r .lease_id < ~/.nomad-token)" > /dev/null 2>&1 ; do
        sleep 300
    done
}

ctok() {
    if ! vault token lookup >/dev/null 2>&1 ; then
        vlogin
    fi

    if ! consul acl token read -id "$(jq -r .data.accessor < ~/.consul-token)" > /dev/null 2>&1 ; then
        vault read -format json consul/creds/$CONSUL_ROLE > ~/.consul-token
    fi
    
    CONSUL_HTTP_TOKEN=$(jq -r .data.token < ~/.consul-token)
    export CONSUL_HTTP_TOKEN
}

ckeepalive() {
    ctok

    while vault lease renew "$(jq -r .lease_id < ~/.consul-token)" > /dev/null 2>&1 ; do
        sleep 300
    done
}

prodaccess() {
    nkeepalive &
}

n_has_namespace() {
  if [[ -z "$NOMAD_NAMESPACE" || "$NOMAD_NAMESPACE" == '*' ]]; then
    echo "found NOMAD_NAMESPACE of '$NOMAD_NAMESPACE'  -- you must define a specific value for this env var, e.g. 'platform'" >&2
    return 1
  else
    return 0
  fi
}

njs() {
  # Nomad Job Status
  cmd_help_text="\`njs <nomad_job>\`   e.g. \`njs 'rails'\`"

  n_has_namespace || return 1
  
  nomad_job="$1"
  if [[ -z "$nomad_job" ]]; then
    echo "njs: no \$1 specified for $cmd_help_text" >&2
    return 1
  fi

  #nomad job status -namespace platform "$nomad_job"
  nomad job status "$nomad_job"
}

egrep_escape() {
  # https://stackoverflow.com/a/16951928
  sed 's/[][\.|$(){}?+*^]/\\&/g' <<< "$1"
}

njob_periodic() {
  # given a base job name, e.g. 'integrations-rifco'
  # find the running periodic job name, e.g. 'integrations-rifco/periodic-1634157900'
  cmd_help_text="\`njob_periodic <nomad_job>\`   e.g. \`njob_periodic 'integrations-rifco'\`"

  n_has_namespace || return 1

  nomad_job="$1"
  if [[ -z "$nomad_job" ]]; then
    echo "njob_periodic: no \$1 specified for $cmd_help_text" >&2
    return 1
  fi

  nomad_job_escaped=`egrep_escape "$nomad_job"`
  nomad_job_periodic=`njs "$nomad_job" | grep -m 1 -E "^$nomad_job_escaped/periodic-[0-9]+\s+running$" | awk '{print $1}'`
  if [[ -z "$nomad_job_periodic" ]]; then
    echo "njob_periodic: no running periodic job was found for nomad_job='$nomad_job'" >&2
    return 1
  fi

  echo "$nomad_job_periodic"
}

n_alloc() {
  # grab the first allocation_id that is running
  # e.g. "78eb59d1" from "78eb59d1  50af085f  ruby        40       run      running   35m21s ago  34m15s ago"
  cmd_help_text="\`n_alloc <nomad_job> <nomad_task_group>\`   e.g. \`n_alloc 'rails' 'ruby'\`"

  n_has_namespace || return 1

  nomad_job="$1"
  if [[ -z "$nomad_job" ]]; then
    echo "n_alloc: no \$1 specified for $cmd_help_text" >&2
    return 1
  fi

  nomad_task_group="$2"
  if [[ -z "$nomad_task_group" ]]; then
    echo "n_alloc: no \$2 specified for $cmd_help_text" >&2
    return 1
  fi

  nomad_task_group_escaped=`egrep_escape "$nomad_task_group"`

  allocation_id=`njs "$nomad_job" | grep -m 1 -E "^[^\s]+\s+[^\s]+\s+$nomad_task_group_escaped\s+[0-9]+\s+run\s+running" | awk '{print $1}'`
  if [[ -z "$allocation_id" ]]; then
    echo "n_alloc: no running allocation_id was found for nomad_job='$nomad_job' and nomad_task_group='$nomad_task_group'" >&2
    return 1
  fi

  echo "$allocation_id"
}

n_alloc_with_periodic() {
  # this is a wrapper around n_alloc
  # it will first try to find a running allocation_id for $nomad_job
  # if that fails, then it will check and see if:
  #   (1) $nomad_job is actually a periodic job
  #   (2) the periodic job has a running allocation_id
  cmd_help_text="\`n_alloc_with_periodic\` (has the same function signature as \`n_alloc\`)"

  allocation_id=`n_alloc "$@"`
  if [[ -z "$allocation_id" ]]; then
    nomad_job="$1"
    if [[ -z "$nomad_job" ]]; then
      echo "n_alloc_with_periodic: no \$1 specified for $cmd_help_text" >&2
      return 1
    fi
    
    n_has_namespace || return 1

    echo "n_alloc_with_periodic: checking if nomad_job='$nomad_job' is periodic" >&2

    nomad_job_periodic=`njob_periodic "$nomad_job"`
    if [[ -z "$nomad_job_periodic" ]]; then
      echo "n_alloc_with_periodic: no periodic job found for nomad_job='$nomad_job'" >&2
      return 1
    else
      echo "n_alloc_with_periodic: found periodic job of '$nomad_job_periodic' for '$nomad_job'" >&2

      allocation_id=`n_alloc "$nomad_job_periodic" "${@:2}"`
      if [[ -z "$allocation_id" ]]; then
        echo "n_alloc_with_periodic: no running allocation_id was found for nomad_job_periodic='$nomad_job_periodic' and ${@:2}" >&2
        return 1
      fi
    fi
  fi

  echo "$allocation_id"
}

nsh() {
  # Nomad SHell
  cmd_help_text="\`nsh <nomad_job> <nomad_task_group> <nomad_task> <optional shell command>\`   e.g. \`nsh 'rails' 'ruby' 'app' 'rails c'\`"

  # NOMAD_NAMESPACE=platform-staging nsh platform-stage-rep-editable-coaching-form ruby rails
  # NOMAD_NAMESPACE=platform nsh integrations-rifco_ingest python app

  n_has_namespace || return 1
  
  nomad_job="$1"
  if [[ -z "$nomad_job" ]]; then
    echo "nsh: no \$1 specified for $cmd_help_text" >&2
    return 1
  fi

  nomad_task_group="$2"
  if [[ -z "$nomad_task_group" ]]; then
    echo "nsh: no \$2 specified for $cmd_help_text" >&2
    return 1
  fi

  nomad_task="$3"
  if [[ -z "$nomad_task" ]]; then
    echo "nsh: no \$3 specified for $cmd_help_text" >&2
    return 1
  fi

  # optionally, specify specific command to execute in the shell
  sh_cmd_args=()
  sh_cmd="$4"
  if [[ -n "$sh_cmd" ]]; then
    sh_cmd_args+='-c'
    sh_cmd_args+="$sh_cmd"
  fi

  allocation_id=`n_alloc_with_periodic "$nomad_job" "$nomad_task_group"`
  if [[ -z "$allocation_id" ]]; then
    echo "nsh: no running allocation_id was found for job of '$nomad_job'" >&2
    return 1
  fi

  echo "using allocation_id = $allocation_id"
  nomad alloc exec -task "$nomad_task" -i -t "$allocation_id" /bin/sh "${sh_cmd_args[@]}"
}

nrc() {
  nomad_job="$1"
  if [[ -z "$nomad_job" ]]; then
    echo "no \$1 specified for \`nrc <nomad_job>\`" >&2
    return
  fi
  allocation_id=`n_alloc "$nomad_job"`
  if [[ -z "$allocation_id" ]]; then
    echo "no running allocation_id was found for '$nomad_job'" >&2
    return
  fi
  nomad alloc exec -task app -i -t "$allocation_id" /usr/local/bin/bundle exec rails c
}

nbc() {
  nomad_job="$1"
  if [[ -z "$nomad_job" ]]; then
    echo "no \$1 specified for \`nrc <nomad_job>\`" >&2
    return
  fi
  allocation_id=`n_alloc "$nomad_job"`
  if [[ -z "$allocation_id" ]]; then
    echo "no running allocation_id was found for '$nomad_job'" >&2
    return
  fi
  nomad alloc exec -task app -i -t "$allocation_id" /bin/bash
}
