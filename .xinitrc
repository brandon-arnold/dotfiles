# set timings for display to turn off
xset dpms 600 600 600

# required for gnome-keyring to work in i3
# /etc/X11/xinit/xinitrc.d/50-systemd-user.sh

xrandr --setprovideroutputsource modesetting NVIDIA-0
xrandr --auto
xrandr --dpi 288
# xrandr --dpi 264

xinput set-prop "DELL098F:00 04F3:311C Touchpad" "libinput Click Method Enabled" 0 1
xinput set-prop "DELL098F:00 04F3:311C Touchpad" "libinput Accel Speed" 0.25
xinput set-prop "DELL098F:00 04F3:311C Touchpad" "libinput Natural Scrolling Enabled" 1

# start i3
exec i3

