set -o vi
set -o viraw

# Aliases
alias ls='ls -Fa'

ttyname=$(/usr/gnu/bin/tty)
export HISTFILE=${HOME}/${ttyname##*/}.hist

#if [[ "$TERM" == "xterm" ]]; then
#  export TERM=xterm-color
#fi
