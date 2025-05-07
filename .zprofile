# User PATH
typeset -U path
path=(/opt/rocm/bin ~/opt/altera/24.1std/quartus/bin ~/opt/altera/24.1std/questa_fe/bin ~/bin ~/scripts /usr/local/go/bin /home/brandon/.local/bin /home/brandon/opt/lscc/diamond/3.14/bin/lin64/ $path[@])

# Hex to decimal, decimal to hex. Ex:
# $ h2d FF
# 255
h2d(){
  echo "ibase=16; $@"|bc
}
d2h(){
  echo "obase=16; $@"|bc
}

backup() {
    systemctl start system-backup.service
}

backuplog() {
    journalctl -u system-backup --since=today
}

alias cclip='xclip -selection clipboard'
alias ll='ls -lah'
alias unixtime="date +%s"

lpasspass() {
    if [[ $# -eq 0 ]] ; then
        echo "usage: lpasspass <account-name>"
    else
        lpass show --password $1
    fi
}

saydone() {
  espeak --stdout "task finished" -v en-us | paplay
}

slack() {
  flatpak run com.slack.Slack
}

alias top="sudo htop"
# alias cat="bat"
alias du="ncdu --color dark -rr -x --exclude .git --exclude node_modules --enable-delete"

# start x on login -- see .xinitrc for default window manager
# if [ -z "$DISPLAY" ] && [ -n "$XDG_VTNR" ] && [ "$XDG_VTNR" -eq 1 ]; then
#   exec startx
# fi

# start sway on login
# if [ $(tty) = "/dev/tty1" ]; then
#     XKB_DEFAULT_LAYOUT=us exec sway
#     exit 0
# fi

export PATH=$PATH:$(npm get prefix)/bin

export QSYS_ROOTDIR="/home/brandon/opt/altera/24.1std/quartus/sopc_builder/bin"
