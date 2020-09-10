# set timings for display to turn off
xset dpms 600 600 600

# required for gnome-keyring to work in i3
# /etc/X11/xinit/xinitrc.d/50-systemd-user.sh

xrandr --setprovideroutputsource modesetting NVIDIA-0
xrandr --auto
xrandr --dpi 288
# xrandr --dpi 264

# start i3
exec i3

