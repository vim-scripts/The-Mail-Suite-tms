" File:                  after/ftplugin/mail.vim
" Copyright (C) 2004 Suresh Govindachar  <initial><last name><at><yahoo>
" Version:               1.1
" Date:                  August 9, 2004
" 
" Purpose:  To be used by itself or with the plugin (plugin/tms.vim): 
"           The Mail Suite (tms) - Send, Receive and Organize via an 
"           Editable User Infterface (EUI)
"
ru mail/tms.vim

setlocal foldmethod=expr
setlocal foldexpr=Eml_fold(v:lnum)

"''''''''''''''''''''''''''''''''''''"
setlocal tw=0
setlocal smartindent
"''''''''''''''''''''''''''''''''''''"

let b:eml_boundary = 0

function! Eml_fold(linenum)

   let s:line = getline(a:linenum)

   if (s:line =~ '^\s*$')     | return 0 | endif
   if (s:line =~ '^Subject:') | return 0 | endif
   if (s:line =~ '^From:')    | return 0 | endif
   if (s:line =~ '^To:')      | return 0 | endif
   if (s:line =~ '^CC:')      | return 0 | endif
   if (s:line =~ '^Date:')    | return 0 | endif
   if (s:line =~ '^\s*filename=".*"\s*$') | return 0 | endif

   return 1

endfunction

function! Eml_open()

   if (b:eml_boundary == '0')
      call Eml_get_boundary()  " may or may not set b:eml_boundary
   endif

   if (b:eml_boundary == '0')
      let s:eml_open_message = ':1/^\s*$/,$g/^\s*\n\s*\S/+1 norm zO'
   else
      let s:eml_open_message = ':1/^\s*$/,/^-*' . b:eml_boundary . '/g/^\s*\n\s*\S/+1 norm zO'
   endif

   execute 'silent! ' . s:eml_open_message
   nohlsearch

   let s:eml_open_message = ':1/^\s*$/,$g/^\s*Content-Type:\s*text\/plain//^\s*\n\s*\S/+1 norm zO'
   execute 'silent! ' . s:eml_open_message
   nohlsearch
   1

endfunction

function! Eml_get_boundary()
   let s:foo = 1
   let s:end_at = line('$')
   :while (s:foo < s:end_at)
       let b:eml_boundary = getline(s:foo)
       if (b:eml_boundary =~ '^\s*$')
            let s:foo     = s:end_at - 1
       else
            if(b:eml_boundary =~ '\s*boundary=".*')
                 let b:eml_boundary = substitute(b:eml_boundary, '.*\s*boundary="', '', '')
                 let b:eml_boundary = substitute(b:eml_boundary, '".*', '', '')
                 let s:foo     = s:end_at  " no -1 here
            endif
       endif
       let s:foo = s:foo + 1
   endwhile
   if(s:foo == s:end_at)
       let b:eml_boundary = 0
   endif
endfunction

finish

"
"      return '<1'
" E493: Backwards range given:
"
" 1/^\s*$/,/----=_NextPart_000_00B5_01C46744.AB147C20/g/^\s*$/+1 norm zO
" 1/^\s*$/,/----=_NextPart_000_00B5_01C46744.AB147C20/g/^\s*$/+1 norm zO

"   :1/^\s*$/,$g/^\s*\_$\_s*\(----\)\@!\S/+1 norm zO
"   :1/^\s*$/,b:eml_boundaryg/^\s*$/+1 norm zO
"
