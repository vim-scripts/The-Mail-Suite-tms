" File:                  syntax/index.vim
" Copyright (C) 2004 Suresh Govindachar  <initial><last name><at><yahoo>
" Version:               1.1
" Date:                  August 9, 2004
" 
" Purpose:  To be used with the plugin (plugin/tms.vim): 
"           The Mail Suite (tms) - Send, Receive and Organize via an 
"           Editable User Infterface (EUI)
"

" 
" A place holder for coloring index.idx files
"
if exists("b:current_syntax")
  finish
endif
let b:current_syntax = "index"

" the order below is important (couldn't figure out to use nextgroup, contained etc.)
syntax region  old           start="^\s*[rah ]*|"  end=".*|"  
syntax region  new           start="^[^|]*n[^|]*|" end=".*|"  
syntax match   date_error    "^.* 31 Dec 1969 .*|"                       
syntax region  custom_mark   start="^[^|A-Z]*[b-gi-mo-qs-z][^|A-Z]*|"   end=".*|" 

highlight link custom_mark todo
highlight link date_error  error
highlight link new         keyword
highlight link old         comment

"syntax match  flnm    "[^|]\w\w*\.eml\s*$" 
"hi def flnm guifg=bg ctermfg=7

finish

