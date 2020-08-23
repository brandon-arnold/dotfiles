[ -s "~/.secret-env" ] && \. "~/.secret-env"

export ALTERNATE_EDITOR=""
export EDITOR="emacsclient -t"                  # $EDITOR should open in terminal
export VISUAL="emacsclient -c -a emacs"         # $VISUAL opens in GUI with non-daemon as alternate

# colorize less with python-pygment
export LESS='-R'
export LESSOPEN='|~/.lessfilter %s'

export GDK_SCALE=2
export GDK_DPI_SCALE=0.5
export QT_AUTO_SCREEN_SCALE_FACTOR=1
