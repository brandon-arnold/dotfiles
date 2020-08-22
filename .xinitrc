# set timings for display to turn off
xset dpms 600 600 600

# required for gnome-keyring to work in i3
/etc/X11/xinit/xinitrc.d/50-systemd-user.sh

# start i3
exec i3

