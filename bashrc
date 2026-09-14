# ~/dotfiles/bashrc -- per-interactive-shell bash configuration
#
# MACOS: this assumes the shell is a current Homebrew bash
# (/opt/homebrew/bin/bash on Apple silicon, /usr/local/bin/bash on Intel), NOT
# Apple's /bin/bash, which is frozen at 3.2 from 2007 and never updated because
# bash went GPLv3 in 4.0. See the longer note at the top of
# ~/dotfiles/bash_profile for the brew install / chsh / tmux default-shell
# steps. 'echo $BASH_VERSION' starting with "3.2" means you are on Apple's.
#
# ---------------------------------------------------------------------------
# WHAT BELONGS IN THIS FILE, AND WHAT BELONGS IN ~/dotfiles/bash_profile
# ---------------------------------------------------------------------------
# This file is read once per interactive shell: every tmux pane, every nested
# 'bash', every subshell. ~/dotfiles/bash_profile is read once per login and
# sources this file at its end, so a login shell gets both.
#
# Put it HERE when it is:
#   * a prompt, alias, shell function, completion, or key binding
#   * a shopt or set -o
#   * history BEHAVIOR: HISTCONTROL, HISTIGNORE, histappend, cmdhist
#   * an interactive preference exported for child programs (EDITOR, LESS,
#     PAGER, CDPATH). Cheap to re-set, and harmless to re-set.
#
# Put it in ~/dotfiles/bash_profile instead when it is:
#   * anything that changes PATH
#   * a tool bootstrap that shells out or eval's -- brew shellenv, pyenv init,
#     rvm, nvm, cargo -- because those are slow and only need to run per login
#   * OS detection
#   * history FILE sizing, HISTSIZE / HISTFILESIZE
#
# HARD RULE: do not modify PATH in this file. A login shell exports PATH to
# every child, so a PATH edit here is re-applied at each nesting level (login
# shell -> tmux pane -> subshell) and the entry accumulates. That is how
# ~/.rvm/bin came to appear in PATH three times.
# ---------------------------------------------------------------------------

# Only if interactive bash with a terminal!
# Written as an explicit if rather than [ p -a q ] || return: -a inside [ ] is
# not well defined by POSIX and misparses when an operand looks like an
# operator (shellcheck SC2166), and 'A && B || C' would invite SC2015.
if [ ! -t 1 ] || [ -z "$BASH_VERSION" ]; then
	return
fi

# Failsafe. This should be set when we're called, but if not, the "not found"
# error messages should be pretty clear.
# Use leading ':' to prevent this from being run as a program after it is
# expanded.
: ${SETTINGS:='SETTINGS_variable_not_set'}

# Set this so we can differentiate between Linux/SunOS specifics items.
# bash_profile exports UNAME_S, so normally this costs nothing; the fallback is
# for a non-login shell that somehow started without a login ancestor.
if [[ -z "$UNAME_S" ]]; then
	if [[ -x /usr/bin/uname ]]; then
		# MacOS
		UNAME=/usr/bin/uname
	elif [[ -x /bin/uname ]]; then
		# Linux, Solaris
		UNAME=/bin/uname
	fi

	UNAME_S=$(${UNAME} -s)
fi

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
[ -r "$HOME/.keychain/${HOSTNAME}-sh" ] &&
	source "$HOME/.keychain/${HOSTNAME}-sh"
[ -r "$HOME/.keychain/${HOSTNAME}-sh-gpg" ] &&
	source "$HOME/.keychain/${HOSTNAME}-sh-gpg"

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
	xterm* | rxvt*)
    # TODO: This needs fixing so xterm/rxvt will look correct
    :
    # PROMPT_COMMAND='history -a; echo -ne "\033]0;${USER}@${HOSTNAME}:$PWD\007"'
		;;
	esac
	;;
esac

# Ghostty shell integration
if [[ -n "${GHOSTTY_RESOURCES_DIR}" ]]; then
  builtin source "${GHOSTTY_RESOURCES_DIR}/shell-integration/bash/ghostty.bash"
fi

# Make sure custom inputrc is handled, if we can find it; note different
# names. Also note different order, since for this one we probably want
# our custom settings to override the system file, if present.
for file in $SETTINGS/inputrc ~/.inputrc /etc/inputrc; do
	[ -r "$file" ] && export INPUTRC="$file" && break # Use first found
done

# No core files by default
# See also /etc/security/limits.conf on many Linux systems.
# ulimit -S -c 0 > /dev/null 2>&1

# Set various aspects of the bash history.
#
# HISTSIZE/HISTFILESIZE are set in bash_profile, not here: they control how
# much of ~/.bash_history survives, and with histappend on, an unset
# HISTFILESIZE makes bash truncate that file to 500 lines on exit. The two
# lines below are a floor, not the real setting -- they only bite for a shell
# that started with no login ancestor, and they exist because the failure mode
# is silent, immediate data loss. Change the real values in bash_profile.
: "${HISTSIZE:=500000}"
: "${HISTFILESIZE:=500000}"
export HISTSIZE HISTFILESIZE
#export HISTCONTROL=ignoreboth # bash < 3, omit dups & lines starting with spaces
# Note what erasedups does and does not do here: it drops older duplicates from
# the IN-MEMORY list, which is what makes up-arrow within a session tidy. It
# does not dedupe ~/.bash_history, because 'history -a' only ever appends the
# new lines. Tested: the resulting file is byte-identical with and without
# erasedups, so this is not worth 'fixing' by removing -- you would lose the
# in-session tidiness and gain nothing.
export HISTCONTROL='erasedups:ignoredups:ignorespace'
# '[ ]*' is one space followed by anything, i.e. lines starting with a space --
# which duplicates ignorespace above. '&' is the useful half: skip a line that
# repeats the one before it.
export HISTIGNORE='&:[ ]*' # bash >= 3, omit dups & lines starting with spaces
#export HISTTIMEFORMAT='%Y-%m-%d_%H:%M:%S_%Z=' # bash >= 3, timestamp hist file
shopt -s histappend      # Append rather than overwrite history on exit

# Flush each command to $HISTFILE as it is entered, rather than only at exit.
# Without this, a shell that is killed (or a machine that loses power) takes
# the whole session's history with it, and concurrent tmux panes never see each
# other's commands until they exit.
#
# Appended rather than assigned, and deliberately NOT exported. Ghostty's shell
# integration has usually already installed __ghostty_hook / bash-preexec into
# PROMPT_COMMAND by this point, and a plain assignment would silently delete
# it. PROMPT_COMMAND is a string in bash <= 5.0 and may be an array in 5.1+, so
# match whichever it already is. Exporting it, as the old .bash_profile did,
# leaks 'history -a' into every non-interactive child shell.
if [[ "${PROMPT_COMMAND[*]:-}" != *"history -a"* ]]; then
	if [[ -z "${PROMPT_COMMAND[*]:-}" ]]; then
		PROMPT_COMMAND="history -a"
	elif [[ $(declare -p PROMPT_COMMAND 2>/dev/null) == "declare -a "* ]]; then
		PROMPT_COMMAND+=("history -a")
	else
		# shellcheck disable=SC2179 # this branch is the non-array case
		PROMPT_COMMAND+=$'\nhistory -a'
	fi
fi

shopt -q -s cdspell      # Auto-fix minor typos in interactive use of 'cd'
shopt -q -s checkwinsize # Update the values of LINES and COLUMNS
shopt -q -s cmdhist      # Make multiline commands 1 line in history
set -o notify            # (or set -b) # Immediate notif. of background
# job termination.
# set -o ignoreeof              # Don't let Ctrl-D exit the shell
set -o vi # Vi command line editing mode

# Other bash settings
# PATH is built entirely in bash_profile now -- see the HARD RULE at the top.
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
	# Quoted: lesspipe prints LESSOPEN='||... %s' as a single assignment, and
	# unquoted it word-splits on the spaces inside the value (SC2046).
	[ -x "$path/lesspipe.sh" ] && eval "$("$path/lesspipe.sh")" && break
	[ -x "$path/lesspipe" ] && eval "$("$path/lesspipe")" && break
done

# Set other less & editor prefs (overkill)
#export LESS="--LONG-PROMPT --LINE-NUMBERS --ignore-case --QUIET --no-init"
export LESS="--LONG-PROMPT --ignore-case --QUIET --no-init -R"
export VISUAL='vi' # Set a default that should always work
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
export EDITOR="$VISUAL"     # Yet Another Possibility
export SVN_EDITOR="$VISUAL" # Subversion
alias edit=$VISUAL          # Provide a command to use on all systems

# Set ls options and aliases.
# Note all the colorizing may or may not work depending on your terminal
# emulation and settings, esp. ANSI color. But it shouldn't hurt to have.
# See above notes re: nano for why we're using this for loop.
for path in ${PATH//:/ }; do
	# -b forces Bourne-shell syntax. Bare 'dircolors' guesses from $SHELL and
	# warns 'no SHELL environment variable, and no shell type option given'
	# whenever that is unset -- cron, containers, env -i. This only started
	# mattering once coreutils was installed and the branch could actually run.
	[ -r "$path/dircolors" ] && eval "$(dircolors -b)" &&
		LS_OPTIONS='--color=auto' && break
done
# Fall back to BSD ls colouring when there is no GNU dircolors. On MacOS
# without Homebrew coreutils installed, the loop above finds nothing, so
# LS_OPTIONS stayed empty and ls had no colour at all; BSD ls spells it -G.
if [ -z "$LS_OPTIONS" ] && [ "${UNAME_S}" = "Darwin" ]; then
	LS_OPTIONS='-G'
fi
export LS_OPTIONS="$LS_OPTIONS -F -h"
# Using dircolors may cause csh scripts to fail with an
# "Unknown colorls variable 'do'." error.  The culprit is the ":do=01;35:"
# part in the LS_COLORS environment variable.  For a possible solution see
# http://forums.macosxhints.com/showthread.php?t=7287
# eval "$(dircolors)"
alias ls="ls $LS_OPTIONS"
alias ll="ls $LS_OPTIONS -l"
alias ll.="ls $LS_OPTIONS -ld" # Usage: ll. ~/.*
alias la="ls $LS_OPTIONS -la"
alias lrt="ls $LS_OPTIONS -alrt"

################### Utility Functions #######################################
ensure_git_config() {
  local key="${1}"
  local value="${2}"

  if ! command -v git &> /dev/null; then
    echo "git not present, cannot set git config"
  else
    if ! git config --get "$key" > /dev/null 2>&1; then
      echo "Setting git config $key to '$value'..."
      git config --global "$key" "$value"
    fi
  fi
}

ensure_git_aliases() {
  local key="${1}"
  local value="${2}"

  if ! command -v git &> /dev/null; then
    echo "git not present, cannot set git aliases"
  else
    if ! git config --get "alias.${key}" > /dev/null 2>&1; then
      echo "Setting git alias.${key} to '$value'..."
      git config --global "alias.${key}" "$value"
    fi
  fi
}
#############################################################################

# Useful aliases
# Moved to a function: alias bot='cd $(dirname $(find . | tail -1))'
#alias clip='xsel -b'         # pipe stuff into right "X" clipboard
alias clr='cd ~/ && clear'          # Clear and return $HOME
alias diff='diff -u'                # Make unified diffs the default
#################################
# git related BEGIN
alias ga="git add"
alias gc="git commit"
alias gco="git checkout"
alias gdiff="git diff"
alias gl="git prettylog"
alias glo="git log --oneline --graph --pretty=format:'%h %ad %s [%an]' --date=local"
alias gp="git push"
alias gs="git status"
alias gt="git tag"
# Git related configuration.
#
# Guarded twice over:
#
#  * 'declare -A' is bash 4.0+. On Apple's /bin/bash 3.2, or an old Solaris
#    bash, the unguarded version does not abort the file -- execution carries
#    on and everything below still loads -- but it spews 'declare: -A: invalid
#    option' plus an arithmetic syntax error per dotted key on EVERY shell
#    start, and silently applies none of the settings. Keys without a dot are
#    worse than noisy: 3.2 treats the subscript as arithmetic, so "co" and
#    "ci" both evaluate to 0 and quietly overwrite each other.
#
#  * _GIT_CONFIG_ENSURED is exported, so this runs once per login rather than
#    once per interactive shell. The loops spawn a 'git config --get' per
#    entry, measured at ~250ms, which every tmux pane was paying to re-check
#    settings that were already correct.
if [ -z "$_GIT_CONFIG_ENSURED" ] && [ "${BASH_VERSINFO[0]:-0}" -ge 4 ]; then
declare -A git_config git_alias
git_config["user.name"]="Gordon Marler"
git_config["credential.helper"]="store"
git_config["credential.https://github.com.username"]="gmarler"
git_config["push.default"]="tracking"
git_config["init.defaultBranch"]="main"
git_alias["ci"]="commit"
git_alias["co"]="checkout"
git_alias["prettylog"]="log --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(r) %C(bold blue)<%an>%Creset' --abbrev-commit --date=relative"
git_alias["root"]="rev-parse --show-toplevel"
# $value MUST be quoted here. Unquoted, a multi-word value word-splits and only
# its first word reaches the function's $2, so on a machine where these are not
# already set you silently get user.name=Gordon, alias.root=rev-parse, and a
# prettylog truncated to 'log'. Harmless on a box where they are already right,
# which is exactly why it survives unnoticed -- and broken on a fresh one.
for key in "${!git_config[@]}"; do
  value="${git_config[$key]}"
  ensure_git_config "$key" "$value"
done
for key in "${!git_alias[@]}"; do
  value="${git_alias[$key]}"
  ensure_git_aliases "$key" "$value"
done
unset git_config git_alias key value
export _GIT_CONFIG_ENSURED=1
fi
# git related END
#################################
alias hu='history -n && history -a' # Read new hist. lines; append current lines
alias hr='hu'                       # "History update" backward compat to 'hr'
alias lesss='less -S'               # Don't wrap lines
alias locate='locate -i'            # Case-insensitive locate
alias man='LANG=C man'              # Display manpages properly
#alias open='gnome-open'     # Open files & URLs using GNOME handlers; see run below
#alias ping='ping -c4'        # Only 4 pings by default
alias r='fc -s' # Recall and execute 'command' starting with...
# Tweaked from http://bit.ly/2fc4e8Z
alias randomwords="shuf -n102 /usr/share/dict/words \
  | perl -ne 'print qq(\u\$_);' | column"
alias reloadbind='rndc -k /etc/bind/rndc.key freeze \
  && rndc -k /etc/bind/rndc.key reload && rndc -k /etc/bind/rndc.key thaw'
# Reload dynamic BIND zones after editing db.* files
alias top10='sort | uniq -c | sort -rn | head'
alias vzip='unzip -lvM' # View contents of ZIP file
alias wgetdir="wget --no-verbose --recursive --no-parent --no-directories \
 --level=1" # Grab a whole directory using wget
alias wgetsdir="wget --no-verbose --recursive --timestamping --no-parent \
 --no-host-directories --reject 'index.*'" # Grab a dir and subdirs
alias zonex='host -l'                      # Extract (dump) DNS zone

# Date/time
alias iso8601="date '+%Y-%m-%dT%H:%M:%S%z'" # ISO 8601 time
alias now="date       '+%F %T %Z(%z)'"      # More readable ISO 8601 local
alias utc="date --utc '+%F %T %Z(%z)'"      # More readable ISO 8601 UTC

# git WIP aliases/function
# (https://itnext.io/multitask-like-a-pro-with-the-wip-commit-2f4d40ca0192)
alias gwip='git add -A; git rm $(git ls-files --deleted) 2> /dev/null; git commit --no-verify --no-gpg-sign --message "--wip-- [skip ci]"'
alias gunwip='git rev-list --max-count=1 --format="%s" HEAD | grep -q "\--wip--" && git reset HEAD~1'
# Similar to `gunwip` but recursive "Unwips" all recent `--wip--` commits not just the last one
function gunwipall() {
	local _commit=$(git log --grep='--wip--' --invert-grep --max-count=1 --format=format:%H)

	# Check if a commit without "--wip--" was found and it's not the same as HEAD
	if [[ "$_commit" != "$(git rev-parse HEAD)" ]]; then
		git reset $_commit || return 1
	fi
}

if [[ "${UNAME_S}" == "Linux" ]]; then
	alias gc='xsel -b'  # "GetClip" get stuff from right "X" clipboard
	alias pc='xsel -bi' # "PutClip" put stuff to right "X" clipboard
	alias cal='cal -M'  # Start calendars on Monday
	alias df='df --print-type --exclude-type=tmpfs --exclude-type=devtmpfs'
	alias inxi='inxi -c19' # (Ubuntu) system information script
	alias jdiff="\diff --side-by-side --ignore-case --ignore-blank-lines\
    --ignore-all-space --suppress-common-lines" # Useful GNU diff command
	alias ntsysv='rcconf'                          # Debian rcconf is pretty close to Red Hat ntsysv
	alias pathping='mtr'                           # mtr - a network diagnostic tool
	#
	# Neat stuff from http://xmodulo.com/useful-bash-aliases-functions.html
	#
	alias meminfo='free -m -l -t'  # See how much memory you have left
	alias whatpid='ps auwx | grep' # Get PID and process info
	alias port='netstat -tulanp'   # Show which apps are connecting to the network

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

# nix related aliases (mostly related to Bloomberg CA Cert handling
alias nix_prefix="NIX_SSL_CERT_FILE=~gmarler/CA-Certs/ALL-CERTS \
  CURL_CA_BUNDLE=~gmarler/CA-Certs/ALL-CERTS \
  https_proxy=http://localhost:8888/ http_proxy=http://localhost:8888/ "

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
	# Date/time aliases. These used to hard-code gdate, which only exists if
	# Homebrew coreutils is installed -- it is not on every machine, and when
	# it is missing all three aliases just fail with 'gdate: command not
	# found'. Prefer gdate when present, otherwise use BSD date, which handles
	# these same format strings; only the UTC flag differs (--utc vs -u).
	if command -v gdate >/dev/null 2>&1; then
		alias iso8601="gdate '+%Y-%m-%dT%H:%M:%S%z'" # ISO 8601 time
		alias now="gdate       '+%F %T %Z(%z)'"      # Readable ISO 8601 local
		alias utc="gdate --utc '+%F %T %Z(%z)'"      # Readable ISO 8601 UTC
	else
		alias iso8601="date '+%Y-%m-%dT%H:%M:%S%z'"
		alias now="date    '+%F %T %Z(%z)'"
		alias utc="date -u '+%F %T %Z(%z)'"
	fi
	# HomeBrew Bash completions, if present
	if [[ -f "${HOMEBREW_PREFIX:-/opt/homebrew}/etc/bash_completion" ]]; then
		. "${HOMEBREW_PREFIX:-/opt/homebrew}/etc/bash_completion"
	fi
	# SSH shortcuts. These live here rather than in bash_profile so they exist
	# in tmux panes too -- aliases are not inherited by child shells.
	alias sshdev="ssh -tt v5dev inline"
	alias sshprod="ssh -tt v5prod inline"
fi

# If the script exists and is executable, create an alias to get
# web server headers
for path in ${PATH//:/ }; do
	[ -x "$path/lwp-request" ] && alias httpdinfo='lwp-request -eUd' && break
done

# Useful functions
parse_git_branch() {
	git branch 2>/dev/null | sed -e '/^[^*]/d' -e 's/* \(.*\)/ (\1)/'
}

export BASH_SILENCE_DEPRECATION_WARNING=1

# nvm itself is loaded in bash_profile (it puts a node on PATH); only the
# completion belongs here.
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

# fzf: completion and key bindings. This one does append ~/.fzf/bin to PATH,
# which is why bash_profile runs a dedupe pass after sourcing this file.
[ -f ~/.fzf.bash ] && source ~/.fzf.bash

# --- ksh93-style function autoloading --------------------------------------
# $FPATH is a colon-separated list of directories (set in bash_profile, since
# it is exported environment). A file named <fn> in one of them is expected to
# define a shell function named <fn>; the file is not read until the first time
# <fn> is called.
#
# Why this is NOT built on command_not_found_handle, which is the obvious
# approach and is what used to live here: bash runs that hook in a FORKED
# CHILD. Sourcing the function file there defines it in a process that exits
# microseconds later, so the definition is discarded, the file is re-read on
# every single call, and -- the real problem -- any cd, variable assignment or
# export the function performs is lost along with the child. A function like
#     bot() { cd "$(dirname "$(find . | tail -1)")"; }
# would silently appear to do nothing. Verified on bash 5.2.37.
#
# So do what ksh93's 'autoload' actually does: declare a cheap stub now, and
# let it replace itself with the real definition on first call. A stub is an
# ordinary function, so it runs in THIS shell and the sourced definition sticks.
: "${FPATH:=$HOME/.bash_functions}" # floor, in case bash_profile did not run

# Search $FPATH for the file defining function $1 and source it.
# Returns 0 only if the function is actually defined afterwards.
_autoload_load() {
	local name=$1 dir file oldifs=$IFS

	# Split $FPATH on ':' into the positional parameters, then put IFS back
	# BEFORE sourcing anything -- leaving IFS=':' in effect would quietly
	# corrupt word splitting inside the function file we are about to read.
	IFS=:
	set -- $FPATH
	IFS=$oldifs

	for dir in "$@"; do
		[ -n "$dir" ] || continue
		file=$dir/$name
		[ -f "$file" ] && [ -r "$file" ] || continue

		unset -f "$name" # drop the stub; the file supplies the real one
		. "$file"

		declare -F "$name" >/dev/null 2>&1 && return 0

		# The file exists but defined no such function -- an empty
		# placeholder, or a misspelled name inside it. Put the stub back so
		# that fixing the file and calling again just works, no rehash.
		_autoload_stub "$name"
		printf 'bash: %s: %s does not define a function named %s()\n' \
			"$name" "$file" "$name" >&2
		return 1
	done

	printf 'bash: %s: no such file in $FPATH (%s)\n' "$name" "$FPATH" >&2
	return 1
}

# Declare the stub for function $1. fpath_reload has already checked that $1 is
# a plain identifier, which is what makes interpolating it into eval safe.
_autoload_stub() {
	eval "$1() {
		_autoload_load $1 || return 127
		$1 \"\$@\"
	}"
}

# Scan $FPATH and declare a stub for every function file found. Runs at shell
# startup, and by hand after adding a new file. An already-defined function is
# never clobbered, so to pick up edits to a file that has already been loaded:
#     unset -f <name> && fpath_reload
fpath_reload() {
	local dir file name oldifs=$IFS
	IFS=:
	set -- $FPATH
	IFS=$oldifs

	for dir in "$@"; do
		[ -n "$dir" ] && [ -d "$dir" ] || continue
		for file in "$dir"/*; do
			[ -f "$file" ] && [ -r "$file" ] || continue
			name=${file##*/}
			# Plain identifiers only. Skips README, notes.txt, foo.sh,
			# editor backups like 'bot~', and names starting with a digit.
			case $name in
			'' | [0-9]* | *[!A-Za-z0-9_]*) continue ;;
			esac
			declare -F "$name" >/dev/null 2>&1 && continue
			_autoload_stub "$name"
		done
	done
}

fpath_reload

# A file dropped into $FPATH after this shell started has no stub, so bash
# reports it as not found. Catch just that case and say something actionable.
# This hook runs in a forked child (see above), so it can print but cannot
# define anything -- hence telling you to rehash rather than trying to load.
#
# Note this replaces any distro-provided handler, e.g. Ubuntu's
# command-not-found package that suggests which apt package to install.
command_not_found_handle() {
	local cmd=$1 dir file oldifs=$IFS
	IFS=:
	set -- $FPATH
	IFS=$oldifs

	for dir in "$@"; do
		[ -n "$dir" ] || continue
		file=$dir/$cmd
		if [ -f "$file" ] && [ -r "$file" ]; then
			printf "bash: %s: %s exists but was added after this shell started; run 'fpath_reload'\n" \
				"$cmd" "$file" >&2
			return 127
		fi
	done

	printf 'bash: %s: command not found\n' "$cmd" >&2
	return 127
}

# Custom local overrides
if [[ -f "$HOME/.bashrc.custom" ]]; then
	echo "Sourcing Custom .bashrc.custom"
	source $HOME/.bashrc.custom
fi

# The perl5 local::lib block that local::lib appended here, and the
# $HOME/.local/bin prepend that followed it, were moved to bash_profile during
# the merge of upstream aab523e: both write to PATH, which this file must not
# do, and the perl5 one had /home/gmarler hard-coded so it was wrong on MacOS.
# If local::lib ever re-appends its block here, move it back over there.
