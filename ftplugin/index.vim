" File:                  ftplugin/index.vim
" Copyright (C) 2004 Suresh Govindachar  <initial><last name><at><yahoo>
" Version:               1.1
" Date:                  August 9, 2004
" 
" Purpose:  To be used with the plugin (plugin/tms.vim): 
"           The Mail Suite (tms) - Send, Receive and Organize via an 
"           Editable User Infterface (EUI)
"

if exists("b:did_ftplugin")
  finish
endif
let b:did_ftplugin = 1  " Don't load another plugin for this buffer

setlocal tw=0
setlocal nowrap
setlocal nomodeline

ru mail/tms.vim

if exists("tms_do_idx_folding")

setlocal foldmethod=expr
setlocal foldexpr=TMS_Index_fold(v:lnum)

function! TMS_Index_fold(linenum)

   if (a:linenum < 3) | return 0 | endif

   let s:line = getline(a:linenum)

   if (s:line =~ '^[^|]*n[^|]*|') | return 0 | endif
   if (s:line =~ '^\s*[rah ]*|')  | return 2 | endif

	 return 1

endfunction

endif

finish
