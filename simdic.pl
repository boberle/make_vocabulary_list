#!/usr/bin/perl
use strict;
use warnings FATAL=>'all';
use utf8;
use File::Basename;
use Unicode::Normalize;
#use Data::Dumper;

BEGIN {
   unshift @INC, ".";
}

use Common;

$0 = 'simdic';
my $VERSION = '2014-08-13, modified 2020-02-29';

########################################################################
# THOUGHTS ABOUT UNICODE (FOR GREEK)
#
# The big issue is unicode, as always. The goal is to convert all the
# strings (from the input file and from the dictionary file) in the
# same form. To do that, use:
#  - "use Unicode::Normalize;"
#  - $foo = NFD($foo) # Normalization Form D (formed by canonical
#    decomposition)
#  OR:
#  - $foo = NFC($foo) # Normalization Form C (formed by canonical
#    decomposition followed by canonical composition)
# In the beginning, try NFC, if it doesn't work, try NFD.
# See: http://perldoc.perl.org/Unicode/Normalize.html.
#
# NOTE: If you change NFC for NFD, you will need to change the regex
# code for contracted verb (in get_pp_from_bailly).
########################################################################


########################################################################
# GLOBAL VARIABLES

# mode:
#  - 1 = exact (diacritics, punctuation, number, etc.)
#  - 2 = bare (no diacritics, punctuation, number, etc.)
#  - 3 = both
my $MODE = 1;

# if not FALSE, write html code in this file (otherwise, print
# the non-html voc list on stout)
my $HTML_FILE = '';

# padding for head word
my $PADDING = '30';

# dictionary to search in
my $DIC = '';

my $SCRIPT_DIR = dirname(__FILE__);

########################################################################




########################################################################
# HTML FILE TEMPLATE
########################################################################

my $HTML_PAGE_TEMPLATE = << "END";
<!-- voc list
#VOCLIST
-->
<html>

   <head>
      <title>vocabulary</title>
      <meta http-equiv="Content-Type" content="text/html; charset=utf-8">

      <style>
         h1 {
            font-family: "IFAO-Grec Unicode";
            font-weight: bold;
            font-size: 20pt;
         }
         p {
            font-family: "IFAO-Grec Unicode";
            font-size: 16pt;
         }
         a.title:link, a.title:visited, a.title:hover, a.title:active {
            font-weight: bold;
            font-size: 18pt;
            color: #9F000F;
            text-decoration: none;
         }
         /* used to keep the ckeckbox with the label */
         span.nobreak {
            white-space:nowrap;
         }
         span.titleNoEntry {
            font-weight: normal;
            font-size: 18pt;
            color: black;
            text-decoration: none;
         }
         html {
            overflow-y: scroll;
         }
      </style>

   </head>

   <body>
      <script>

         function hideAll() {
            var all = document.getElementsByTagName("div");
            for (var i=0, max=all.length; i < max; i++) {
               all[i].style.display = 'none';
            }
         }

         // function to be called by the onclick event handler of the
         // links
         function showEntry(number) {
            hideAll();
            // entry
            var e = document.getElementById(number)
            if (e.style.display == 'none') {
               e.style.display = 'block';
            } else {
               e.style.display = 'none';
            }
            // check box
            var c = document.getElementById("check"+number)
            c.checked = true;
            changeLinkColor(number);
         }

         // function to be called by the onchange event handler
         // of checkboxes
         function changeLinkColor (number) {
            var c = document.getElementById("check"+number)
            var e = document.getElementById("link"+number)
            if (c.checked == true) {
               e.style.color = '#347235';
            } else {
               e.style.color = '#9F000F';
            }
         }

      </script>

      <h1>Vocabulary</h1>

      <p>#HEADINGS</p>

      #DIVS

      <script>
         hideAll();
      </script>

   </body>

</html>
END


########################################################################
# Get the command line parameters.
########################################################################

my $HELP = <<"END";
USAGE:
  $0 [OPTIONS] [TYPE]

DESCRIPTION:
  This script look for some words (read on STDIN one word or phrase
  per line) in the specified dictionary, and return the meanings,
  arranged in a preformatted vocabulary list.

  The list is written in plain text, with the meanings, on STDOUT, unless
  the --html option is set with a file name: in this case, the list is a
  (complicated) html file.  A blank list appear at the beginning of the
  file.
  
  The format of the dictionary file is as follows:
     - One entry per line: SEARCH_WORD TAB DISPLAY_WORD TAB MEANING.
     - There may be several entry for a SEARCH_WORD, with or without
       the same DISPLAY_WORD.
     - Comments (#) and white lines are ignored.

OPTIONS:
  -h --help   Print this.
  -d          The dictionary.  Use -l to get the list.  Default is bailly.
  -m VALUE    How to match the input against the SEARCH_WORD. By default,
              they are matched as is, i.e. with all diacritics,
              punctuation, etc. (VALUE = 1, by default).  With VALUE = 2
              all diacritics, punctuation and even spaces or numbers
              are removed.  With VALUE = 3, the script tries an exact
              math, then a bare match.
  -p VALUE    Padding.
  --html FILE File into which write the html code.  If not present, a
              vocabulary list is written on STDOUT.  A blank vocabulary
              list is written at the beginning of the file.

Version: $VERSION
END


sub get_cl_parameters {

   my $return_value = 1;

   # default
   $DIC = '';
   $PADDING = '40';
   $MODE = '1';
   $HTML_FILE = '';

   my %argv = Common::get_argv(
      # params with values
      [ qw/html m d p/ ],
      # params without values
      [ qw// ],
      # required params
      [ qw// ],
      # associations
      { m => \$MODE,
        p => sub {
          die "$0: *** wrong value: $_[1] ***\n" unless $_[1] =~ m/\d++/;
          $PADDING = $_[1];
        },
        d => sub { $DIC = $_[1] },
        html => \$HTML_FILE,
      },
      # help text
      $HELP,
      # long help text
      undef,
      # number of parameters (not options) allowed
      [ qw/0/ ]
   ); 

   if (not $DIC) {
      die "$0: no dictionnary selected!";
   }

   return $return_value;

}


########################################################################
# Remove all diacritics, and all non-letters, including number!.
########################################################################

sub simplify_string {

   my $text = shift;

   $text = lc($text);
   $text = remove_diacritics($text);
   $text =~ s/\P{L}++//g;

   return $text;
   
}



########################################################################
# Read the given dictionary file (the format is described in the help
# text) and return the corresponding hash, whose format is:
#   SEARCH_WORD => {
#                    DISPLAY_WORD_1 => [ MEANING_1, MEANING_2, ... ],
#                    DISPLAY_WORD_2 => [ MEANING_1, MEANING_2, ... ],
#                    ...
#                  },
#   ...
########################################################################


sub read_dic_file {

   my $file = shift;
   my $bare = shift || '';

   my %data = ();

   open my $fh, $file or die "$0: *** can't open $file ***\n";

   while (<$fh>) {

      next if m/^\s*+(?:#.*+)?$/;

      chomp;

      if (m/^\s*+([^\t]++)\s*?\t\s*?([^\t]++)\s*?\t\s*?(.*?)\s*+$/) {

         my $search = NFC($1);
         my $display = $2;
         my $meaning = $3 || "no definition available";

         if ($bare) {
            $search = simplify_string($search);
         }

         if (exists $data{$search}) {
            if (exists $data{$search}->{$display}) {
               push @{$data{$search}->{$display}}, $meaning;
            } else {
               $data{$search}->{$display} = [ $meaning ];
            }
         } else {
            $data{$search} = { $display => [ $meaning ] };
         }

      } else {

         die "$0: *** ill-formed line: '$_' ***\n";

      }

   } # while

   close $fh or die "$0: *** can't close $file ***\n";

   return %data;

}



########################################################################
# The argument to be given is the hash corresponding to a SEARCH_WORD
# in the description of the read_dic_file() function.
#
# So, for example:
#   {
#     DISPLAY_WORD_1 => [ MEANING_1, MEANING_2, ... ],
#     DISPLAY_WORD_2 => [ MEANING_1, MEANING_2, ... ],
#     ...
#   },
#
# Return a formatted entry for a voc list.
#
# If the argument is not a reference, but a scalar, assumed that this
# scalar is the word, and that it has not been found.  The value
# returned is an entry with ?????? in place of the meaning.
########################################################################


sub format_voclist_entry {

   my $data = shift;

   # $data is not a ref, then assumed the word has not been found,
   # and $data contains the missing word...

   unless (ref $data) {
      return sprintf("%-$PADDING"."s::?????????????\n", "$data");
   }

   # for each 'display word'...

   my $result = '';

   while (my ($display_word, $r_meanings) = each %{$data}) {

      # ... display each meaning

      # first split each meaning by "\\n" (=> called "sections")
      my @sections = map{split(/(?:\\n
                                  |\s*+-\s++\d++\s++-\s*+
                                  |\s*+-\s++[a-z]\s++-\s*+)
                               /x, $_)}
         @$r_meanings;

      # then print
      my $first_round_passed = '';
      for my $section (@sections) {
         $section =~ s/^\s++//;
         $section =~ s/\s++$//;
         $section =~ s/\s*+\.$//;
         next if $section =~ m/^\s*+$/;
         $result .= sprintf("%-$PADDING"."s%s\n",
            ($first_round_passed ? "" : $display_word),
            "\::$section");
         $first_round_passed = 1;
      }

   } # while

   return $result;

}

########################################################################
# Same as format_voclist_entry(), but for html.  Return three strings:
#  - html code for the list of headings
#  - the divs with the meaning
#  - the empty vocab list
########################################################################

my $HTML_DIV_COUNTER = 1;

sub format_html_entry {

   my $data = shift;

   my $headings = '';
   my $divs = '';
   my $voclist = '';

   my $template_title = # vars = cntr, cntr, cntr, cntr, display_word
      '<span class="nobreak">'
         .'<input id="check%d" type="checkbox" '
            .'onchange="changeLinkColor(\'%d\');"/>&nbsp;'
         .'<a id="link%d" class="title" href="#" '
            .'onclick="showEntry(\'%d\');">%s</a>'
      .' ―</span> '."\n";

   my $template_title_no_entry = # vars = display_word
      ' <span class="nobreak">'
         .'<span class="titleNoEntry">%s</span>'
      .' ―</span> '."\n";

   my $template_entry = # vars = counter, display_word, entry
      '<div id="%d"><p><b>%s</b><br/>%s</p></div>'."\n";


   # $data is not a ref, then assumed the word has not been found,
   # and $data contains the missing word...

   unless (ref $data) {
      return
         sprintf($template_title_no_entry, $data),
         '',
         sprintf("%-$PADDING"."s::?????????????\n", $data);
   }

   # for each 'display word'...

   while (my ($display_word, $r_meanings) = each %{$data}) {

      # ... display each meaning

      my $first_round_passed = '';

      for my $meaning (@$r_meanings) {

         unless ($first_round_passed) {
            $voclist .= sprintf("%-$PADDING"."s\n", "$display_word\::");
         }

         $display_word =~ s{ }{&nbsp;}g;
         $meaning =~ s{\\n}{\n}g; 
         $meaning =~ s{^\n++}{}g; 
         $meaning =~ s{\n++$}{}g; 
         $meaning =~ s{^(\t++)}{'&nbsp;'x(length($1)*5)}mge; 
         $meaning =~ s{^( ++)}{'&nbsp;'x(length($1))}mge; 
         $meaning =~ s{\n}{<br/>}g; 

         $headings .= sprintf($template_title,
            $HTML_DIV_COUNTER, $HTML_DIV_COUNTER, $HTML_DIV_COUNTER,
            $HTML_DIV_COUNTER, $display_word);
         $divs .= sprintf($template_entry, $HTML_DIV_COUNTER,
            $display_word, $meaning);

         $first_round_passed = 1;
         $HTML_DIV_COUNTER++;

      } # for

   } # while

   return ($headings, $divs, $voclist);


}


########################################################################
# main()
########################################################################

sub main {

   return unless get_cl_parameters();

   # load the dictionaries

   my %full = ($MODE eq '1' or $MODE eq '3') ? read_dic_file($DIC, 0) : ();
   my %bare = ($MODE eq '2' or $MODE eq '3') ? read_dic_file($DIC, 1) : ();

   # load the list of words to be searched

   my @words = ();
   while (<STDIN>) {
      next if m/^\s*+(?:#.*+)?$/;
      chomp;
      s/^\s++//g;
      s/\s++$//g;
      push @words, NFC($_);
   }

   # for each word, search the word in the dictionaries

   my $html_headings = '';
   my $html_divs = '';
   my $voclist = '';

   for my $word (@words) {

      my $bare_word = %bare ? simplify_string($word) : '';

      # select the data, ie the argument to be sent to the subroutine

      my $data = '';
      if (%full and exists $full{$word}) {
         $data = $full{$word};
      } elsif (%bare and exists $bare{$bare_word}) {
         $data = $bare{$bare_word};
      } else {
         $data = $word;
      }

      # call the correct subroutine for simple voclist or html:

      if ($HTML_FILE) {
         my ($heading, $div, $voc) = format_html_entry($data);
         $html_headings .= $heading;
         $html_divs .= $div;
         $voclist .= $voc;
      } else {
         $voclist .= format_voclist_entry($data);
      }
         
   } # for

   # write or print for simple voclist or html:

   if ($HTML_FILE) {
      my $code = $HTML_PAGE_TEMPLATE;
      $code =~ s/#HEADINGS/$html_headings/;
      $code =~ s/#DIVS/$html_divs/;
      $code =~ s/#VOCLIST/$voclist/;
      write_file($HTML_FILE, $code);
   } else {
      #print '='x78, "\n";
      print $voclist;
      #print '='x78, "\n";
   }

}


########################################################################
# Write a file, die on error.
########################################################################

sub write_file {

   my $file = shift;
   my $content = shift;

   open my $fh, ">", $file or die "$0: *** can't open $file ***\n";
   print $fh $content;
   close $fh or die "$0: *** can't close $file ***\n";
   
}


########################################################################
# Remove the diacritics of a text.
#
# What is a diacritic for Unicode.  Well, I don't know with certainty,
# because Unicode is Hell, as everyone knows, but I will use the
# \p{NonSpacingMake}.  According to what one find on Internet, "a
# non-spacing mark always combines with the character that precedes
# it" (http://my.safaribooksonline.com), so I'm pretty sure that
# covers the diacritics.  Some other sites also cite this category to
# remove all the diacritics.
#
# Note that these characters sometimes respond to \b... in the middle
# of a word!  Before searching anything, it's thus safer to remove all
# the diacritics, hence this function.
########################################################################

sub remove_diacritics {

   my $text = shift;

   $text = NFD($text);
   $text =~ s/\p{NonspacingMark}//g;

   return $text;

}


main();
