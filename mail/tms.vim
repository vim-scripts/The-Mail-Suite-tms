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

   let g:tms_fooey = 0
   if exists("tms_u_got_mail")
       let g:tms_fooey = g:tms_u_got_mail
   endif
   let g:tms_u_got_mail = 0
   exec 'perl tms_get_mail();'
   let g:tms_u_got_mail = g:tms_u_got_mail + g:tms_fooey

   if(g:tms_u_got_mail == g:tms_fooey)
        return
   endif

   exec 'perl tms_post_receive();'

   "exec 'perl tms_make_index(glob "d:/tms/tms/*");'
   "exec 'silent !perl d:\tms\filter\filter.pl'
   "exec 'perl tms_make_index(glob "d:/tms/tms/*");' 
   "exec 'silent !perl d:\tms\filter\filter.pl 1' 
   "cfile  c:\tmp\errors.err

endfunction


if !exists("tms_done_post_receive_filter_example")

let tms_done_post_receive_filter_example = 1

perl << EOHardCodedFilterRelatedExample
#BEGIN {(*STDERR = *STDOUT) || die;}
use diagnostics;
use warnings;
use strict;

my @tms_filter_rule_file =
(
'daum',
'  address: noreplymaster\@hanmail\.net',
'  move:    spam',
'  done:    1',
'av_yahoo',
'  address: mail-antivirus\@yahoo-inc\.com',
'  subject: Alert: Virus Detected',
'  move:    spam',
'  done:    1',
'av_sonic',
'  subject: Sonic\.net Graymail',
'  move:    spam',
'  done:    1',
'vim',
'  address: \@vim\.org',
'  move:    vim',
'  done:    1',
'perl',
'#  address: \@(listserv\.)?activestate\.com',
'  address: activestate\.com',
'  move: perl',
'  done:    1',
'#-------------------------------------------------',
);

my @tms_rules=tms_rule_file_2_rules();
sub tms_rule_file_2_rules
{
    my $now = -1;
    #while ($_ = shift @tms_filter_rule_file)
    foreach (@tms_filter_rule_file)
    {
      chomp;
      $_ =~ s/\s*#.*//;
      $_ =~ s/\s+$//; # to get rid of white lines
      $_ or next;
      if($_ !~ /:/) # ?if(!/:/)
      {
         ${$tms_rules[++$now]}{name} = $_;
         next;
      }
      ($_ =~ /^\s*(\w+):\s*(\S.*)\s*$/) and ${$tms_rules[$now]}{$1} = $2;
    }
    return @tms_rules;
}

my $dir_mail_home = tms_get_dir_mail_home();
my @mail_boxes = tms_use_vim_glob("$dir_mail_home/*");
my @index_raws = map "$_/index.raw", @mail_boxes;  

#tms_echo('warn', "mail:@mail_boxes\n");
#tms_echo('warn', "raws:@index_raws\n");

sub tms_use_vim_glob
{
   my ($pattern) = @_;

      my $foo = "let b:tms_fooey = glob(\"$pattern\")";
                VIM::DoCommand($foo); 
         $foo = VIM::Eval('b:tms_fooey');

         $foo =~ s,\\,/,g;
         $foo =~ s,/\n,\n,g;
      my @fp_files = split /\n/, $foo;

      return @fp_files;
}

sub tms_post_receive
{
#tms_echo('warn', "starting with indexing ...");
    tms_make_index(@mail_boxes);
#tms_echo('msg', "will filter ...");

    # UNCOMMENT THE NEXT LINE ONCE YOU HAVE VERIFIED
    # CONTENTS OF THE ARRAY @tms_filter_rule_file ABOVE
    # tms_filter($dir_mail_home);

#tms_echo('msg', "will reindex ...");
    tms_make_index(@mail_boxes);
#tms_echo('msg', "setting up quickfix ...");
    tms_make_quickfix_tag_file($dir_mail_home, "$dir_mail_home/tags");
#tms_echo('msg', "cfileing quickfix tags file ...");
    VIM::DoCommand("cfile $dir_mail_home/tags"); 
#tms_echo('msg', "all done\n");
}

sub tms_filter
{
   my ($dir_mail_home) = @_;
   
   my $log = '';

   open (IN, "$dir_mail_home/inbox/index.raw") or die("Unable to open index.raw for reading: $!\n");
     my @lines = <IN>;
   close IN;
     chomp @lines;
   
   my %rawxfer=();
   use File::Copy;
   for my $raw_line (@lines)
   {
      $raw_line =~ /\|/ or next;
      my ($mark, $from, $to, $subject, $date, $nick, $flnm) = split /\|/, $raw_line;
      for my $the_rule (@tms_rules)
      {
         (${$the_rule}{address} and 
          ((my $foo = "$from $to") =~ /${$the_rule}{address}/i)) or 
         (${$the_rule}{subject} and 
                         ($subject =~ /${$the_rule}{subject}/i)) or next;
   
            $foo = "$dir_mail_home/${$the_rule}{move}";
            $raw_line =~ s/$flnm\s*$// or die "There should be a $flnm in $raw_line!!!\n";
   
         my $dest_file = tms_filter_w_make_unique_name($foo, $flnm);
           ($dest_file =~ /([\w.]+)$/ and $raw_line .= $1) or die "Why isn't $dest_file a file???\n";
         
         push @{$rawxfer{"$foo/index.raw"}}, $raw_line;
     
         $log .= "${$the_rule}{name}:  ,$flnm, -> ,$dest_file,\n";
         move("$dir_mail_home/inbox/$flnm", $dest_file) or die "could not move $flnm to $dest_file $!\n";
         ${$the_rule}{done} and last;
      }
   }
   for (keys %rawxfer)
   {
      $log .= tms_filter_w_append_aref_to($_, $rawxfer{$_});
   }
#tms_echo('msg', "log is:$log\n");
}

sub tms_filter_w_make_unique_name 
{
   my ($dir, $file) = @_;

   my $flnm = $file;
      $flnm =~ s/\.eml$//;

      if($dir)
      {
         $flnm =~ s/^\///;
         $flnm = $dir . '/' . $flnm;
      }

   my $i='';
      while (-e $flnm.$i.'.eml')
      {
         $i =~ s/_//;
         $i++;
         $i = '_'.$i;
      } 
      $flnm = $flnm . $i . '.eml';

      return $flnm;
}

sub tms_filter_w_append_aref_to
{
  my ($file, $aref_lines) = @_;

  my $log = '';
     $log .= "$_\n" for (@{$aref_lines});

  open (OUT, ">>$file") or die("Unable to open $file for appending: $!\n");
     print OUT $log;
  close OUT;

  return "$file:\n$log";
}

sub tms_make_quickfix_tag_file
{
  use File::Glob ':glob';

  my ($dir_mail_home, $errors_file) = @_;

  my $errs = '';
  my $file = '';
  my $sum  = 0;
  
  my @raws = glob("$dir_mail_home/*/index.raw");
     while ($file = shift @raws)
     {
        open (IN, $file) or die "unable to open $file $!\n"; 
           my @lines = <IN>;
        close IN;
        my $count = 0;
           $count = grep /^[^|]*n[^|]*\|/, @lines;
           #next unless $count;
           $errs .= "$file:$count\n";
           $sum  += $count;
     }
     $errs =~ s/^.*raw:0[\n\r]*//gm;

     $errs =~ s,(\w+)/index.raw:(\d+),$1/index.idx:$2:$1 $2/$sum newly arrived,g;
 
     open (OUT, ">$errors_file") or die "unable to open $errors_file:$!\n";
        print OUT $errs;
     close OUT;
  return;
}

EOHardCodedFilterRelatedExample

endif

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

