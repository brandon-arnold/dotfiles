[[ $- != *i* ]] && return

alias ls='ls --color=auto'
PS1='[\u@\h \W]\$ '

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

export GDK_SCALE=3
export GDK_DPI_SCALE=0.75
export QT_AUTO_SCREEN_SCALE_FACTOR=1

export TERM=xterm-256color
