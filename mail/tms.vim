" File:                  mail/tms.vim
" Copyright (C) 2004 Suresh Govindachar  <initial><last name><at><yahoo>
" Version:               1.1
" Date:                  August 9, 2004
" 
" Purpose:  Contains mappings to enable a "quick-start" of the 
"           plugin (plugin/tms.vim): 
"           The Mail Suite (tms) - Send, Receive and Organize via an 
"           Editable User Infterface (EUI)
"

" This file will be sourced by the plugin file plugin/tms.vim and also 
" by the ftplugin files ftplugin/index.vim and after/ftplugin/mail.vim

" Horizontal scrolling within the usually wide index.idx buffer
if(&ft == 'index')
   setlocal sidescroll=1
   nmap  <buffer>   <c-l>  zl
   nmap  <buffer>   <c-h>  zh
endif

if((&ft == 'index') || (&ft == 'mail'))
  if !exists("maplocalleader")
    let maplocalleader = '\'
    let s:undomaplocalleader = 1
  endif
endif

if(&ft == 'mail')
   " open next mail 
   nmap <buffer>  <LocalLeader>n  :perl tms_w_do_this('n');<CR>
   " open previous mail 
   nmap <buffer>  <LocalLeader>p  :perl tms_w_do_this('p');<CR>
endif

if(&ft == 'index')
   " open mail 
   nmap <buffer>  <LocalLeader>o  :perl tms_w_do_this('o');<CR>
endif

if((&ft == 'index') || (&ft == 'mail'))
   " reply to sender
   nmap <buffer>  <LocalLeader>r  :perl tms_w_do_this('r');<CR>
   " reply to all
   nmap <buffer>  <LocalLeader>R  :perl tms_w_do_this('R');<CR>
   " forward
   nmap <buffer>  <LocalLeader>f  :perl tms_w_do_this('f');<CR>
   " send acknowledgment
   nmap <buffer>  <LocalLeader>A  :perl tms_w_do_this('A');<CR>
   
   " delete (move to trash folder)
   nmap <buffer>  <LocalLeader>d  :perl tms_w_do_this('d');<CR>
   " move (prompt for folder to move to)
   nmap <buffer>  <LocalLeader>m  :perl tms_w_do_this('m');<CR>
   " copy (prompt for folder to copy to)
   nmap <buffer>  <LocalLeader>c  :perl tms_w_do_this('c');<CR>
endif

if(&ft == 'index')
   " delete block from idx (move to trash folder)
   map <buffer>  <LocalLeader>D  :TMSIndexBlock D<CR>
   " move block from idx (prompt for folder to move to)
   map <buffer>  <LocalLeader>M  :TMSIndexBlock M<CR>
   " copy block from idx (prompt for folder to copy to)
   map <buffer>  <LocalLeader>C  :TMSIndexBlock C<CR>
endif

if(&ft == 'index')
   if has("win32")
      nmap  <buffer> <LocalLeader>v  :exec 'silent !start rundll32 url.dll,FileProtocolHandler '.expand(expand("%:p:h")."/".substitute(getline("."), '.*\| \\|\\s*$', "", "g"))<CR>
   endif
endif

if((&ft == 'index') || (&ft == 'mail'))
   if exists("*s:undomaplocalleader")
      unlet s:undomaplocalleader
   endif
   finish
endif


if !exists("mapleader")
  let mapleader = '\'
  let s:undomapleader = 1
endif

" unrestricted mapping that could take arguments
" Make the index.idx file for (eml files) in directory specified in argument
" [default: directory of current buffer]
" mnemonic i for make the Index file  
map <Leader>i    :TMSMakeIndex  

" Get mail from the nicks of accounts specified in the argument
" [default is all accounts]  
" mnemonic g for Get mail 
map <Leader>g    :TMSGetMail  

" Send the mail indicated by the file in the argument
" [default is current buffer;  NOTE: current buffer need not have a file!]
" mnemonic s for Send mail 
map <Leader>s    :TMSSendMail  


map      <Leader>G  :TMSExampleOfUserDefinedMap<CR>

command! -nargs=0    TMSExampleOfUserDefinedMap    call s:TMSExampleOfUserDefinedWrapperFunction()

function! s:TMSExampleOfUserDefinedWrapperFunction()

perl << EOExample_of_user_defined_wrapper_function
use diagnostics;
use warnings;
use strict;

       tms_get_mail() or tms_echo('msg', "No new messages") or return;

    my $foo = tms_fix_directory('inbox');
       tms_make_index($foo);
       $foo = $foo . '/index.idx';

    my $command = 'sf ';
       ((VIM::Buffers($foo))[0]) and $command = 'sb '; 
       tms_is_in_window($foo)    and $command = 'drop ';

       VIM::DoCommand($command . $foo . '|e!');

EOExample_of_user_defined_wrapper_function

endfunction

if exists("*s:undomapleader")
   unlet s:undomapleader
endif

finish

n
p

o
r
R
f
A

d
m
c

D
M
C

v

i
g
s

G

