# ~/.bash_profile -- portable Bash startup for Solaris/Linux/macOS
#
# This file and ~/.bashrc are both symlinks into the dotfiles checkout; runtime
# code refers only to the links in $HOME. See README for installation.
#
# This file is bash-only. For ksh93 on Solaris see ~/dotfiles/profile (login)
# and ~/dotfiles/kshrc (the $ENV file); those two are deliberately left alone.
#
# ---------------------------------------------------------------------------
# STARTUP CONTRACT
# ---------------------------------------------------------------------------
# Bash reads ~/.bash_profile for login shells and ~/.bashrc for non-login
# interactive shells. Ghostty uses login shells on macOS but normally starts
# non-login shells on Linux; a nested `bash` is non-login too. tmux is
# configured to use the login shell by default.
#
# This file owns the shared environment: PATH, tool bootstraps, OS detection,
# and history-file sizing. It exports _BASH_ENV_READY once that work is done.
# A non-login ~/.bashrc with no inherited guard sources this linked profile;
# this profile then sources ~/.bashrc to install interactive preferences. Thus
# every entry point has the same environment, while the slow bootstrap runs
# only once per inherited process tree. A login child still reaches ~/.bashrc
# even when the guard is already present, so aliases and prompt remain loaded.
#
# ---------------------------------------------------------------------------
# MACOS: THIS ASSUMES HOMEBREW BASH, NOT APPLE'S /bin/bash
# ---------------------------------------------------------------------------
# Apple still ships bash 3.2 from 2007 at /bin/bash and will never update it
# (bash moved to GPLv3 in 4.0). This file and ~/.bashrc are written for the
# current Homebrew bash -- /opt/homebrew/bin/bash on Apple silicon,
# /usr/local/bin/bash on Intel -- and are not tested against 3.2.
#
# Getting there, once, on a new Mac:
#     brew install bash
#     echo /opt/homebrew/bin/bash | sudo tee -a /etc/shells
#     chsh -s /opt/homebrew/bin/bash
# and make sure the login shell is /opt/homebrew/bin/bash.
#
# Check with 'echo $BASH_VERSION'. A leading "3.2" means you are on Apple's
# bash and something above did not take.
#
# ---------------------------------------------------------------------------
# WHAT BELONGS IN THIS FILE, AND WHAT BELONGS IN ~/.bashrc
# ---------------------------------------------------------------------------
# For a LOGIN shell bash reads exactly one of ~/.bash_profile, ~/.bash_login,
# ~/.profile -- and nothing else. For a NON-LOGIN interactive shell it reads
# ~/.bashrc and nothing else. The startup contract above bridges that split.
#
# Put the shared environment HERE when it is:
#   * a change to PATH (or MANPATH, FPATH, ...)
#   * a tool bootstrap that shells out or eval's -- brew shellenv, pyenv init,
#     rvm, nvm, cargo. These are slow, so the guard runs them only once per
#     process tree.
#   * OS detection
#   * history FILE sizing, HISTSIZE / HISTFILESIZE (see the next note)
#
# Put it in ~/.bashrc instead when it is:
#   * a prompt, alias, shell function, completion, or key binding
#   * a shopt or set -o
#   * history BEHAVIOR: HISTCONTROL, HISTIGNORE, histappend, cmdhist
#
# HARD RULE: nothing in ~/.bashrc may modify PATH directly. It asks this linked
# file to establish PATH once when needed, avoiding accumulated entries.
#
# Note there is no "is this shell interactive?" guard in this file. Login
# shells are not always interactive ('bash -lc ...', some ssh invocations) and
# they still need a correct PATH. The interactive test lives in ~/.bashrc.
#
# ---------------------------------------------------------------------------
# WHY HISTSIZE/HISTFILESIZE ARE SET HERE RATHER THAN IN ~/.bashrc
# ---------------------------------------------------------------------------
# With 'shopt -s histappend' set, bash on exit appends the session's new
# commands to $HISTFILE and then TRUNCATES that file to $HISTFILESIZE lines.
# An unset HISTFILESIZE means the default: 500.
#
# The previous ~/.bash_profile never sourced ~/.bashrc, so the outer login
# shell -- the one you type 'tmux' into -- ran with that 500-line default,
# while the tmux panes, which do read ~/.bashrc, ran with 500000. Exiting the
# outer shell therefore chopped ~/.bash_history back to 500 lines and discarded
# the day's history. Setting the sizes in the shared environment, which every
# child shell inherits or loads, makes that failure impossible rather than
# merely unlikely.
# ---------------------------------------------------------------------------

# Not bash? Nothing here applies.
[ -n "$BASH_VERSION" ] || return

_bash_env_initialized=false
if [ -z "${_BASH_ENV_READY+x}" ]; then
export _BASH_ENV_READY=1
_bash_env_initialized=true

# --- OS detection ----------------------------------------------------------
# PATH may still be minimal at this point, so find uname by absolute path the
# way ~/.bashrc does. Exported so ~/.bashrc can reuse it instead of re-running.
for _u in /usr/bin/uname /bin/uname; do
	[ -x "$_u" ] && _UNAME=$_u && break
done
UNAME_S=$("${_UNAME:-uname}" -s 2>/dev/null)
export UNAME_S
unset _u _UNAME

# --- PATH helpers ----------------------------------------------------------
# Order-preserving, and they never introduce a duplicate. A directory that does
# not exist is skipped silently, which is what lets one file cover Solaris,
# Linux and MacOS without a thicket of 'if [ -d ... ]' around every entry.

_path_drop() { # remove every occurrence of $1 from PATH
	local dir=$1 out='' entry
	local IFS=:
	for entry in $PATH; do
		[ -n "$entry" ] || continue
		[ "$entry" = "$dir" ] && continue
		out="${out:+$out:}$entry"
	done
	PATH=$out
}

_path_prepend() { # front of PATH; leftmost argument ends up first
	local i dir
	for ((i = $#; i > 0; i--)); do
		dir=${!i}
		[ -d "$dir" ] || continue
		_path_drop "$dir"
		PATH="$dir${PATH:+:$PATH}"
	done
}

_path_append() { # end of PATH; leftmost argument ends up first
	local dir
	for dir in "$@"; do
		[ -d "$dir" ] || continue
		_path_drop "$dir"
		PATH="${PATH:+$PATH:}$dir"
	done
}

_path_dedupe() { # keep only the first occurrence of each entry
	local out='' entry
	local IFS=:
	for entry in $PATH; do
		[ -n "$entry" ] || continue
		case ":$out:" in
		*":$entry:"*) ;;
		*) out="${out:+$out:}$entry" ;;
		esac
	done
	PATH=$out
}

# --- PATH, common ----------------------------------------------------------
# Whatever the system handed us is the starting point: on MacOS /etc/profile
# has already run path_helper, on Solaris/Linux this is /etc/profile's PATH.
_path_prepend "$HOME/bin" "$HOME/.local/bin"

# Nix profiles installed from personal flakes, e.g. the nixvim build from
# ~/gitwork/my-nixvim. Deliberately generic: every profile under the nix state
# directory contributes its bin, so adding another flake output needs no edit
# here. Honours XDG_STATE_HOME, which is where nix actually looks, rather than
# hard-coding ~/.local/state.
#
# The -<N>-link entries must be skipped. Nix keeps each generation as
# <name>-<N>-link and points <name> at the current one, so all of them carry a
# bin/ -- a plain */bin glob would put every superseded build on PATH next to
# the live one (there are three stale neovim generations sitting there today).
# Adding <name> rather than its target also means the entry stays correct
# across a rebuild, instead of pinning to one /nix/store hash.
_nix_profile_dir="${XDG_STATE_HOME:-$HOME/.local/state}/nix/profiles"
if [ -d "$_nix_profile_dir" ]; then
	for _p in "$_nix_profile_dir"/*; do
		case ${_p##*/} in
		*-[0-9]*-link) continue ;; # a generation, not the current pointer
		esac
		_path_prepend "$_p/bin"
	done
fi
unset _nix_profile_dir _p

# --- PATH and environment, per OS ------------------------------------------
case "$UNAME_S" in
SunOS)
	# GNU userland ahead of /usr/bin. The ls/diff aliases and the dircolors
	# block in ~/.bashrc assume GNU semantics, not the Solaris ones. Note this
	# differs from ~/dotfiles/profile, which appends /usr/gnu/bin despite its
	# comment claiming otherwise; for bash we want what the comment says.
	_path_prepend /usr/gnu/bin
	_path_append /usr/bin /usr/sbin /sbin

	# Mirror ~/dotfiles/profile so bash and ksh93 agree about what is on PATH.
	# Globbed rather than pinned to 5.18.1 / 12.3; an unmatched glob expands to
	# itself and is then dropped by the -d test in the helpers.
	for _d in /usr/perl5/site_perl/*/bin /usr/perl5/[0-9]*/bin; do
		_path_prepend "$_d"
	done
	for _d in /opt/solarisstudio*/bin /opt/developerstudio*/bin; do
		_path_append "$_d"
	done
	unset _d

	export MANPATH="${MANPATH:-/usr/share/man}"
	export PAGER="/usr/bin/less -ins"
	export PERLDOC_PAGER="less -+C -R -ins"
	[ -d /usr/gnu/share/terminfo ] && export TERMINFO=/usr/gnu/share/terminfo
	;;

Linux)
	[ -x /home/linuxbrew/.linuxbrew/bin/brew ] &&
		eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
	;;

Darwin)
	# Homebrew first: coreutils and pyenv below both live under its prefix.
	# Apple silicon is /opt/homebrew, Intel is /usr/local.
	for _brew in /opt/homebrew/bin/brew /usr/local/bin/brew; do
		[ -x "$_brew" ] && eval "$("$_brew" shellenv)" && break
	done
	unset _brew

	# GNU coreutils ahead of the BSD ones, same reasoning as /usr/gnu/bin on
	# Solaris. HOMEBREW_PREFIX comes from 'brew shellenv' just above; using it
	# avoids a second, much slower 'brew --prefix' subprocess.
	_path_prepend "${HOMEBREW_PREFIX:-/opt/homebrew}/opt/coreutils/libexec/gnubin"

	# Legacy python.org framework installs. The old ~/.bash_profile hard-coded
	# 3.4/3.6/3.7/3.8/3.9, several of them twice, and only 3.8 is present. The
	# glob plus the -d test keeps this honest as versions come and go.
	#
	# Appended, not prepended: the old file prepended these and then prepended
	# the pyenv shims afterwards, so pyenv already won in practice everywhere
	# except the outer login shell. Appending makes every shell agree.
	for _d in /Library/Frameworks/Python.framework/Versions/[0-9]*/bin; do
		_path_append "$_d"
	done
	unset _d
	;;
esac

# --- Tool bootstraps -------------------------------------------------------
# Each of these is idempotent, but they are slow, so they run once per process
# tree here rather than once per interactive shell in ~/.bashrc.

# pyenv
export PYENV_ROOT="$HOME/.pyenv"
_path_prepend "$PYENV_ROOT/bin"
command -v pyenv >/dev/null 2>&1 && eval "$(pyenv init -)"

# rust / cargo
[ -r "$HOME/.cargo/env" ] && . "$HOME/.cargo/env"

# nvm. Only the PATH-bearing half belongs here; nvm's bash completion is a
# completion, so it stays in ~/.bashrc.
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"

# rvm, last of the PATH-touching tools as rvm itself asks.
_path_append "$HOME/.rvm/bin"
[ -s "$HOME/.rvm/scripts/rvm" ] && . "$HOME/.rvm/scripts/rvm"

# perl local::lib. This is the block local::lib appends to a shell rc when you
# run it; upstream aab523e had it at the bottom of bashrc with /home/gmarler
# hard-coded, which is a Linux path and simply wrong on MacOS. Moved here (it
# writes PATH), rewritten in terms of $HOME, and guarded so it is inert on
# machines with no ~/perl5 tree -- which includes this Mac today.
if [ -d "$HOME/perl5/lib/perl5" ]; then
	_path_prepend "$HOME/perl5/bin"
	export PERL5LIB="$HOME/perl5/lib/perl5${PERL5LIB:+:$PERL5LIB}"
	export PERL_LOCAL_LIB_ROOT="$HOME/perl5${PERL_LOCAL_LIB_ROOT:+:$PERL_LOCAL_LIB_ROOT}"
	export PERL_MB_OPT="--install_base \"$HOME/perl5\""
	export PERL_MM_OPT="INSTALL_BASE=$HOME/perl5"
fi

# opencode
_path_prepend "$HOME/.opencode/bin"

# --- History sizing --------------------------------------------------------
# See the long note at the top of this file before changing either of these.
export HISTSIZE=500000     # commands kept in memory
export HISTFILESIZE=500000 # lines kept in ~/.bash_history

# MacOS only, but harmless elsewhere: /etc/bashrc_Apple_Terminal redirects
# HISTFILE into ~/.bash_sessions/<uuid>.history for Terminal.app. Setting this
# to 0 keeps one shared ~/.bash_history instead.
export SHELL_SESSION_HISTORY=0

# --- Misc environment ------------------------------------------------------
# Optional home-directory settings directory for an inputrc and lesspipe.sh.
# It is deliberately not tied to the dotfiles checkout.
export SETTINGS="${SETTINGS:-$HOME/.settings}"

# Function search path for the ksh93-style autoloader in ~/.bashrc: colon
# separated, same shape as PATH, one file per function named after it. The
# autoloading machinery itself lives in ~/.bashrc; only the variable is here,
# because it is exported environment.
export FPATH="$HOME/.bash_functions"

fi

# --- Hand off to the interactive configuration -----------------------------
# A login shell reads only this file, so it must always source ~/.bashrc. This
# also lets a login child with an inherited environment load its prompt,
# aliases, functions, and history behaviour.
[ -f "$HOME/.bashrc" ] && . "$HOME/.bashrc"

# ~/.fzf.bash (which ~/.bashrc sources) may touch PATH, and macOS path_helper
# can run more than once. Deduplicate after the first complete bootstrap.
if [ "$_bash_env_initialized" = true ]; then
	_path_dedupe
	export PATH
fi
unset _bash_env_initialized
