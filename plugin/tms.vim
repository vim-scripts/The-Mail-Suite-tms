" File:                  plugin/tms.vim
" The Mail Suite (tms) - Send, Receive and Organize via an Editable User Infterface (EUI)
" Copyright (C) 2004 Suresh Govindachar  <initial><last name><at><yahoo>
" Version:               1.13
" Date:                  September 5, 2004
" Initial Release:       August 11, 2004
" Documentation:         tms.txt
" 
" General Notes:                                           {{{1
"
" Exports:  
"    The only commands the user need be concerned with are 
"    listed in the file: 
"
"       mail/tms.vim
"
"---------------------------------------------------------------------------

"bookkeeping {{{1
if !has('perl')           "{{{2
   finish
endif
if exists("loaded_tms")   
   finish
endif
"see help use-cpo-save for info on the variable save_cpo  
let s:save_cpo = &cpo
set cpo&vim

"let g:tms_debug = 1
"let g:tms_do_not_bw_in_perl = 1
"let g:tms_do_not_bun_in_perl = 1

if !exists("tms_debug")
   let g:tms_debug = 0
endif
if !exists("tms_do_not_bw_in_perl")
   let g:tms_do_not_bw_in_perl = 0
endif
if !exists("tms_do_not_bun_in_perl")
   let g:tms_do_not_bun_in_perl = 0
endif
if (g:tms_do_not_bun_in_perl != 0)
   let g:tms_do_not_bw_in_perl = 1
endif
   

if !exists("tmsrc")   " {{{2
   if has("win32")
      let g:tmsrc = expand($VIM . '/vimfiles/mail/_tmsrc')
   else
      let g:tmsrc = expand($HOME . '/.tmsrc')
   endif
endif

"perl  {{{1
"
" The perl code has been organized into blocks entitled:
"      utilities
"      initialization
"      pop
"      smtp
"      organizer
"      working
"      via vim
" This is just a first, rough attempt at organizing the code.
" 
" This -- meaning the development of the first (1.1) release -- was my 
" very first perl-embedded-in-Vim code.  In the course of this developemnt
" I have learnt things that can be used to better organize tms.
" Key items in regard to reorganizing the code:
"
"   a) Make a very sharp distinction between perl code that 
"      is dependent on Vim and perl code that is generic.
"
"        - Keep the generic code in a .pm file  
"        - Keep the Vim dependent code as small as possible and 
"        - Keep the Vim dependent code in a .vim file 
"        - The .pm file will not be "sourced" within VIM;  rather,
"          the .vim file will "use" the stuff in the .pm file.
"
"   b) The reliance of the present code on VIM::<> and on $main::<>
"      can be made clean by: 
"         
"        - As soon as possible, extract information from VIM::<> and
"          $main::<> (meaning from the User's context) into generic 
"          perl variables
"        - Restrict processing as much as possible to generic perl variables
"        - Transfer information from generic perl variables into the User's 
"          context (meaning into $main::<> and into VIM::<>) as late as possible
"
" In some places (especially initialization), values are passed around 
" instead of references;  fix this.
"         
"Utilities {{{2
"
perl << EOUtils
#BEGIN {(*STDERR = *STDOUT) || die;} # {{{4
#line 99

use diagnostics;
use warnings;
use strict;
#use LWP::Simple;
#use Net::POP3;

my $debug =  VIM::Eval('g:tms_debug');  # {{{3
# put=line(\".\")
# normal u
# dis =
# normal zR
# %g/^#line .*/ exec 'normal 6lD'|put =|normal kJ

tms_debug("Compiling utilities..."); 

# tms_verify_read()  # {{{3
sub tms_verify_read  # {{{4
{
    my %rc = tms_get_rc();
    my $tmsrc = tms_get_tmsrc();
    tms_print("Starting (while seeing \$tmsrc as $tmsrc)...\n");
    foreach (keys %rc)
    {
        my $key = $_;
        tms_print("Main key:  $key\n");
        foreach (keys %{$rc{$key}})
        {
            tms_print("    $_:  $rc{$key}{$_}\n");
        }
    }
    tms_print("DONE\n");
}

# tms_get_input($tag) # {{{3
sub tms_get_input # {{{4
{
   my ($tag) = @_;

   $tag =~ s,\\,\\\\,g;
   my $foo='';
   if(1)
   {
      $foo = "let b:tms_fooey = input(\"$tag\n\")";
             VIM::DoCommand('call inputsave()');
             VIM::DoCommand($foo); 
             VIM::DoCommand('call inputrestore()');
      $foo = VIM::Eval('b:tms_fooey');
   }
   else
   {
      $foo = "let s:fooey = input(\"$tag\n\")";
             VIM::DoCommand('call inputsave()');
             VIM::DoCommand($foo); 
             VIM::DoCommand('call inputrestore()');
      $foo = VIM::Eval('s:fooey');
   }
   return $foo;
}

# tms_print($what) # {{{3
sub tms_print # {{{4
{
  my ($what) = @_;
  VIM::Msg($what);
}

# tms_debug($what) # {{{3
sub tms_debug # {{{4
{
  my $what = shift;
  $debug and tms_echo('msghlsearch', $what);
}

# tms_echo($type, $what) # {{{3
# $what is a multi-line ("\n") string that will be echo'ed
# with the highlighting encoded in $type
#
# 2do: escape things in $what which VIM cannot echo.
# tms_echo # {{{3
sub tms_echo # {{{4
{
  my ($type, $what) = @_;
  $type = 'echo'.$type;        #$type can be msg or msgwarn or err or msghlToDo etc.

  ($type =~ s/warn//)   and VIM::DoCommand('echohl WarningMsg'); 
  ($type =~ s/hl(.+)//) and VIM::DoCommand("echohl $1"); 
  foreach (split "\n", $what)
  {
     VIM::DoCommand("$type \'$_\'");
  }
  VIM::DoCommand('echohl None');
  return 1;
}


# tms_die($dying_message) # {{{3
sub tms_die # {{{4
{
  my ($dying_message) = @_;
  tms_echo('err', $dying_message);
  die $dying_message;
}

tms_debug("                   1 Done compiling utilities\n");
EOUtils



"Initialization {{{2
"
" Read the rc file (_tmsrc) and store it
" Get passwords, if required
" Verify that directories exist -- create them if they don't exist 
"
" sub to strip comments from rc file
"
" 'get' subroutines that return:
"    the stuff read from the rc file
"    certain directories 
"       trash 
"       mail_home
"
perl << EOInit
#BEGIN {(*STDERR = *STDOUT) || die;} # {{{4
#line 225
use diagnostics;
use warnings;
use strict;
#use LWP::Simple;
#use Net::POP3;

tms_debug("Compiling initializing...\n");  # {{{3

my $tmsrc   = VIM::Eval("g:tmsrc"); 
my %tms_rc  = tms_read_tmsrc($tmsrc);
#v1.12   %tms_rc  = tms_get_password(%tms_rc);
   %tms_rc  = tms_verify_dirs(%tms_rc);

# %rc = tms_read_tmsrc($file) # {{{3
sub tms_read_tmsrc # {{{4
{
  my ($file) = @_;
  open (IN, $file) or tms_die("Unable to open $file for reading: $!\n");
     my @lines = <IN>;
  close IN;

  my %rc = ();
  while ($_ = shift @lines) 
  {
     $_ = tms_strip_rcline($_);
     $_ or next;
     if($_ =~ s/^nick\s+//)
     {
         my $nick = $_;
         while ($_ = shift @lines) 
         {
             $_ = tms_strip_rcline($_);
             $_ or next;
             #($_ =~ /^end$/) and last;
             ($_ =~ m/(\S+)\s+(.+)/) or last;
             $rc{$nick}{$1}=$2;
         }
         (defined $rc{$nick}{delete_after}) or $rc{$nick}{delete_after} = 0; 
     }
     #($_ =~ /^end$/) and next;
     ($_ =~ m/^(\S+)\s+(.+)/) or next;
     $rc{'_config'}{$1}=$2;
  }
  my $foo = VIM::Eval('fnamemodify(tempname(), ":p:h")'); 
  #(defined $rc{_config}{dir_drafts}) or $rc{_config}{dir_drafts} = $foo;
  (defined $rc{_config}{dir_trash})  or $rc{_config}{dir_trash} = $foo;
  return %rc;
}

sub tms_auto_get_password()
{
   %tms_rc  = tms_get_password(%tms_rc);
}
sub tms_reset_password()
{
   $tms_rc{_config}{_password} = '';
   %tms_rc  = tms_get_password(%tms_rc);
}

# %rc = tms_get_password(%rc) # {{{3
sub tms_get_password # {{{4
{
   my (%rc) = @_;

   my %nickpass=();
   my $num_str = $rc{_config}{_password};
   (defined $num_str) and %nickpass = split " ", pack("b*", $num_str);
   
   my $found_new = 0;
   foreach (keys %rc)
   {
       ($_ =~ /^_/) and next; 
       (defined $nickpass{$_}) and next; 

       $nickpass{$_} = tms_get_input("enter the password for the mail server named $_");
       $found_new = 1;
   }
   $num_str = '';
   foreach (keys %nickpass)
   {
       $num_str          = $num_str . ' ' . $_ . ' ' . $nickpass{$_};
       $rc{$_}{password} = $nickpass{$_};
   }
   if($found_new)
   {
      $num_str = unpack("b*", $num_str);
      $rc{_config}{_password} = $num_str;
      my $file = $tmsrc;
      my $original = '';
      open (IN, $file) or tms_die "Unable to open $file for reading:$!\n"; 
          while(<IN>)
          {
             /^\s*_password\s+/ and next;
             $original .= $_;
          }
      close IN;
      open (OUT, ">$file") or tms_die "Unable to open $file for re-writing:$!\n"; 
          print OUT $original;
          print OUT "\n_password    $num_str\n";
      close OUT;
   }
   return %rc;
}

# %rc = tms_verify_dirs(%rc) # {{{3
sub tms_verify_dirs  # {{{4
{
   my (%rc) = @_;

   foreach my $key (keys %rc)
   {
      foreach my $tag (keys %{$rc{$key}})
      {
         ($tag =~ /^dir_/) or next; 
         my $foo = $rc{$key}{$tag}; 
            $foo =~ s,\\,/,g;
            $foo =~ s,//+,/,g;
            $foo =~ s,/\s*$,,g;
            ($^O =~ /mswin/i) and $foo = lc $foo;

         $rc{$key}{$tag} = $foo; 
         (-d $foo) or mkdir $foo, 0755;  

         #-old- ignore test of existence of directory
         #-old- for now, just call mkdir and ignore return value
         #-old-if($rc{$key}{$_}) { #mkdir $rc{$key}{$_};  if(-d $rc{$key}{$_}) { # tms_echo('err', "$rc{$key}{$_}: is a dir"); }  else { tms_echo('err', "$rc{$key}{$_}: is NOT a dir"); mkdir $rc{$key}{$_}, 0777;# or tms_die "Cannot make dir:$!\n"; }  }
      }
   }
   return %rc;
}

# $line = tms_strip_rcline($line) # {{{3
sub tms_strip_rcline # {{{4
{
  my ($line) = @_;
  $line =~ s/\s*\#.*//;
  $line =~ s/^\s*//;
  $line =~ s/\s*$//;
  return $line;
}

# $tmsrc= tms_get_tmsrc() # {{{3
sub tms_get_tmsrc # {{{4
{
    return $tmsrc;
}

# %rc = tms_get_rc() # {{{3
sub tms_get_rc # {{{4
{
    return %tms_rc;
}

# $dir_trach = tms_get_dir_trash() # {{{3
sub tms_get_dir_trash # {{{4
{
    return $tms_rc{_config}{dir_trash}; 
}

# $dir_mail_home = tms_get_dir_mail_home() # {{{3
sub tms_get_dir_mail_home # {{{4
{
    return $tms_rc{_config}{dir_mail_home}; 
}


tms_debug("                   2 Done compiling initialization\n");
EOInit

augroup TMSInitialization
  au!
  autocmd VimEnter * :perl tms_auto_get_password();
augroup END


"POP {{{2
"
perl << EOPop
##!/usr/bin/perl   # {{{4
#line 405
#BEGIN {(*STDERR = *STDOUT) || die;}  
use diagnostics;
use warnings;
use strict;
#use CGI qw(:standard);
#use LWP::Simple;
use Net::POP3;

tms_debug("Compiling pop...\n");  # {{{3

# tms_get_mail(@nicks) # {{{3
# 
# Input   - list of nicks of pop-hosts to get mail from
#           if empty, defaults to all nicks
#
# Result  - new mails get downloaded to directories (specified in rc file)
#         - updates index.raw file in downloaded directory 
#         - pop-state of nick is updated (by re-creation)
#         - delete mail on pop-server if this needs to be done based 
#           on setting for deletion in rc file
#         - message with high-light search that no messages were
#           download, or with high-light ToDo that certain number of 
#           messages were downloaded
#
# Returns - the number of new mails just received
#
# Calls   tms_get_rc();
#         tms_get_pop_state($pop_state_file);
#         tms_just_the_date($1);
#         tms_set_pop_state($pop_state_file, %pop_state_now);
#
sub tms_get_mail # {{{4
{
   my (@nicks) = @_;
   my %rc = tms_get_rc();
   my $u_got_mail = 0;
   
   @nicks or @nicks = keys %rc;

   my $now=time();
   
   foreach my $nick (@nicks)
   {
      ($nick =~ /^_/) and next; 
      my $inbox        = $rc{$nick}{dir_inbox};
      my $host         = $rc{$nick}{pop_host};
      my $user_id      = $rc{$nick}{user_id};
      my $passwd       = $rc{$nick}{password};
      my $delete_after = $rc{$nick}{delete_after};

      #dos      my $pop_state_file = $inbox . "\\" . $nick . '_pop_state';
      my $pop_state_file = $inbox . '/' . $nick . '_pop_state';
      my %pop_state_old  = tms_get_pop_state($pop_state_file);
      my %pop_state_now  = ();
   
      my $mail ='';
      if(!($mail = Net::POP3->new($host)))
      {
         tms_echo('err', "Could not open $nick ($host)\n$!\n"); 
         next;
      }
   
      my $number_of_messages = $mail->login($user_id, $passwd);
      if(!$number_of_messages) 
      { 
         (defined $number_of_messages) or tms_echo('err', "Login error for $nick ($host)\n$!\n");
         $mail->quit();
         next;
      }
      my $index = '';

      my $ref_uids  = $mail->uidl();
      foreach my $message_number (keys %{$ref_uids})
      {
         my $uid  = ${$ref_uids}{$message_number};

         my $flnm = $inbox."/";
         if (!(exists $pop_state_old{$uid}))
         {
           my $the_email = $mail->get($message_number);

           my ($subject, $from, $to, $date, $mark)=();
           my $other_tos  = '';
           my $now_tag='';
           $mark = 'n';
           foreach (@{$the_email})
           {
              /^\s*$/ and last;
            
              if(/^[\w-]+:/)
              {
                 $now_tag='';
                 if(/^Subject:\s*(.*)/i)
                 {
                     $subject = $1;
                     $subject =~ s/\s*$//;
                     $subject =~ s/\|/_/g;
                     my $foo  = $subject;
                     $foo     =~ s/\W/_/g;        # s/[^0-9a-zA-Z_]/_/g;
                     $foo     =~ s/____*/___/g;
                     ($foo) or $foo = '_';
                     $foo     = lc $foo;
                     $flnm   .= $foo; 
                     $now_tag = \$subject;
                 } 
                 (/^From:\s*(.*)/i) and $from = $1       and $now_tag = \$from;
                 (/^To:\s*(.*)/i)   and $to   = $1       and $now_tag = \$to;      
                 (/^CC:\s*(.*)/i)   and $other_tos .= $1 and $now_tag = \$other_tos; 
                 (/^BCC:\s*(.*)/i)  and $other_tos .= $1 and $now_tag = \$other_tos; 
                 (/^Date:\s*(.*)/i) and $date = tms_just_the_date($1) and $now_tag = \$date;
                 (/^Disposition-Notification-To:/i)      and $mark .= 'R';
                 (/^Return-Receipt-To:/i)                and $mark .= 'R';
                 (/^Content-Type:\s*multipart/i)         and $mark .= 'a';
                 (/^Content-Type:.*html/i)               and $mark .= 'h';
              }
              else
              {
                 (my $foo = $_) =~ s/\s*$//;
                 ($now_tag) and ${$now_tag} .= $foo;
              }
           }
           ($mark =~ s/R//g) and $mark .= 'R';
           #($flnm !~ m/\/\s*$/) or  $flnm .= '_'; 
           $from      =~ s/\s*$//;
           $to        =~ s/\s*$//;
           $other_tos =~ s/\s*$//;

           $other_tos = "$to $other_tos";
           $other_tos =~ s/\|/_/g; # this has already been done for $subject

           my $i='';
           while (-e $flnm.$i.'.eml')
           {
              $i =~ s/_//;
              $i++;
              $i = '_'.$i;
           } 
           $flnm = $flnm . $i . '.eml';
           open (OUT, ">$flnm") or tms_die "Unable to create $flnm for writing:$!\n"; 
           print OUT @{$the_email};
           close OUT;
           $u_got_mail++;
     
           ($flnm =~ m/([\w.]+)$/) and $flnm = $1; # remove the leading directory path

           my $entry  = $mark    .'|'. $from .'|'. $other_tos .'|';
              $entry .= $subject .'|'. $date .'|'. $nick      .'|'. $flnm;
           $index    .= $entry . "\n";
        }

        my $foo =  (exists $pop_state_old{$uid}) ? $pop_state_old{$uid} : $now .'_'. $flnm;
           $pop_state_now{$uid} = $foo;
           $foo =~ s/_.*$//; 
           $foo  = $foo + $delete_after; 
        if(($delete_after >= 0) && ($now >= $foo))
        {
            #tms_echo('msgwarn', "marking for deletion...\n");
            $mail->delete($message_number); 
        }
     }
     $mail->quit();

     if($index)
     {
        # dos my  $flnm = $inbox . "\\" . 'index.raw';
        my  $flnm = $inbox . '/index.raw';
        open (OUT, ">>$flnm") or tms_die "Unable to open $flnm for appending:$!\n"; # >> signifies 'append' to the end of file
        print OUT $index, "\n";
        close OUT;
     }
     tms_set_pop_state($pop_state_file, %pop_state_now);
   }
   ($u_got_mail and tms_echo('msghlToDo', "You just got an additional $u_got_mail messages!\n"))
                or tms_echo('msghlsearch', "No new messages.\n"); 
   VIM::DoCommand("let g:tms_u_got_mail = \'$u_got_mail\'");
   return $u_got_mail;
}

# %pop_state = tms_get_pop_state($file) # {{{3
#
#  pop-state file is read into a hash
#
sub tms_get_pop_state # {{{4
{ 
   my ($file) = @_;

   open (IN, $file) or return (); #die "Unable to open $file for reading: $!\n"; 
   my @foo=<IN>;
   close(IN);
   chomp @foo;

   my %pop_state;
   for (@foo)
   {
      my ($id, $time) = split; 
      $pop_state{$id} = $time;
   }
   return %pop_state;
}

# tms_set_pop_state($file, %state) # {{{3
# 
# Re-creates pop-state file from hash
#
sub tms_set_pop_state # {{{4
{

   my ($file, %state) = @_;
   open (OUT, ">$file") or tms_die "Unable to (re-)create $file for writing:$!\n"; 
   for (keys %state)
   {
      print OUT "$_ $state{$_}\n";
   }
   close OUT;
}

# $date = tms_just_the_date('Wed, 7 Jul 2004 16:41:30 +0100') # {{{3
#
# given an input string (usually representing day, date, time-zone), 
#     removes any 3-letter piece of day in it
#     strips leading and trailing white space
#
sub tms_just_the_date # {{{4
{
   my ($foo) = @_;
   
     $foo =~ s/(mon|tue|wed|thu|fri|sat|sun),?//i;
     $foo =~ s/  */ /g;
     $foo =~ s/^\s+//;
     $foo =~ s/\s+$//;
   return $foo;
}

tms_debug("                   3 Done compiling pop\n");
EOPop


"SMTP {{{2
"
perl << EOSmtp
##!/usr/bin/perl   # {{{4
#BEGIN {(*STDERR = *STDOUT) || die;}  
#line 648
use diagnostics;
use warnings;
use strict;
#use CGI qw(:standard);
#use LWP::Simple;
use Net::SMTP;

tms_debug("Compiling smtp...\n");  # {{{3

# $sent_list = tms_send_mail_files(@) # {{{3
#
# Input   - List of files to mail
#
# Calls   - For each file to send, calls
#           tms_send_mail_array_ref(\@) 
#           The argument is a reference to an array of the lines of the file
#
# Result  - g:tms_sent is a comman separated string of the .eml files
#           created as a result of sending each file
#
# Returns - perl variable that is the join with comma of the non-zero 
#           return values from the call to tms_send_mail_array_ref.
#         - this variable is also stored as g:tms_sent 
#           
#
sub tms_send_mail_files # {{{4
{
   my (@what_s) = @_;

   my $sent_list = '';

   foreach my $what (@what_s)
   {
      open (IN, $what) or tms_die("Unable to open $what for reading: $!\n");
         my @lines = <IN>;
      close IN;

      my $flnm = tms_send_mail_array_ref(\@lines);
      $flnm and $sent_list .= "$flnm,";
   }
   $sent_list =~ s/,$//;
   VIM::DoCommand("let g:tms_sent = \'$sent_list\'");
   return $sent_list;
}

# $flnm = tms_send_mail_buffer() # {{{3 
#
# Input   - NONE
#
# Calls   - Saves the current buffer into a temp file (uses VIM's tempname())
#           to get a name;  and calls
#           tms_send_mail_files($temp_file_of_buffer) 
#           Turns out this is faster than collecting the lines of the 
#           buffer into an array and calling tms_send_mail_array_ref(\@) 
#
#         - tms_switch_buffer_file($file_old, $file_new) 
#
# Result  - On a successful send, the current buffer gets replaced by 
#           the file created as a result of sending the temp file.
#
# Returns - whatever was returned by the call to tms_send_mail_array_ref
#
# Note    - Unlike a return from tms_send_mail_files, g:tms_sent is not modified
#
sub tms_send_mail_buffer # {{{4
{
   my ($tmpfl, $flnm) = '';

   # weird: FASTER to save buffer to tmp file and use send file!
   if(0)
   {
         VIM::DoCommand('$');
      my $bot   = tms_get_current_line_number();
      my @lines = $main::curbuf->Get(1 .. $bot);
         VIM::DoCommand('0');
   
      for(my $i=0; $i<scalar @lines; $i++)
      {
          $lines[$i] .= "\n";
      }
   
      $flnm = tms_send_mail_array_ref(\@lines);
      VIM::DoCommand("let g:tms_sent = \'$flnm\'");
   }
   else
   {
       $tmpfl = VIM::Eval("tempname()");
                VIM::DoCommand("execute 'w! $tmpfl'");
       $flnm  = tms_send_mail_files($tmpfl);
   }
   if($flnm =~ m/File:(.*)/)
   {
      tms_switch_buffer_file($tmpfl, $1); 
      VIM::DoCommand("silent! call Eml_open()"); 
   }
   
   # unlink $tmpfl;
   return $flnm;
}

# tms_switch_buffer_file($file_old, $file_new) # {{{3
#
# Result  - Replaces current buffer by $file_new
#         - deletes buffer corresponding to $file_old
#
sub tms_switch_buffer_file  # {{{4
{
   my($old, $new) = @_;

   VIM::DoCommand("execute 'e  $new'");
   VIM::DoCommand("execute 'silent! bd $old'");

   return 1; 
}

# tms_send_mail_array_ref(\@) # {{{3
#
# Input   - reference to an array of \n terminated lines 
#
# Calls   - tms_get_rc();
#         - tms_ip_fmt_time_gm($now);
#         - tms_clean_email_addr($addr);
#
# Operation - Initial elements of input (i.e., elements up to 
#             first white space element) with defaults as 
#             specified in tmsrc file are used to determine
#             how to send the rest of the elements of the 
#             input as an email
#
# Returns   - 0 or a string in the form:
#             Fr:$boo,[To:$foo,][ToFail:$foo,][File:$flnm]
#             The values for To and ToFail are the receipients (irrespective
#             of having been specified in the to or cc or bcc field).
#             flnm is the name of the file used to save a copy of the
#             sent email.  Note that flnm will not have any bcc fields.
#
#             Presence of the Fr:, one or more To: and the File: components 
#             indicates a successful send.
#
# Note      - Date field in sent email is set to +0000 (GMT) time-zone
#
sub tms_send_mail_array_ref # {{{4
{
   my ($ref_lines) = @_;
   my $sent_status = '';
   
   my %rc   = tms_get_rc();
   my $now = time(); 
   my $date = tms_ip_fmt_time_gm($now);

   my ($to, $cc, $bcc, $subject, $receipt, $nick, $from, $reply_to, $id) = ''; 
   my ($sent, $host, $user_id, $passwd, $src_domain) = '';
   my $custom_header = '';
   my $flnm = '';

   while ($_ = shift @{$ref_lines}) 
   {
      chomp;
      /^\s*$/                     and last;
      /^\s*to:?\s*(.*)\s*/i       and $to      .= $1.' ' and next; # multiple lines
      /^\s*cc:?\s*(.*)\s*/i       and $cc      .= $1.' ' and next;
      /^\s*bcc:?\s*(.*)\s*/i      and $bcc     .= $1.' ' and next;
      /^\s*subject:?\s*(.*)\s*/i  and $subject  = $1     and next; # single line
      /^\s*receipt:?\s*(.*)\s*/i  and $receipt  = $1     and next;
      /^\s*nick:?\s*(.*)\s*/i     and $nick     = $1     and next;
      /^\s*from:?\s*(.*)\s*/i     and $from     = $1     and next;
      /^\s*reply_to:?\s*(.*)\s*/i and $reply_to = $1     and next;       
      /^\s*id:?\s*(.*)\s*/i       and $id       = $1     and next;       
      $custom_header .= "$_\n";
   }
   $nick     or (defined $rc{_config}{send_via}) and $nick     = $rc{_config}{send_via};
   $from     or (defined $rc{$nick}{from})       and $from     = $rc{$nick}{from};
   $reply_to or (defined $rc{$nick}{reply_to})   and $reply_to = $rc{$nick}{reply_to};
  
   $from     and $from     = tms_clean_email_addr($from);
   $reply_to and $reply_to = tms_clean_email_addr($reply_to);
   $to       and $to       = tms_clean_email_addr($to);
   $cc       and $cc       = tms_clean_email_addr($cc);
   $bcc      and $bcc      = tms_clean_email_addr($bcc);
  
   $nick or tms_die("smtp host to use for sending has not been specified\n");
   $from or tms_die("from address has not been specified\n");
   $to or $cc or $bcc or tms_die("no recipient has been specified\n");
   $src_domain = $rc{$nick}{src_domain};
  
   ($receipt and ($receipt == 1)) and $receipt = $from; #) =~ s/<(.*)>/$1/;

   if(!defined $id and (defined $rc{_config}{message_id}))
   { 
      $id = $rc{_config}{message_id} . $now .'@'. $src_domain;
      $id = '<'.$id.'>';
   }
   else
   {
      $id = 0;
   }
 
   $sent = $rc{$nick}{dir_sent};
   $host = $rc{$nick}{smtp_host};
 
   $subject or $subject = ' ';
   $flnm = $subject;
   $flnm =~ s/\W/_/g;   
   $flnm =~ s/____*/___/g;
   $flnm = lc $flnm;
   $flnm = $sent .'/'. $flnm;
   my $i='';
   while (-e $flnm.$i.'.eml')
   {
      $i =~ s/_//;
      $i++;
      $i = '_'.$i;
   } 
   $flnm = $flnm . $i . '.eml';
 
   my $header  = "From: $from\n";
      $reply_to and $header .= "Reply-To: $reply_to\n";
      $to       and $header .= "To: $to\n";
      $cc       and $header .= "CC: $cc\n";
      $header .= "Subject: $subject\n";
      $header .= "Date: $date\n";
   if($receipt)
   {
      $header .= "Disposition-Notification-To: $receipt\n"; 
      $header .= "Return-Receipt-To: $receipt\n"; 
   }
   #$custom_header  and  $header .= "$custom_header\n";
   $custom_header and $header  = $custom_header . $header; #both headers end with a \n
   ($id =~ m/\</) and $header .="Message-ID: $id\n";
   $header .="X-Mailer: The Mail Suite (tms) - Send, Receive and Organize via an Editable User Infterface (EUI) - by SG\n";

   $header .= "\n";
 
   my $recipient = '';
   while ($to  and ($to  =~ /<(.*?)>/g)) { $recipient .= "$1,";}
   while ($cc  and ($cc  =~ /<(.*?)>/g)) { $recipient .= "$1,";}
   while ($bcc and ($bcc =~ /<(.*?)>/g)) { $recipient .= "$1,";}
   $recipient =~ s/,$//;

   #--my $fordebug="fr:$from,\nto:$to,\ncc:$cc,\nbcc:$bcc,\nrecipient:$recipient,\n";
   #--$from =~ m/<(.*)>/; 
   #--$fordebug .="smtp-fr:$1,\n";
   #--$fordebug .= 'File:d:/tms/tms/sent/a_test_subject.eml';
   #--return $fordebug;

   my $mail = Net::SMTP->new($host, 
                             # Port =>  25,
                             Hello => $src_domain,
                             # Hello => 'this_here',
                             # Timeout => 30,
                             # Debug   => 1,
                            ); 
   if(!$mail)
   {
      tms_echo('err', "Could not open $nick ($host)[$subject]\n$!\n"); 
      return 0;
   }

   if($rc{$nick}{smtp_auth})
   {
      if(!$mail->auth($rc{$nick}{user_id}, $rc{$nick}{password}))
      {
         tms_echo('err', "Could not authenticate user ($nick: $rc{$nick}{user_id} on $host)[$subject]\n$!\n"); 
         return 0;
      }
   }

   $from =~ m/<(.*)>/; # $from will have <> since it was cleaned-up
   my $boo = $1;  # a bad value will be caught by the call to mail
   $sent_status = "Fr:$boo,";
   if(!$mail->mail($boo))
   { 
      tms_echo('err', "Bad from address $from [$subject]: $!\n");
      $mail->quit();
      return $sent_status;
   }
 
   my $all_failed = 1;
   foreach my $foo (split ",", $recipient)
   {
       if($mail->recipient($foo))
       {  
          $sent_status .= "To:$foo,";
          $all_failed = 0;
       }
       else
       {
          $sent_status .= "ToFail:$foo,";
          tms_echo('msgwarn', "Could not set recipient $foo [$subject]\n$!\n");
       }
   }

   if($all_failed)
   {
       tms_echo('err', "Could not set ANY recipient [$subject]\n$!\n"); 
       $mail->quit();
       return $sent_status;
   }
 
   if(!$mail->data())
   {
      tms_echo('err', "$nick ($host) not ready for [$subject]\n$!\n");
      $mail->quit();
      return $sent_status;
   }
   $mail->datasend($header);
   $mail->datasend(@{$ref_lines});
   
   if(!($mail->dataend()))
   {
      tms_echo('err', "Data of [$subject] refused by $nick ($host):\n$!\n");
      $mail->quit();
      return $sent_status;
   }
   if(!($mail->quit()))
   {
      tms_echo('msgwarn', "Could not quit $nick ($host) after sending [$subject]\n$!\n");
      return $sent_status;
   }
 
   if($bcc)
   {
      $header =~ s/^(Subject: .*)$/BCC: $bcc\n$1/m; # header always has a subject
   }
   open (OUT, ">$flnm") or tms_die "Unable to create $flnm for writing:$!\n"; 
   print OUT $header; 
   print OUT @{$ref_lines}; 
   close OUT;
   $sent_status .= "File:$flnm";
 
      ($flnm =~ m/([\w.]+)$/) and $flnm = $1; # remove the leading directory path
 
   my $entry  =            '|'. $from .'|'. $to   .'|';
      $entry .=  $subject .'|'. $date .'|'. $nick .'|'. $flnm;
      $entry .= "\n";
 
   $flnm = $sent . '/index.raw';
   if(open (OUT, ">>$flnm")) 
   {
      print OUT $entry;
      close OUT;
   }
   else
   {
      tms_echo('err', "Unable to re-open $flnm for appending:$!\n"); 
   }

   return $sent_status;
}

# tms_ip_fmt_time_gm($seconds) # {{{3
#
# Input    - seconds as in the return from localtime()
#
# Returns  - a string representing the GMT based time in 
#            the form:  Fri, 16 Jul 2004 18:45:25 +0000
#            which is a form suitable for use in mail headers
#
sub tms_ip_fmt_time_gm # {{{4
{
   my($date) = @_;

   $date = gmtime $date;
   #date:   Fri Jul 16 11:45:25 2004

   $date =~ s/^(\S+)\s*(\S+)\s*(\d+)\s*(\S+)\s*(\d+)/$1, $3 $2 $5 $4 +0000/;
   #Date: Fri, 16 Jul 2004 18:45:25 +0000

   return $date;
}

# $rv = tms_ip_fmt_time_2_gm_seconds($foo) # {{{3
#
# Input   - date string in the form:  Fri, 16 Jul 2004 18:45:25 +0130
#
# Output  - seconds based on GMT
#
sub tms_ip_fmt_time_2_gm_seconds # {{{4
{
use Time::Local;

   my($date) = @_;
   #Date: Fri, 16 Jul 2004 18:45:25 +0000

   $date =~ s/^\w\w\w,\s*//;
   ($date =~ m/(\d+) (\w+) (\d+) (\d+):(\d+):(\d+) (.\d\d\d\d)/) or return 0;
   my ($sec, $min, $hours, $mday, $mon, $year, $tz) = ($6, $5, $4, $1, $2, $3, $7);

   $year = $year - 1900;
   my $i=0;
   foreach (qw(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec))
   {
      ($mon =~ m/$_/i) and last;
      $i++;
   }
   ($i == 12) and return 0;

   $tz =~ m/(.)(\d\d)(\d\d)/ or return 0;
   my ($sign, $adjust) = ($1, ($2 * 60 + $3) * 60);
   $adjust             = ($sign =~ /-/) ? $adjust :  - $adjust;

   my $rv = timegm($sec, $min, $hours, $mday, $i, $year);

   $rv += $adjust;

   return $rv;
}

# $tz = tms_get_time_zone_info() # {{{3
#
# Returns   - string giving the local time-zone in the form [+-]hhmm
#
sub tms_get_time_zone_info # {{{4
{
   # local - gmt = tz 

   my $now    = time();  # need to use now rather than 0 because of daylight savings etc.
   my $tlocal = localtime $now;
   my $tgm    = gmtime $now;

   #local:Sat Jul 24 08:28:22 2004, gm:Sat Jul 24 15:28:22 2004  -0700.25200
 
   $tlocal =~ /\w\w\w ([\d ]\d) (\d\d?):(\d\d?):(\d\d?) (\d\d\d\d)/;
   my ($ld, $ls) = ($1, ((($2 * 60) + $3) * 60) + $4);  
 
   $tgm    =~ /\w\w\w ([\d ]\d) (\d\d?):(\d\d?):(\d\d?) (\d\d\d\d)/;
   my ($gd, $gs) = ($1, ((($2 * 60) + $3) * 60) + $4);  
 
   my $tz    = $ls - $gs;
   my $delta = $ld - $gd; 

   ($delta > 1)  and $delta = -1;
   ($delta < -1) and $delta =  1;
   $delta = $delta * 24 * 60 * 60;
   $tz    = $tz + $delta;
   my $sign = '+';
   if($tz < 0){$sign = '-'; $tz = -$tz;}
   $delta = $tz;
   
   my $hours = int($tz / 3600);
   my $minutes = $tz - ($hours * 3600);
      $minutes = int ($minutes / 60); 

      $tz = sprintf("%1.1s%2.2d%2.2d.%d", $sign, $hours, $minutes, $delta);
      
   return $tz;
}

# $val = tms_gm_seconds_2_ip_local_zone($gm_seconds, $tz) # {{{3
#
# Input    - GMT based seconds and a time-zone (in form [+-]hhmm)
#
# Returns  - string representing time in time-zone in the form:
#            16 Jul 2004 18:45:25 -0700
#
sub tms_gm_seconds_2_ip_local_zone # {{{4
{
   my($gm_seconds, $tz) = @_;

   $tz =~ /((.)(\d\d\d\d))\.(\d*)/;
   my ($sign, $tz_mark, $adjust) = ($2, $1, $3);

   #---   ($sign = /-/) and $adjust = -$adjust; 
   #---   my $tmstr = gmtime ($gm_seconds + $adjust);
   #---
   #---   $tmstr =~ s/^(\S+)\s*(\S+)\s*(\d+)\s*(\S+)\s*(\d+)/$3 $2 $5 $4 $tz_mark/;
   #---   #Date: Fri, 16 Jul 2004 18:45:25 -0700

   my $tmstr = localtime ($gm_seconds); 
      $tmstr =~ s/^(\S+)\s*(\S+)\s*(\d+)\s*(\S+)\s*(\d+)/$3 $2 $5 $4 $tz_mark/;

   return $tmstr;
}

# tms_clean_email_addr  # {{{3
#
# Input   - comma or space separated email addresses
#           with or without quotes around human-readable piece
#           with or without angle brackets around actual address
#
# Requirement - pieces of the address must begin with word character \w
#               only non-word character allowed in address is -
#               2do: allow = in address
#
# Returns - cleaned up version of input
#              angle brackets around addresses
#              no extra white space (including before <)
#              comma as separator 
#
sub tms_clean_email_addr # {{{4
{
    my $addr = tms_expand_nicks_in_email_addr(@_);
    
    # remove leading space, space around delimiters and trailing space
    $addr =~ s/^\s*//;
    $addr =~ s/\s*([<>,"'])\s*/$1/g;
    $addr =~ s/\s*$//;
    #add <> if required
    $addr =~          s/^(\w[\w.=-]*\@\w[\w.-]*\.\w*)/<$1/;
    $addr =~ s/([\s,>"'])(\w[\w.=-]*\@\w[\w.-]*\.\w*)/$1<$2/g;
    $addr =~ s/(\w[\w.=-]*\@\w[\w.-]*\.\w*)$/$1>/;
    $addr =~ s/(\w[\w.=-]*\@\w[\w.-]*\.\w*)([\s,<"'])/$1>$2/g;

    #add , if required 
    $addr =~ s/>\s*(["'<]?\w)/>,$1/g;

    # clean-up spaces
    $addr =~ s/^\s*//;
    $addr =~ s/\s*([<>,"'])\s*/$1/g;
    $addr =~ s/\s*$//;

    #    # don't like this style: add quotes for non-empty, unquoted human readable stuff
    #    $addr =~ s/^(\w[^<]*)</"$1" </g;
    #    $addr =~ s/>,(\w[^<]*)</>, "$1" </g;

    #    # add space before <, if required
    #    $addr =~ s/([^\s])</$1 </g;

    return $addr;
}
# tms_expand_nicks_in_email_addr # {{{3
#
# place-holder DOES NOTHING
#
#
sub tms_expand_nicks_in_email_addr # {{{4
{
    my ($addr) = @_;
    return $addr;
}

tms_debug("                   4 Done compiling smtp\n");
EOSmtp


"Organizer {{{2
"
perl << EOOrganizer
##!/usr/bin/perl   # {{{4
#BEGIN {(*STDERR = *STDOUT) || die;}  
#line 1189
use diagnostics;
use warnings;
use strict;
#use CGI qw(:standard);
#use LWP::Simple;
#use Net::SMTP;

tms_debug("Compiling organizer...\n");  # {{{3

# tms_make_index # {{{3
#
# Input   - list of directories 
#
# Result  - updates the index.idx file in each directory
#
# Note    - nothing else other than calling subroutines happens here
#
# Idea    - Start by verifying existence of the directory  
#           For each .eml file in the directory, if it does not have an entry 
#               in the .raw file, then create the entry 
#           For each entry in the raw file, if a .eml file does not exist then
#               delete it
#           For each entry in the .idx file, if there is an entry in the .raw
#               file then update the mark in the .raw entry 
#           Determine the max width for each column in the .raw file
#           Get the header from the .idx file
#           Create the format hash based on the preceding two items
#               the format will have info on the columns, their widths 
#               and their sort-order in the to-be-created .idx file
#           Create the .idx file based on the .raw file and the format hash 
#
#
sub tms_make_index # {{{4
{
   my (@what_s) = @_;

   foreach my $what (@what_s)
   {
       my $dir       = tms_get_dir($what);  
       my @raw_lines = tms_get_lines($dir . '/index.raw'); 
       my $ref_raw   = tms_get_raw_hash(\@raw_lines); 
       my @files     = tms_get_file_names($dir . '/*.eml');

       tms_update_raw_4files_add($ref_raw, $dir, \@files);
       tms_update_raw_4files_trim($ref_raw, \@files);
       tms_update_raw_4mark($ref_raw, $dir . '/index.idx'); 
       tms_write_raw($ref_raw, $dir . '/index.raw');

       my $ref_max   = tms_get_raw_max_widths($ref_raw); 
       my $header    = tms_get_header($dir . '/index.idx');
       my %format    = tms_get_idx_format($header, $ref_max); 

       tms_raw_to_index_sorted($ref_raw, \%format, $dir . '/index.idx'); 
   }
}


# $dir = tms_get_dir($what);   # {{{3
#
# main purpose is to strip the last file-name, if present
# (returns input if it is a directory)
# assumes file-name is made up of \w and ..
# stuff that remains after stripping is not tested for being a directory
#
sub tms_get_dir # {{{4
{
   my ($what) = @_; 
  
   $what =~ s/[\w.]*$//  unless -d $what;
   $what =~ s/[\\\/]$//;
   #return (-d $what) ? $what : '';
   return $what;
}

# @raw_lines = tms_get_lines($dir . '/index.raw');  # {{{3
#
# Given a file, returns array of its chomped lines
#
sub tms_get_lines # {{{4
{
   my($flnm) = @_; 

   open (IN, $flnm) or return ();  # tms_die("Unable to open $flnm for reading: $!\n");
      my @lines = <IN>;
   close IN;
   chomp @lines;
   return @lines;
}

# $ref_raw = tms_get_raw_hash(\@lines);  # {{{3
# 
# Given an array of the chomped lines of a .raw file, returns a hash
# Keys of the hash are .eml files, and values are the corresponding raw lines.
#
sub tms_get_raw_hash # {{{4  
{
   my($ref_lines) = @_;

   my $line='';
   my %f2line=();  

   foreach $line (@{$ref_lines})
   {  
      # blank lines are OK 
      # no white space between fields boundries. | (field values can have white space)
      next unless ($line =~ m/.*\|(\w[\w ]*\.eml)$/); # $ reqd to avoid match in subject field
      $f2line{$1} = $line; 
   }
   return \%f2line;  
}

# $ref_max = tms_get_raw_max_widths($ref_raw) # {{{3
#
# Given a reference to the raw-hash, returns a reference to a hash
# whose keys are the names of the columns and whose values are the 
# maximum width of the column.
#
# For the date (E) column, width is computed by discarding any stuff
# after the time-zone signature ([+-]hhmm).  If the time-zone signature
# is not in the standard form (eg, GMT instead of +0000) then it too
# is discarded.  Note that the date in the .raw file does not has the
# week-day in it.  The attempt is to retain as much of the form 
# "dd mmm yyyy hh:mm:ss [+-]hhmm" as possible.
#
sub tms_get_raw_max_widths # {{{4  
{
   my($ref_raw) = @_;

   my $line='';
   my %max=();  
   my $i=0; 
   my $h = '([^|]*)\|';
      $h = $h x 6 . '([^|]*)';
   my @w_col=();

   $max{$_} = 0 foreach (qw(M F T S E N L)); 

   foreach $line (values %{$ref_raw})
   {  
      next unless ($line =~ m/$h/o);
      @w_col = (length $1, length $2, length $3, length $4, length $5, length $6, length $7); 
      my $foo  = $5;
         $foo  =~ s/([\+\-]\d\d\d\d)(.*)$/$1/;
         ($foo =~ m/\d\d:\d\d:\d\d [\+\-]\d\d\d\d/) or $foo =~ s/(\d\d:\d\d:\d\d)(.*)$/$1/; 
          $w_col[4] = length $foo;

      $i = 0;
      foreach my $tag (qw(M F T S E N L)) 
      {
         $max{$tag} = $max{$tag} > $w_col[$i] ? $max{$tag} : $w_col[$i];
         $i++;
      }
   }
   return \%max;
}

# @files = tms_get_file_names($dir . '/*.eml') # {{{3
#
# Uses VIM to glob the input pattern, strips the path from the
# resulting list and returns the list of bare file-names 
#
# Since there could be spaces in the filenames, cannot use perl's glob;
# need to use File::Glob -- but VIM kept crashing with the following code:
#
#---{
#---   my ($which) = @_;
#---   {
#---      # The next is needed to account for spaces in filenames
#---      # BUT VIM CRASHES with this on!
#---      #use File::Glob ':glob';  
#---      
#---      return  map {s/^.*[\\\/]//; $_} glob $which;
#---   }
#---}
# 
sub tms_get_file_names # {{{4
{
   my ($which) = @_;
   #{
   #   my @full_path_files = glob $which;
   #   my @files=();
   #   foreach my $foo (@full_path_files)
   #   {
   #      $foo =~ s/^.*[\\\/]//;
   #      push @files, $foo;
   #   }
   #   return @files;
   #}

      my $foo = "let b:tms_fooey = glob(\"$which\")";
                VIM::DoCommand($foo); 
         $foo = VIM::Eval('b:tms_fooey');

      my @fp_files = split /\n/, $foo;

      my @files=();

      my $boo='';
      foreach $boo (@fp_files)
      {
         $boo =~ s/^.*[\\\/]//; # clear the path so that only the file names remain
         push @files, $boo;
      }
      return @files;
}

# tms_update_raw_4files_add(\%raw, $dir, \@files); # {{{3
#
# If a .eml file in the directory does not have an entry in the raw hash
# then an entry for it is created.  Uses a call to tms_get_entry($fp_file)
#
sub tms_update_raw_4files_add # {{{4
{
   my($href_raw, $dir, $aref_files) = @_;

   my $key='';
   foreach $key (@{$aref_files})
   {
       exists ${$href_raw}{$key} and next;
       ${$href_raw}{$key} = tms_get_entry($dir .'/'. $key);
   }
}

# tms_update_raw_4files_trim(\%raw, \@files); # {{{3
#
# For each entry in the raw hash, if the corresponding file 
# does not exist in the array of files, delete the entry
#
sub tms_update_raw_4files_trim # {{{4
{
   my($href_raw, $aref_files) = @_;

   my %hfiles=();
   my $key='';

   $hfiles{$_}++ foreach (@{$aref_files});

   foreach $key (keys %{$href_raw})
   {
       exists $hfiles{$key} and next;
       #${$href_raw}{$key}=();
       delete ${$href_raw}{$key};
   }
}

# tms_update_raw_4mark($ref_raw, $dir . '/index.idx') # {{{3
#
# For each line in the .idx file, if the .eml file corresponding 
# to it is a key of the raw hash then over-write the mark of the 
# corresponding value;  otherwise do nothing (no need to delete 
# the line from the .idx file since the .idx file will soon 
# be overwritten).
#
sub tms_update_raw_4mark # {{{4
{
   my ($ref_raw, $file) = @_;

   open (IN, $file) or return;
      my @idx_lines = <IN>;
   close IN;
   chomp @idx_lines;

   my ($line, $mark, $foo) = ();
   foreach $line (@idx_lines)
   {
      ($line =~ m/^([^|]*)((\|\s*)|(\|.*\|\s*))(\w[\w ]*\.eml)\s*$/) or next; # adjusting for white space curruption
      $mark =  $1;
      $file =  $5;
      ($mark and $file) or next;
      $mark =~ s/^\s*//;
      $mark =~ s/\s*$//;
      exists ${$ref_raw}{$file} or next; # no need to delete from .idx file since idx file will be redone 
      $foo  =  ${$ref_raw}{$file};
      $foo  =~ s/^([^|]*)\|/$mark\|/;
      ${$ref_raw}{$file} = $foo;
   }
   return;
}

# tms_write_raw(\%raw, $dir . '/index.raw') # {{{3
#
# Write out the raw has as the .raw file.
#
sub tms_write_raw
{
  my ($ref_raw, $flnm) = @_;

  open (OUT, ">$flnm") or tms_die("Unable to create $flnm for writing: $!\n");
      print OUT join "\n", values %{$ref_raw};
      print OUT "\n\n"; # 2do for later:  having or not having one \n seem to be the same;  two \n's here do what I expect one \n here to do -- WHY?
  close OUT;
}

# tms_get_entry($dir .'/'. $flnm); # {{{3
#
# Given an email file, go through its header and create
# an entry for the .raw file.
#
sub tms_get_entry # {{{4
{
   my ($file) = @_;
   
   my ($mark, $from, $to, $subject, $date, $other_tos) = ();
   $mark = '';
   $other_tos  = '';

   my $flnm =  $file;
      $flnm =~ s/^.*[\\\/]//;

   return  "|||||$flnm|"  unless open (IN, $file);

   my $now_tag='';
   while(<IN>)
   {
      chomp;
      /^\s*$/ and last;

      if(/^[\w-]+:/)
      {
         $now_tag='';
         (/^Subject:\s*(.*)/i) and $subject    = $1 and $now_tag = \$subject;
         (/^From:\s*(.*)/i)    and $from       = $1 and $now_tag = \$from;
         (/^To:\s*(.*)/i)      and $to         = $1 and $now_tag = \$to; 
         (/^CC:\s*(.*)/i)      and $other_tos .= $1 and $now_tag = \$other_tos; 
         (/^BCC:\s*(.*)/i)     and $other_tos .= $1 and $now_tag = \$other_tos; 
         (/^Date:\s*(.*)/i)    and $date       = tms_just_the_date($1) and $now_tag = \$date;
         (/^Content-Type:\s*multipart/i) and $mark .= 'a';
         (/^Content-Type:.*html/i)       and $mark .= 'h';
      }
      else
      {
         ($now_tag) and ${$now_tag} .= $_;
      }
   }
   close IN;
   $to = "$to $other_tos";
   $to =~ s/\|/_/g;

   $subject =~ s/\|/_/g;

   return  $mark .'|'. $from .'|'. $to   .'|'. $subject .'|'. $date .'||'. $flnm;
}


# $header = tms_get_header($dir . '/index.idx'); # {{{3
#
# Given a file, if its first line remotely-seems to be a .idx header 
# line (has the char | in it) then return it;  else return the
# default .idx header
#
sub tms_get_header # {{{4
{
   my($file) = @_;

   my $default = ' Mrk | From           | To             | Subject2                               | sEnt1        | Nick | fiLename   ';
   return $default unless open (IN, $file);
   my $foo = <IN>;
   close IN;
   chomp $foo;
   ($foo =~ m/\|/) or $foo = $default;
   return $foo;
}

# %format = tms_get_idx_format($header, $ref_max) # {{{3
#
# Given a .idx header line and the hash of the .raw file's max 
# widths in, build the format hash and return it.
#
# The format hash contains information about the columns to
# show in the .idx file, the width of those columns and the 
# sort order (and direction) of those columns.
#
# To what's in the format hash, it might help to see the 
# subroutine tms_dump_format()
#
sub tms_get_idx_format # {{{4
{
  my($header, $ref_max) = @_;  

  my %format = ();
  my $strf = ' ';
  my @asort = ();
  my ($type, $width, $max_width, $direction) = (); 

  my $new_head = ' ';   
  foreach my $head (split /\|/, $header)
  {
      $type = '';
      ($head =~ m/([A-Z])/) and $type = $1; 
      $type and push @{$format{column}}, $type;
      
      $width = length($head) - 2; 
      $max_width = ${$ref_max}{$type}; 
      if($head =~ m/[\*LN]/)
      { 
         $width = ($width > $max_width) ? $width : $max_width; 
      }
      $width = "-$width.$width";
      $strf .= '%'.$width.'s | ';
      $head =~ s/ //;
      $new_head .= sprintf('%'.$width.'s | ', $head);

      $direction = 1;
      ($head =~ m/(-)/)  and $direction = 0;
      ($head =~ m/(\d)/) and $asort[$1-1] = {type => $type, direction => $direction};
  }
  $new_head =~ s/\| $//;   
  $format{raw} = $new_head;
  $strf =~ s/ \| $//;
  $format{string} = $strf;
  $format{sort_order} = \@asort; 

  my $ncols       = scalar @{$format{column}}; 
  my $type_ult    = ${$format{column}}[-1];

  # last column MUST be fiLename
  # MUST have at least two columns
  if(($type_ult ne 'L') or ($ncols <= 1)) 
  {
     my $err  = "Invalid header:\n$header\n";
        $err .= "ncols=$ncols\n";
        $err .= "ult=$type_ult\n";
        $err .= "penult=${$format{column}}[-2]\n";
        $err .= "Exiting\n";
     tms_echo($err);
     exit; 
  }
  return %format;
}

# tms_dump_format(\%format); # {{{3
#
# Dump the format hash
#
sub tms_dump_format # {{{4
{
   my ($ref_format) = @_;

   my $n = '';
   my %format = %{$ref_format};

   my $expand = "Raw:\n".$format{raw}."\n\n";

   $expand .= "Format string:\n".$format{string}."\n\n";

   $n = scalar @{$format{column}}; 
   $expand .= "Order of the $n columns:";
   foreach (@{$format{column}}){$expand .= "  $_"}
   $expand .= "\n";
   
   $expand .= "The $n columns read explicitly:";
   for(my $i=0; $i<$n; $i++)
   {
      $expand .= "  [$i]->".${$format{column}}[$i];
   }
   $expand .= "\n\n";

   $n = scalar @{$format{sort_order}}; 
   $expand .= "Number of columns sorted: $n\n";
   for(my $i=0; $i<$n; $i++)
   {
      $expand .= "    $i:  ". ${${$format{sort_order}}[$i]}{type}; 
      $expand .=        "  ". ${${$format{sort_order}}[$i]}{direction} ."\n"; 
   }
   $expand .= "\n";

   tms_print($expand);
}


# tms_raw_to_index_sorted(\%raw, \%format, $dir . '/index.idx')  # {{{3
#
# Given a raw hash, a format hash and the name of a .idx file, 
# overwrite the file with the raw hash formated as per the 
# format hash.  
#
# Algorithm is fast since it sorts the date stamp by converting 
# it -- only once (not for each comparison) -- to GMT-seconds;  
# also, instead of sorting a hash, it pre-builds a special array 
# and sorts this array.
#
sub tms_raw_to_index_sorted # {{{4
{
   my($ref_raw, $ref_format, $file) = @_;

   my $index  = ${$ref_format}{raw};
      $index .= "\n". '-' x length($index) ."\n";
   my $strf  = ${$ref_format}{string};

   my @column = @{${$ref_format}{column}};
   for(1 .. 6) {push @column, 'M'}
     
   my @raw_lines_pieces = map { [ split /\|/] } values %{$ref_raw};

   my $tz = tms_get_time_zone_info();

#----------------------------------------------------------------
   our @asort          = @{${$ref_format}{sort_order}};
   our $num            = (scalar @asort) - 1;
   our $rel_date_index = 0;
   our %type2index     = ();
   our $i = 0;
   $type2index{$_}     = $i++ for qw(M F T S E N L); 
   my  $date_index     = $type2index{E};
   my  $subject_index  = $type2index{S};
   my  $from_index     = $type2index{F};
   my  $to_index       = $type2index{T};
   

   for my $foo (@raw_lines_pieces)
   {
      for $i (0 .. $num)  
      {
         my $index = $type2index{$asort[$i]{type}};
         my $val   = ${$foo}[$index];

         if(($index == $from_index) or ($index == $to_index))
         {
            $val =~ s/["']([^"']+?)["'](.*)/$1$2/;
            $val =~ s/^\s*//;
            $val =~ s/^<([^<>]+?)>/$1/;
            $val =~ s/^\s*//;
         }
         if($index == $date_index)
         { 
            $rel_date_index = $i;
            $val = tms_ip_fmt_time_2_gm_seconds($val);
         }
         if($index == $subject_index)
         { 
            $val =~ s/\s*re\w?:?\s*//i;
            $val =~ s/\s*fw\w?:?\s*//i;
            while($val =~ s/^\s*((re)|(fw))\w?:\s*//) {};  #e.g., re: ref: reg: fw: fwd:
            $val = lc($val);
         }
         push @{$foo}, $val; 
      }
   }
   $num            += 7;
   $rel_date_index +=7;

#----------------------------------------------------------------
     
   my (@araw, @cols, %hraw) = ();
   foreach (sort tms_index_line_comparator @raw_lines_pieces) 
   {
       @araw = @{$_};
       @cols = ();
       $i = 0;
       foreach (qw(M F T S E N L)) 
       {
          defined $araw[$i] or $araw[$i]='';
          my $val = $araw[$i++];

          ($_ =~ /E/) and $val = tms_gm_seconds_2_ip_local_zone($araw[$rel_date_index], $tz);

          push @cols, ($_, $val);
       }
       %hraw = @cols;
       my $entry = sprintf($strf, $hraw{$column[0]}, $hraw{$column[1]}, $hraw{$column[2]}, $hraw{$column[3]}, $hraw{$column[4]}, $hraw{$column[5]}, $hraw{$column[6]}); 
       $index .= $entry ."\n";
   }

   open (OUT, ">$file") or tms_die("Unable to create $file for writing: $!\n");
      print OUT $index; 
   close OUT;

   #---------------------------------------------------------------
   sub tms_index_line_comparator  # {{{4
   {
      my $rv = 0;
      for $i (7 .. $num)  
      {
          if($i != $rel_date_index)
          {
              $rv = ${$a}[$i] cmp ${$b}[$i];
          }
          else
          {
              $rv = ${$a}[$i] <=> ${$b}[$i];
          }
          $rv and last;
      }
      ($i > $num) and tms_echo('err', "Invalid index: $i is bigger than $num");
      $rv = $asort[$i-7]{direction} ? $rv : -$rv;
      return $rv;
   }
   #---------------------------------------------------------------
}

tms_debug("                   5 Done compiling organizer\n");
EOOrganizer


"Working {{{2
"
perl << EOWorking
##!/usr/bin/perl   # {{{4
#BEGIN {(*STDERR = *STDOUT) || die;}  
#line 1789
use diagnostics;
use warnings;
use strict; 
#use CGI qw(:standard);
#use LWP::Simple;
#use Net::SMTP;

tms_debug("Compiling working...\n");  # {{{3

my $tms_ok_to_bw_in_perl  = !(VIM::Eval('g:tms_do_not_bw_in_perl')); 
my $tms_ok_to_bun_in_perl = !(VIM::Eval('g:tms_do_not_bun_in_perl')); 

# tms_w_do_this('x') # {{{3
#
#  The first version of this module had several subroutines, 
#  each of 3 to 4 lines.  But that design was scrapped for the
#  present version.  This version will soon be redone with 
#  structures (thereby making it more readable).
#
#  This user manipulates the .eml files -- open (or view), reply, 
#  reply-to-all, forward, acknowledge, delete, move, copy, go-to
#  next, go-to previous etc. -- via routines in this module.
#
#  All these manipulations start with the current buffer being
#  either an .idx file or a .eml file.
#
# dev notes {{{5
# n-next            must be called from eml -- replace old eml by new eml 
# p-previous        must be called from eml -- replace old eml by new eml 
#
# o-open          must call from idx file  show requested eml in a sb window 
# r-reply         show partial response, if called from eml, replace old eml 
# R-Reply-all     show partial response, if called from eml, replace old eml 
# f-forward       show partial response, if called from eml, replace old eml 
# A-acknowledge,  show partial response, if called from eml, replace old eml 
#
# d-delete if eml and idx then replace eml by next
# m-move   if eml and idx then replace eml by next
# c-copy
#
# 2do:
# dmc -> in addition to calling context of current eml, current line in idx, 
#        support visual block selection in idx by identifying calling context
#        (just say default calling range is current line!)
#        Won't need special DMC code
#        BUT then again may be better to leave things as they are!
# f -> as above, support forwarding multiple items 
# F -> forward as attachment: current eml, current line in idx, visual block in idx
#
# 5}}}
#
sub tms_w_do_this # {{{4
{
  my ($do_what) = @_;
  my $rv        = 0;
  my ($from_idx, $have_other, $idx_file, $idx_line_number, $idx_line, $eml_file)
                = tms_w_get_calling_eml_idx_context();

  return unless $eml_file;

  my $unlink_this = '';
  if($do_what =~ /[d|c|m]/)
  {
     my $where_to = '';
     $where_to    = ($do_what  =~ /d/) ? tms_get_dir_trash() : tms_get_destination_dir();
     $where_to or return 0;
     $rv          = tms_copy_file($eml_file, $where_to);
     #rv is full path version of $eml_file
     
     $unlink_this = $rv unless ($do_what =~ /c/);
     #-will unlink after bw-if($rv and $do_what !~ /c/)
     #-will unlink after bw-{ 
     #-will unlink after bw-   unlink $rv;
     #-will unlink after bw-}

     # do NOT bw eml_file just now because might need to drop to this buffer
     # and open the eml_file from the next line in the idx file
  }
  if($do_what =~ /[n|p]/)
  {
     # has to be called from eml file and with consistent idx buffer 
     #                           will check consistence even if 
     #                           it means sb to idx (when idx is not in buffer list)
     #                           consistence means must have line in idx for this eml
     return 0 if $from_idx; 

     my $flnm  = '';
     $eml_file =~ /(\w[\w ]*\.eml)$/ and $flnm = $1;

     if(!$have_other)
     {
        #if other was a hidden buffer, then in context finder: OK to have sb'ed to it and set have_other
        VIM::DoCommand("silent sb $idx_file");
     }
     else
     {
        VIM::DoCommand("silent drop $idx_file");
     }
     VIM::DoCommand("normal gg");
     VIM::DoCommand("/ $flnm\\s*\$");
     VIM::DoCommand("silent! nohls");
     $idx_line_number = tms_get_current_line_number();
     $idx_line        = tms_get_content_of_line($idx_line_number);
     $flnm            = tms_get_eml_from_idx_line($idx_line);
     $have_other = ($flnm =~ /\w[\w ]*\.eml/i) and ($eml_file =~ /\b$flnm$/);
     $rv = $have_other; 
     $rv or return 0; 

     my $max = $main::curbuf->Count();
     my $new_line = 1;
        ($do_what =~/p/) and $new_line = -1;
        $new_line = $idx_line_number + $new_line;
        ($new_line <= $max) or $new_line = 1; # a bad line

        $idx_line_number = $new_line;
        $idx_line        = tms_get_content_of_line($idx_line_number);
        $flnm            = tms_get_eml_from_idx_line($idx_line);

        if(!$flnm)
        {
           tms_echo('err', "No valid file to go to\n");
           return 0;
        }
        $main::curwin->Cursor($new_line, 0);

      $idx_file =~ /(.*)\bindex\.idx$/i;
      $flnm     = $1 . $flnm;

      VIM::DoCommand("silent! drop $eml_file|silent! e $flnm|silent! call Eml_open()"); 

      if($tms_ok_to_bw_in_perl)
      {
         VIM::DoCommand("silent! bw! $eml_file");
      }
      elsif($tms_ok_to_bun_in_perl)
      {
         VIM::DoCommand("silent! bun! $eml_file");
      }
  } 
  if($do_what =~ /o/)
  {
     if(!$from_idx)
     { 
        # commented out next line since it is actually a no-op (because we are not from_idx!)!
        #VIM::DoCommand("drop $eml_file");
        return 0;
     }
     my $foo = 'new ';
     if($have_other) # may have opened the file; hidden it; and now come back to idx file and doing open again
     {
         #here, if other is a hidden buffer, then in context finder: OK to have sb'ed to it and set have_other 
         $foo = 'drop ';
     }
     VIM::DoCommand("silent $foo $eml_file|silent! call Eml_open()");
     $rv = 1;
  }

  if($do_what =~ /[r|R|f|A]/)
  {
       if(($do_what !~ /A/) and ((!$from_idx) or ($have_other)))
       {
          #here, if other is a hidden buffer, then in context finder: ...
          if($tms_ok_to_bw_in_perl)
          {
             VIM::DoCommand("silent! drop $eml_file|silent! bw!");
          }
          elsif($tms_ok_to_bun_in_perl)
          {
             VIM::DoCommand("silent! drop $eml_file|silent! bun!");
          }
          else
          {
             VIM::DoCommand("silent! drop $eml_file");
          }
       }
       if(($do_what =~ /A/) and ($have_other == 2))
       {
           #here, if other is a hidden buffer, in context finder: ... undo what was done
           VIM::DoCommand("silent! drop $eml_file|silent! hide");
       }

    my $command = "silent new |silent r $eml_file|normal ggdd"; # Remove very first BLANK line
       VIM::DoCommand($command);

    my $header = '';
    my $i = 1;
    my $line = tms_get_content_of_line($i);
    while ($line !~ /^\s*$/)
    {
       $header .= "$line\n";
       $i++;
       $line = tms_get_content_of_line($i);
    }
    $main::curbuf->Delete(1, $i); 

    my($to, $cc, $subject, $from, $date)=('', '', '', '', '');
    my($references, $message_id)        =('', '');
       
      while($header =~ m/^to:[ \t]*([^\r\n]*)[ \t]*/img) {$to .= $1}
      while($header =~ m/^cc:[ \t]*([^\r\n]*)[ \t]*/img) {$cc .= $1}

      ($header =~ m/^subject:\s*(.*)/im)       and $subject    = $1;
      ($header =~ m/^from:\s*(.*)\s*/im)       and $from       = $1;
      ($header =~ m/^date:\s*(.*)\s*/im)       and $date       = $1;
      ($header =~ m/^references:\s*(.*)\s*/im) and $references = $1;
      ($header =~ m/^message-id:\s*(.*)\s*/im) and $message_id = $1;
       $references = "$references $message_id";
       $references =~ s/^\s+//; # reqd to handle case of no references in original header

       $subject      =~ s/\s*$//;
    my $save_subject = $subject;
       do {$subject =~ s/^\s*//} while($subject =~ s/^((Ref?g?:)|(Fwd?:))//i); 
 
    my @new_header=();
       
       $references and push @new_header, "References: $references";

       if($do_what =~ /r/i)
       {
          $to = ($do_what =~ /R/) ?  "$from $to $cc" : $from;

          push @new_header, "To: $to";
          push @new_header, "Subject: Re: $subject";
          push @new_header, "";
          push @new_header, "$from sent on $date:";
       }
       elsif($do_what =~ /f/)
       {
          push @new_header, "To: ";
          push @new_header, "Subject: Fwd: $subject";
          push @new_header, "";
          push @new_header, "____Original_Message____";
          push @new_header, "From: $from";
          push @new_header, "To: $to";
          push @new_header, "CC: $cc";
          push @new_header, "Date: $date";
          push @new_header, "Subject: $save_subject";
       }
       else
       {
          push @new_header, "To: $from";
          push @new_header, "Subject: Read: $save_subject";
          push @new_header, "";
          push @new_header, "The mail sent by you on $date was displayed";
          my $last = $main::curbuf->Count();
             $main::curbuf->Delete(1, $last); 
       }
       push @new_header, "";
 
       $main::curbuf->Append(0, @new_header);

       VIM::DoCommand('silent set filetype=mail');

       $rv = 1;
  }

  $rv or return 0;

  #--moved below to mark the one opened after delete --  if($from_idx or $have_other)
  #--moved below to mark the one opened after delete --  {
  #--moved below to mark the one opened after delete --     #here, if other is a hidden buffer, then in context finder: OK to have sb'ed to it and set have_other 
  #--moved below to mark the one opened after delete --     tms_reset_marks('[n|R]', $idx_file, $idx_line_number, $idx_line);
  #--moved below to mark the one opened after delete --  }
   
  my $flnm = 0;
  if($do_what =~ /[d|m]/)
  {
      if($from_idx or $have_other) # will have idx in open buffer
      {
         #here, if other is a hidden buffer, then in context finder: 
         # should be here even if user closed idx_file
         VIM::DoCommand("silent drop $idx_file"); 
         $main::curbuf->Delete($idx_line_number);
         VIM::DoCommand("silent update"); 

         if($have_other) # eml file in open buffer
         { {   
               # a block because of use of last inside it
               # In next call: buffer may NOT have idx_line_number!!!
               $idx_line = tms_get_content_of_line($idx_line_number); 
               # the next subroutine is safe for junk input
               $flnm     = tms_get_eml_from_idx_line($idx_line);

               $flnm or last; # go and bw the eml buffer

               $idx_file =~ /(.*)\bindex\.idx$/;
               $flnm     = $1 . $flnm;

               # next line has e! since may have edited file-to-be-deleted
               VIM::DoCommand("silent drop $eml_file|silent e! $flnm|silent! call Eml_open()");
               # this new guy -- flnm -- needs to be marked as read!
               # will happen below!!!
         } }
      }
      if($tms_ok_to_bw_in_perl)
      {
         VIM::DoCommand("silent! bw! $eml_file");
      }
      elsif($tms_ok_to_bun_in_perl)
      {
         VIM::DoCommand("silent! bun! $eml_file");
      }
  } 

  if($flnm or (($do_what !~ /[d|m]/) and ($from_idx or $have_other)))
  {
      tms_reset_marks('[n|R]', $idx_file, $idx_line_number, $idx_line);
  }
  
  if($unlink_this)
  { 
      #unlink $unlink_this;
      VIM::DoCommand('silent let foo = delete("'.$unlink_this.'")'); 
  }

  #VIM::DoCommand("redraw!");
  return 1;

}

# @context = tms_w_get_calling_eml_idx_context() # {{{3
#
#  This module determines the as much as possible about the calling 
#  context:  is the current buffer a .idx file or a .eml file?  is 
#  the other file in a window, in a hidden window or absent? the 
#  name of the .idx file, the .eml file, the .idx line number and
#  contents of the .idx line.
#
# dev notes {{{5
#                            eml_file will always be defined or nothing to do
# ($from_idx, $have_other) = undef  nothing to do
#                            (1, 0) called from idx file, eml buffer unknown
#                            (1, 1) called from idx file, eml buffer open
#                            (0, 1) called from eml file, with idx file in open buffer
#                            (0, 0) from eml file, with no idx or no idx in open buffer
# $have_other == 2                  other was in a hidden buffer that was sb'ed
# consider setting have_other to point to the other buffer instead of to 2
# 5}}}
#
#
sub tms_w_get_calling_eml_idx_context  # {{{4
{
  my $idx_file = tms_get_current_buffer();
  my $from_idx = 0;
     $idx_file =~ /\bindex.idx$/i and $from_idx = 1;

  my ($idx_line_number, $idx_line) = ();
  my ($eml_file, $flnm) = ();
  my $have_other = 0;
     if($from_idx)
     {
        $idx_line_number = tms_get_current_line_number();
        $idx_line        = tms_get_content_of_line($idx_line_number);
        $eml_file        = tms_get_eml_from_idx_line($idx_line);
        ($idx_file =~ m/(.*)\bindex\.idx/i) and $eml_file = $1 . $eml_file;
        #here, have idx file and know eml file name; but unknown if eml is have_other
        $have_other = 1 if(tms_is_in_window($eml_file));

        if(!$have_other)
        {
           my $foo = (VIM::Buffers("$eml_file"))[0]; 
           #2do:  ? $foo and sb to $eml_file?
           #2do:  ? set $have_other to $foo? =~/VIBUF/ /SCALAR/
           if($foo)
           {  
              VIM::DoCommand("silent sb $eml_file");
              $have_other = 2;
           }
        }
     }
     else
     {
        return () unless ($idx_file =~ /\w[\w ]*\.eml$/i);
        $eml_file = $idx_file;
        $idx_file =~ s/(\w[\w ]*\.eml)$/index.idx/i;
        $flnm     = $1;

        # here, have eml file, don't know about idx
        # 1) if idx is a buffer in a window, need to drop to it
        # 2) if idx is a buffer that is not a window, need to sb it
        # 3) success in either 1 or 2 will result in idx being have_other  
        # 4) if success as in 3, find line; reset have_other if line not found

        #$have_other is still 0 here
        $have_other = 3 if(tms_is_in_window($idx_file));

        if(!$have_other)
        {
           my $foo = (VIM::Buffers("$idx_file"))[0]; 
           if($foo)
           {  
              VIM::DoCommand("sb $idx_file");
              $have_other = 2;
           }
        }
        if($have_other) # may end up false at the end of this block
        {
           VIM::DoCommand("silent drop $idx_file");
           VIM::DoCommand("normal gg");
           VIM::DoCommand("/ $flnm\\s*\$");
           VIM::DoCommand("silent! nohls");
           $idx_line_number = tms_get_current_line_number();
           $idx_line        = tms_get_content_of_line($idx_line_number);
           $flnm            = tms_get_eml_from_idx_line($idx_line);
           $have_other = ($flnm =~ /\w[\w ]*\.eml/i) and ($eml_file =~ /\b$flnm$/);
        }
     }
     return ($from_idx, $have_other, $idx_file, $idx_line_number, $idx_line, $eml_file);
}

# tms_clean_get_full_path_from_vim($rel_path_file) # {{{3
# 
# Calls fnamemodify with the input and with the :p argument
# Changes all \ to /
# Changes multiple consecutive / to single /
# In on windows, lowercases everything
#
sub tms_clean_get_full_path_from_vim # {{{4
{
   my($file) = @_;
  
   my $foo  = "silent let b:tms_fooey = fnamemodify('$file', ':p')";
              VIM::DoCommand($foo); 
      $file = VIM::Eval('b:tms_fooey');

      $file =~ s,\\,/,g;
      $file =~ s,//+,/,g;
      $file =~ s,/\s*$,,g;
      ($^O =~ /mswin/i) and $file = lc $file;

   return $file;
}

# tms_is_in_window($name) # {{{3
#
# cycles through the list of windows to see if the 
# input name is in a window.
#
sub tms_is_in_window # {{{4
{
   my ($name) = @_;
   my $rv     = 0;

   my $fp_name = tms_clean_get_full_path_from_vim($name);

   my @wins=VIM::Windows(); 

   for my $i (0 .. $#wins) 
   {
      my $fp_foo = $wins[$i]->Buffer()->Name(); 
         $fp_foo = tms_clean_get_full_path_from_vim($fp_foo); 
      if($fp_foo eq $fp_name)
      {
         $rv = 1;
         last;
      }
   }
   return $rv;
}

# tms_reset_marks('[n|R]', $idx_file, $idx_line_number, $idx_line) # {{{3
#
# Takes the mark from the input line and modifies it with the input
# pattern (with the global flag).  Overwrites the input line number'th
# line in the buffer of the file with the modified line.  Drops to
# that buffer, writes it, and drops back to the current buffer.
#
sub tms_reset_marks # {{{4
{
  my ($which, $file, $line_n, $line) = @_; 

     $line =~ s/^([^\|]*)//;
  my $mark = $1;
     $mark =~ s/$which/ /g;
     $line = $mark . $line;

  my $buf  = (VIM::Buffers($file))[0]; 
     $buf and $buf->Set($line_n, $line);

     $file =~ s,\\,/,g;
     $file =~ s,//+,/,g;
     #-reply buf has no name----$file =~ m/^(.*)[\/](\w[\w .]*)$/;
     #-reply buf has no name----$mark = $1;
     #-reply buf has no name----$mark =~ s,\s*[/]*\s*$,,g;
     #-reply buf has no name----$line =~ m/\|\s*([^\|]+)\s*$/;
     #-reply buf has no name----$mark = $mark .'/'. $1;
     $mark = $main::curbuf->Name();

     VIM::DoCommand("silent drop $file|w|silent! drop $mark");

     return;
}


# tms_get_destination_dir() # {{{3
# 
# Interacts with the user to get a string that potentially
# is a directory.  Calls tms_fix_directory with the string
# and returns the returned value.
#
sub tms_get_destination_dir # {{{4
{
  my $where_to = tms_get_input("Enter the destination dir: ");
     $where_to = tms_fix_directory($where_to);
     
     return $where_to;
}


# tms_fix_directory() # {{{3
#
# Cleans up the input string (\ to /, remove consecutive /, 
# remove trailing /).  If result is not a directory then
# treates the string as a subdirectory of the mail home. 
# Tests final string to see if it is a directory.
# Returns directory or 0.
#
sub tms_fix_directory # {{{4
{
   my($dir) = @_;

   $dir =~ s,\\,/,g;
   $dir =~ s,//+,/,g;
   $dir =~ s/\/$//;

   if(!(-d $dir))
   {
     my $base = tms_get_dir_mail_home();
        $dir  =~ s/^\///;
        $dir  = $base . '/' . $dir;
   }
   $dir = 0 unless (-d $dir);
   return $dir;
}

# tms_copy_file($file, $dir) # {{{3
#
# Copies the file to the directory 
# Input file is full-path.  Extracts file-name (flnm).
# Calls tms_make_unique_name($dir, $flnm)
# to ensure nothing gets overwritten in the
# destination directory.
#
sub tms_copy_file # {{{4
{
use File::Copy;

   my($file, $dir) = @_;

      $file =~ /(\w[\w .]*)$/;
   my $flnm = $1; 
   
   my $dest_file = tms_make_unique_name($dir, $flnm);

   #  $file =~ s,\\,/,g;
   #  $dest_file =~ s,\\,/,g;
   #
   #  $file =~ s/^\s*//;
   #  $file =~ s/\s*$//;
   #  $dest_file =~ s/^\s*//;
   #  $dest_file =~ s/\s*$//;

   #$dest_file =~ s/\w[\w.]*$//;
   #$file =~ s,/,\\,g;
   #$dest_file =~ s,/,\\,g;
   #tms_echo('err', "file:$file,\ndest:$dest_file,\n");

   my $foo = '';
   if(1)
   {
      $foo  = "silent let b:tms_fooey = fnamemodify('$file', ':p')";
              VIM::DoCommand($foo); 
      $file = VIM::Eval('b:tms_fooey');
   }
   else
   {
      $foo  = "silent let s:fooey = fnamemodify('$file', ':p')";
              VIM::DoCommand($foo); 
      $file = VIM::Eval('s:fooey');
   }
   $file =~ s,\\,/,g;
   
   if(!copy($file, $dest_file))
   {  
      tms_echo('err', "Could not copy $file to $dest_file\n$!\n");
      return 0;
   }
   return $file;
}

# tms_make_unique_name($dir, $file) # {{{3
#
# Modifies $file (essentially by appending _n, n being 1, 2, ...)
# so that the there is no file with the resulting name in the
# directory $dir.
#
# NOTE:  resulting name will always have the .eml extension
#
sub tms_make_unique_name # {{{4
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


# tms_get_current_line_number() # {{{3
#
# what more can be said?
#
sub tms_get_current_line_number # {{{4
{
   my ($row, $col) = $main::curwin->Cursor();
   return $row; 
}

# tms_get_content_of_line($line_number) # {{{3
#
# what more can be said?
#
sub tms_get_content_of_line # {{{4
{
   my ($which) = @_;
   return  $main::curbuf->Get($which)
}

# tms_get_eml_from_idx_line() # {{{3
#
# Note:  verifies that input is meaningful
#        and returns false if it isn't
#
sub tms_get_eml_from_idx_line # {{{4
{
   my ($line) = @_;
   my $rv = '';
   $line and ($line =~ m/^([^|]*)((\|\s*)|(\|.*\|\s*))(\w[\w ]*\.eml)\s*$/) and $rv = $5;
   #---$line =~ m/^([^|]*)((\|\s*)|(\|.*\|\s*))(\w[\w ]*\.eml)\s*$/;
   #---return $5;
   return $rv;
}

# tms_get_current_buffer() # {{{3
#
# what more can be said?
#
sub tms_get_current_buffer # {{{4
{
    return $main::curbuf->Name();
}




tms_debug("                   6 Done compiling working\n");
EOWorking


" mainly viml {{{1
"help user-functions

" s:TMSCalledFromVim(...)  "{{{3
"
" All this function does is to transfer the number 
" of its arguments and its arguments to the 
" perl subroutine tms_via_vim() -- after making 
" any \ in the arguments into /. 
"
" This function is to be called via any of the four 
" commands created below (after its endfunction line).
"
function! s:TMSCalledFromVim(...)  "{{{4

  let s:myarg = '"' . a:0 . '"' 
  let idx = 1
  while idx <= a:0
      let s:myarg = s:myarg . ', "' . a:{idx} . '"'
      let idx = idx + 1
  endwhile
  let s:myarg = substitute(s:myarg, '\', '/', 'g')
  let s:myarg = substitute(s:myarg, '/\s*"', '"', 'g')
  let s:myarg = substitute(s:myarg, '\s*"\s*', '"', 'g')

  exec "perl tms_via_vim " . s:myarg    

endfunction

"help user-commands    
" TMSxxx commands "{{{3
"
command! -nargs=* -complete=dir  TMSMakeIndex  call s:TMSCalledFromVim('index', <f-args>) 
command! -nargs=* -complete=dir  TMSShowIndex  call s:TMSCalledFromVim('show', <f-args>) 
command! -nargs=* -complete=file TMSSendMail   call s:TMSCalledFromVim('send',  <f-args>) 
command! -nargs=*                TMSGetMail    call s:TMSCalledFromVim('get',   <f-args>) 
command! -nargs=1 -range         TMSIndexBlock call s:TMSCalledFromVim(<q-args>, <line1>, <line2>)


"Via Vim {{{2
"
perl << EOViavim
##!/usr/bin/perl  #{{{4 
#BEGIN {(*STDERR = *STDOUT) || die;}  
#line 2509
use diagnostics;
use warnings;
use strict;
#use CGI qw(:standard);
#use LWP::Simple;
#use Net::SMTP;

tms_debug("Compiling via vim..."); #{{{3 

# tms_via_vim($num_following, $what, @the_args) # {{{3
#
# Gets called from the viml function: s:TMSCalledFromVim(...)
# which in turn gets called from the commands TMSxxx
#
# It passes on the arguments to the perl subroutine 
# corresponding to its $what argument.  The arguments are
# examined and/or adjusted before doing the call.
#
sub tms_via_vim # {{{4
{
  my ($num_following, $what, @the_args) = @_;

  if($what eq 'index')
  {
     for (0 .. $#the_args){$the_args[$_] = tms_fix_directory($the_args[$_])}
     tms_make_index(@the_args);
  }

  if($what eq 'show')
  {
     for (0 .. $#the_args){$the_args[$_] = tms_fix_directory($the_args[$_])}
     VIM::DoCommand("sf $_/index.idx") for (@the_args);
  }

  if($what eq 'send')
  {
     @the_args and tms_send_mail_files(@the_args)
               or  tms_send_mail_buffer(@the_args);
  }

  if($what eq 'get')
  {
     tms_get_mail(@the_args);
  }

  if($what =~ /[DMC]/)
  {
     tms_w_idx_block_dmc($what, @the_args) 
  }
  if($what =~ /F/)
  {
     #" forward block from idx 
     #map <buffer>  <LocalLeader>F  :TMSIndexBlock F<CR>
  }
}

# tms_w_idx_block($do_what, $line1, $line2) # {{{3
#
# Given a block of .idx lines -- in the current 
# buffer -- deletes, moves or copies the .eml files 
# associated with those lines.  And in the case of 
# a delete or a move, the lines are then removed
# from the .idx file (deleted from buffer and the 
# buffer is updated).
#
sub tms_w_idx_block_dmc # {{{4
{
  my($do_what, $line1, $line2) = @_;

  my $dir = $main::curbuf->Name();
     $dir =~ s,\\,/,g;
     $dir =~ s/\w[\w. ]*\.idx$//; # keeps its slash (/) unless it is dot-dir

  my $where_to = ($do_what  =~ /D/) ? tms_get_dir_trash() : tms_get_destination_dir();
     $where_to or return;

  for ($line1 .. $line2)
  {
      my $file = tms_get_content_of_line($_);
         $file = tms_get_eml_from_idx_line($file);
         $file = $dir . $file;

     my  $rv = tms_copy_file($file, $where_to);
         #rv is full path version of $eml_file
         ($do_what =~ /[DM]/) and $rv and unlink $rv; 
         # above and elsewhere, checking for =[DM] rather than ![C]
         # is safer and allows this subroutine to be called with 
         # do_what being something other than [DMC] (such as F) -- even 
         # though its name currently ends with dmc!
  }
  ($do_what =~ /[DM]/) and VIM::DoCommand("silent $line1,$line2"."delete|update");
}

tms_debug("                   7 Done compiling via vim\n");

EOViavim

" appendix {{{1

if (g:tms_do_not_bw_in_perl)

function! TMS_bw_extension(ext)

   let s:last_buffer = bufnr("$")
   let s:idx = 1

   while s:idx <= s:last_buffer
     
       let s:flnm = bufname(s:idx)
       if(s:flnm =~ '\.'.a:ext.'$')
           execute 'silent! bw! ' . s:idx
       endif
       let s:idx = s:idx + 1

   endwhile

endfunction

function! s:TMS_bw_crud()

  "call TMS_bw_extension('\(eml\|idx\)')
  call TMS_bw_extension('eml')
  call TMS_bw_extension('idx')

endfunction
command! -nargs=0 TMSBwCrud  call s:TMS_bw_crud()

endif


" Source the vimfiles/mail/tms.vim file which has 
" mappings to call various subroutines defined here.
"
" let s:foo = expand($VIM . '/vimfiles/mail/tms.vim')
"
ru mail/tms.vim

let g:loaded_tms = 1
"
"restore saved cpo     {{{2
let &cpo = s:save_cpo

"<SID> any functions?


if !exists("tms_debug")
   finish
endif
if (g:tms_debug == 0)
   finish
endif

if exists("tms_done_warner")
   finish
endif
let g:tms_done_warner=1

perl << EOMessage
use diagnostics;
use warnings;
use strict;     
#sub warner($);
$SIG{__WARN__} = \&warner; 
$SIG{INT}      = \&warner; 
$SIG{QUIT}     = \&warner; 
$SIG{ALRM}     = \&warner; 
$SIG{__DIE__}  = \&warner; 
#$SIG{__DIE__} = DEFAULT;

sub warner
{
   my $sig = shift(@_);
   VIM::Msg("\nline:$.> From Warner:  " . $sig);
}
EOMessage

finish  "{{{1

"EOF

