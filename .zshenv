[ -s "~/.secret-env" ] && \. "~/.secret-env"

export ALTERNATE_EDITOR=""
export EDITOR="emacsclient -t"                  # $EDITOR should open in terminal
export VISUAL="emacsclient -c -a emacs"         # $VISUAL opens in GUI with non-daemon as alternate

# colorize less with python-pygment
export LESS='-R'
export LESSOPEN='|~/.lessfilter %s'

