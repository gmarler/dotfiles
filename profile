#
# Simple profile places /usr/gnu/bin at front,
# adds /usr/X11/bin, /usr/sbin and /sbin to the end.
#
# Use less(1) as the default pager for the man(1) command.
#
export PATH=/usr/perl5/site_perl/5.18.1/bin:/usr/perl5/5.18.1/bin:$PATH
export PATH=$PATH:/usr/bin:/usr/sbin:/sbin:/usr/gnu/bin
export PATH=$PATH:/opt/solarisstudio12.3/bin
export PAGER="/usr/bin/less -ins"

#
# Define default prompt to <username>@<hostname>:<path><"($|#) ">
# and print '#' for user "root" and '$' for normal users.
#
#PS1='${LOGNAME}@$(/usr/bin/hostname):$(
#    [[ "${LOGNAME}" == "root" ]] && printf "%s" "${PWD/${HOME}/~}# " ||
#    printf "%s" "${PWD/${HOME}/~}\$ ")'

if [[ "${LOGNAME}" == "root" ]]; then
  SPROMPT='#'
else
  SPROMPT='$'
fi
export FPATH=$HOME/ksh-functions
export HISTSIZE=20000
if [[ -f $HOME/.kshrc && -r $HOME/.kshrc ]]; then
  export ENV=$HOME/.kshrc
fi
export EDITOR=vi

HOSTNAME=$(/usr/bin/hostname)
PS1="[${HOSTNAME%%.*}:"'$(printf "%s" "${PWD/${HOME}/\~}")'"]
${SPROMPT} "

export PS1 # to override /etc/ksh.kshrc

if [[ $(/bin/uname -s) == "SunOS" &&
      $(/bin/uname -r) == "5.11" ]]; then
  export TERMINFO=/usr/gnu/share/terminfo
  export TERM=xterm-256color
  export LESS="-R"
  export PERLDOC_PAGER="less -+C -R"
fi

eval $(gpg-agent --daemon)
