syntax on
colorscheme space-vim-dark
set guioptions+=!
set guioptions-=m "no menu bar
set guioptions-=T "no toolbar
set guifont=Hack\ 12

# set vim command pwd to be the one presently browsed
set autochdir
set browsedir=current
let g:netrw_keepdir=0
autocmd BufEnter * silent! lcd %:p:h
