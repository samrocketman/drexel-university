"this is a comment
"type :help command to see the vim help docs for that command
:filetype on
:au FileType c,cpp,java set cindent

set nocompatible
set shiftwidth=2
"showmode indicates input or replace mode at botto
set showmode
set showmatch
"shortcut for toggling paste while in insert mode, press F2 key
set pastetoggle=<f2>
set backspace=2
"hlsearch for when there is a previous search pattern, highlight all its matches.
set hlsearch
"ruler shows line and char number in bottom right of vim
set ruler
set number
"expandtab means tabs create spaces in insert mode, softtabstop is the number of spaces created
"tabstop affects visual representation of tabs only
set tabstop=2
set expandtab
set softtabstop=2

"always show status and tabs
set laststatus=2
"set showtabline=2

"ignore case
set ic

"set background=light
set background=dark
set autoindent
if &t_Co > 1 
  syntax enable
endif
