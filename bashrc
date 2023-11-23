# Only if interactive bash with a terminal!
[ -t 1 -a -n "$BASH_VERSION" ] || return

# Failsafe. This should be set when we're called, but if not, the "not found"
# error messages should be pretty clear.
# Use leading ':' to prevent this from being run as a program after it is
# expanded.
: ${SETTINGS:='SETTINGS_variable_not_set'}

# Set this so we can differentiate between Linux/SunOS specifics items
if [[ -x /usr/bin/uname ]]; then
  # MacOS
  UNAME=/usr/bin/uname
elif [[ -x /bin/uname ]]; then
  # Linux, Solaris
  UNAME=/bin/uname
fi

UNAME_S=$(${UNAME} -s)

# DEBUGGING only - will break scp, rsync
# echo "Sourcing $SETTINGS/bash_profile..."
# export PS4='+xtrace $LINENO: '
# set -x

# Debugging/logging - will not break scp, rsync
# case "$-" in
#    *i*) echo "$(date '+%Y-%m-%d_%H:%M:%S_%Z') Interactive" \
#              "$SETTINGS/bashrc ssh=$SSH_CONNECTION" >> ~/rc.log ;;
#    *  ) echo "$(date '+%Y-%m-%d_%H:%M:%S_%Z') Noninteractive" \
#              "$SETTINGS/bashrc ssh=$SSH_CONNECTION" >> ~/rc.log ;;
# esac

# In theory this is also sourced from /etc/bashrc (/etc/bash.bashrc)
# or ~/.bashrc to apply all these settings to login shells too.  In practice
# if these settings only work sometimes (like in subshells), verify that.

# Source keychain file (if it exists) for SSH and GPG agents
[ -r "$HOME/.keychain/${HOSTNAME}-sh" ] \
  && source "$HOME/.keychain/${HOSTNAME}-sh"
[ -r "$HOME/.keychain/${HOSTNAME}-sh-gpg" ] \
  && source "$HOME/.keychain/${HOSTNAME}-sh-gpg"

# Set some more useful prompts
# Interactive command-line prompt
# ONLY set one of these if we really are interactive, since lots of people
# (even us sometimes) test to see if a shell is interactive using
# something like:  if [ "$PS1" ]; then
case "$-" in
  *i*)
    export PROMPT_DIRTRIM=4
    #export PS1='\n[\u@\h t:\l l:$SHLVL h:\! j:\j v:\V]\n$PWD\$ '
    #export PS1='\n[\u@\h:T\l:L$SHLVL:C\!:\D{%Y-%m-%d_%H:%M:%S_%Z}]\n$PWD\$ '
    #export PS1='\n[\u@\h:T\l:L$SHLVL:C\!:J\j:\D{%Y-%m-%d_%H:%M:%S_%Z}]\n$PWD\$ '
    export PS1="\n[\u@\h:T\l:L$SHLVL:C\!:J\j \$(parse_git_branch) ]\n\w \$ "
    #export PS2='> ' # Secondary (i.e. continued) prompt

    #export PS3='Please make a choice: '          # Select prompt
    #export PS4='+xtrace $LINENO: '                # xtrace (debug) prompt
    export PS4='+xtrace $BASH_SOURCE::$FUNCNAME-$LINENO: ' # xtrace prompt

    # If this is an xterm set the title to user@host:dir
    case "$TERM" in
        xterm*|rxvt*)
          PROMPT_COMMAND='echo -ne "\033]0;${USER}@${HOSTNAME}:$PWD\007"'
        ;;
    esac
  ;;
esac

# Make sure custom inputrc is handled, if we can find it; note different
# names. Also note different order, since for this one we probably want
# our custom settings to override the system file, if present.
for file in $SETTINGS/inputrc ~/.inputrc /etc/inputrc; do
    [ -r "$file" ] && export INPUTRC="$file" && break # Use first found
done

# No core files by default
# See also /etc/security/limits.conf on many Linux systems.
# ulimit -S -c 0 > /dev/null 2>&1

# Set various aspects of the bash history
export HISTSIZE=500000        # Num. of commands in history stack in memory
export HISTFILESIZE=500000    # Num. of commands in history file
#export HISTCONTROL=ignoreboth # bash < 3, omit dups & lines starting with spaces
export HISTCONTROL='erasedups:ignoredups:ignorespace'
export HISTIGNORE='&:[ ]*'    # bash >= 3, omit dups & lines starting with spaces
#export HISTTIMEFORMAT='%Y-%m-%d_%H:%M:%S_%Z=' # bash >= 3, timestamp hist file
shopt -s histappend           # Append rather than overwrite history on exit
shopt -q -s cdspell           # Auto-fix minor typos in interactive use of 'cd'
shopt -q -s checkwinsize      # Update the values of LINES and COLUMNS
shopt -q -s cmdhist           # Make multiline commands 1 line in history
set -o notify                 # (or set -b) # Immediate notif. of background
                              # job termination.
# set -o ignoreeof              # Don't let Ctrl-D exit the shell
set -o vi                     # Vi command line editing mode

# Other bash settings
# TODO: Make PATH specific to:
#       - Solaris, - RedHat Linux, - Fedora, - Ubuntu, - MacOS
#PATH="$PATH:/opt/bin"
PATH=${HOME}/bin:${PATH}      # HOME binaries are always first
export MANWIDTH=80            # Manpage width, use < 80 if COLUMNS=80 & less -N
export LC_COLLATE='C'         # Set traditional C sort order (e.g. UC first)
export HOSTFILE='/etc/hosts'  # Use /etc/hosts for hostname completion
export CDPATH='.:~/:..:../..' # Similar to $PATH, but for use by 'cd'
# Note that the '.' in $CDPATH is needed so that cd will work under POSIX mode
# but this will also cause cd to echo the new directory to STDOUT!
# And see also "cdspell" above!

# Import bash completion settings, if they exist in the default location
# and if not already imported (e.g. "$BASH_COMPLETION_COMPAT_DIR" NOT set).
# This can take a second or two on a slow system, so you may not always
# want to do it, even if it does exist (which it doesn't by default on many
# systems, e.g. Red Hat).
if [ -z "$BASH_COMPLETION_COMPAT_DIR" ] && ! shopt -oq posix; then
    if [ -f /usr/share/bash-completion/bash_completion ]; then
      . /usr/share/bash-completion/bash_completion
    elif [ -f /etc/bash_completion ]; then
      . /etc/bash_completion
    fi
fi

# Use a lesspipe filter, if we can find it.  This sets the $LESSOPEN variable.
# Globally replace the $PATH ':' delimiter with space for use in a list.
for path in $SETTINGS ~/ ${PATH//:/ }; do
    # Use first one found of 'lesspipe.sh' (preferred) or 'lesspipe' (Debian)
    [ -x "$path/lesspipe.sh" ] && eval $("$path/lesspipe.sh") && break
    [ -x "$path/lesspipe" ]    && eval $("$path/lesspipe")    && break
done

# Set other less & editor prefs (overkill)
#export LESS="--LONG-PROMPT --LINE-NUMBERS --ignore-case --QUIET --no-init"
export LESS="--LONG-PROMPT --ignore-case --QUIET --no-init -R"
export VISUAL='vi'  # Set a default that should always work
# We'd rather use 'type -P' here, but that was added in bash-2.05b and we use
# systems we don't control with versions older than that.  We can't easily
# use 'which' since that produces output whether the file is found or not.
#for path in ${PATH//:/ }; do
#    # Overwrite VISUAL if we can find nano
#    [ -x "$path/nano" ] \
#      && export VISUAL='nano --smooth --const --nowrap --suspend' && break
#done
# See above notes re: nano for why we're using this for loop
for path in ${PATH//:/ }; do
    # Alias vi to vim in binary mode if we can
    [ -x "$path/vim" ] && alias vi='vim -b' && break
done
export EDITOR="$VISUAL"      # Yet Another Possibility
export SVN_EDITOR="$VISUAL"  # Subversion
alias edit=$VISUAL           # Provide a command to use on all systems

# Set ls options and aliases.
# Note all the colorizing may or may not work depending on your terminal
# emulation and settings, esp. ANSI color. But it shouldn't hurt to have.
# See above notes re: nano for why we're using this for loop.
for path in ${PATH//:/ }; do
    [ -r "$path/dircolors" ] && eval "$(dircolors)" \
      && LS_OPTIONS='--color=auto' && break
done
export LS_OPTIONS="$LS_OPTIONS -F -h"
# Using dircolors may cause csh scripts to fail with an
# "Unknown colorls variable 'do'." error.  The culprit is the ":do=01;35:"
# part in the LS_COLORS environment variable.  For a possible solution see
# http://forums.macosxhints.com/showthread.php?t=7287
# eval "$(dircolors)"
alias ls="ls $LS_OPTIONS"
alias ll="ls $LS_OPTIONS -l"
alias ll.="ls $LS_OPTIONS -ld"  # Usage: ll. ~/.*
alias la="ls $LS_OPTIONS -la"
alias lrt="ls $LS_OPTIONS -alrt"

# Useful aliases
# Moved to a function: alias bot='cd $(dirname $(find . | tail -1))'
#alias clip='xsel -b'         # pipe stuff into right "X" clipboard
alias clr='cd ~/ && clear'   # Clear and return $HOME
alias diff='diff -u'         # Make unified diffs the default
alias hu='history -n && history -a' # Read new hist. lines; append current lines
alias hr='hu'                # "History update" backward compat to 'hr'
alias lesss='less -S'        # Don't wrap lines
alias locate='locate -i'     # Case-insensitive locate
alias man='LANG=C man'       # Display manpages properly
#alias open='gnome-open'     # Open files & URLs using GNOME handlers; see run below
#alias ping='ping -c4'        # Only 4 pings by default
alias r='fc -s'              # Recall and execute 'command' starting with...
# Tweaked from http://bit.ly/2fc4e8Z
alias randomwords="shuf -n102 /usr/share/dict/words \
  | perl -ne 'print qq(\u\$_);' | column"
alias reloadbind='rndc -k /etc/bind/rndc.key freeze \
  && rndc -k /etc/bind/rndc.key reload && rndc -k /etc/bind/rndc.key thaw'
  # Reload dynamic BIND zones after editing db.* files
alias top10='sort | uniq -c | sort -rn | head'
alias vzip='unzip -lvM'      # View contents of ZIP file
alias wgetdir="wget --no-verbose --recursive --no-parent --no-directories \
 --level=1"                  # Grab a whole directory using wget
alias wgetsdir="wget --no-verbose --recursive --timestamping --no-parent \
 --no-host-directories --reject 'index.*'"  # Grab a dir and subdirs
alias zonex='host -l'        # Extract (dump) DNS zone

# Date/time
alias iso8601="date '+%Y-%m-%dT%H:%M:%S%z'"  # ISO 8601 time
alias now="date       '+%F %T %Z(%z)'"       # More readable ISO 8601 local
alias utc="date --utc '+%F %T %Z(%z)'"       # More readable ISO 8601 UTC

if [[ "${UNAME_S}" == "Linux" ]]; then
  alias gc='xsel -b'           # "GetClip" get stuff from right "X" clipboard
  alias pc='xsel -bi'          # "PutClip" put stuff to right "X" clipboard
  alias cal='cal -M'           # Start calendars on Monday
  alias df='df --print-type --exclude-type=tmpfs --exclude-type=devtmpfs'
  alias inxi='inxi -c19'       # (Ubuntu) system information script
  alias jdiff="\diff --side-by-side --ignore-case --ignore-blank-lines\
    --ignore-all-space --suppress-common-lines" # Useful GNU diff command
  alias ntsysv='rcconf'        # Debian rcconf is pretty close to Red Hat ntsysv
  alias pathping='mtr'         # mtr - a network diagnostic tool
  #
  # Neat stuff from http://xmodulo.com/useful-bash-aliases-functions.html
  #
  alias meminfo='free -m -l -t'   # See how much memory you have left
  alias whatpid='ps auwx | grep'  # Get PID and process info
  alias port='netstat -tulanp'    # Show which apps are connecting to the network

  # Ubuntu Packaging (Debian) specific
  if test -x /usr/bin/lsb_release; then
    if /usr/bin/lsb_release -i | grep -q "Ubuntu"; then
      export DEBFULLNAME="Gordon Marler"
      export DEBEMAIL="gmarler@bloomberg.net"
      # Quilt related
      alias dquilt="quilt --quiltrc=${HOME}/.quiltrc-dpkg"
      complete -F _quilt_completion -o filenames dquilt
    fi
  fi
fi

# Admin Server aliases
alias rw="rwin -s"

# MacOS BBVPN host(s)
if [[ "${UNAME_S}" == "Darwin" ]]; then
  # node-proxy aliases
  alias nodeproxy_bbvpn="cd ~/gitwork/nodeproxy &&\
   npx bb-nodeproxy -D --wpadUrl http://wpad.bloomberg.com/wpad-la.dat\
   --proxyAddress 0.0.0.0 --proxyPort 8888"
  alias nodeproxy="cd ~/gitwork/nodeproxy &&\
   npx bb-nodeproxy -D \
   --proxyAddress 0.0.0.0 --proxyPort 8888"
  # Updated PATH settings for MacOS/Brew:
  export PATH="/opt/homebrew/opt/coreutils/libexec/gnubin:$PATH"
  # Date/time alias updates to use GNU coreutils gdate
  alias iso8601="gdate '+%Y-%m-%dT%H:%M:%S%z'"  # ISO 8601 time
  alias now="gdate       '+%F %T %Z(%z)'"       # More readable ISO 8601 local
  alias utc="gdate --utc '+%F %T %Z(%z)'"       # More readable ISO 8601 UTC
  # HomeBrew Bash completions, if present
  if [[ -d /opt/homebrew/etc/bash_completion.d ]]; then
    for bcfile in /opt/homebrew/etc/bash_completion.d/*; do
      [[ -f "$bcfile" ]] && . $bcfile
    done
  fi
fi

# If the script exists and is executable, create an alias to get
# web server headers
for path in ${PATH//:/ }; do
    [ -x "$path/lwp-request" ] && alias httpdinfo='lwp-request -eUd' && break
done


# Useful functions
parse_git_branch() {
     git branch 2> /dev/null | sed -e '/^[^*]/d' -e 's/* \(.*\)/ (\1)/'
}

export BASH_SILENCE_DEPRECATION_WARNING=1

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

# Add RVM to PATH for scripting. Make sure this is the last PATH variable change.
export PATH="$PATH:$HOME/.rvm/bin"

. "$HOME/.cargo/env"

[ -f ~/.fzf.bash ] && source ~/.fzf.bash

# Custom local overrides
if [[ -f "$HOME/.bashrc.custom" ]]; then
  echo "Sourcing Custom .bashrc.custom"
  source $HOME/.bashrc.custom
fi
