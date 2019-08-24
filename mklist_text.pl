#!/usr/bin/perl
use strict;
use warnings FATAL => 'all';
use Data::Dumper;

use Unicode::Normalize;

BEGIN {
   unshift @INC, '.';
}

#use BetaCode::Converter;
use Common;


########################################################################
# WAS IST DAS?
#
# This script reads an $INPUT_FILE, or, if specified, the file given
# as CLI parameters, formatted as described below, which
# is vocabulary list, and formats it to produce a nice latex file that
# you can trash, eat or even compile with lualatex.
########################################################################

########################################################################
# GLOBAL VARIABLES
########################################################################

# input file
my $DEFAULT_INPUT_FILE = 'input';

# output file (NOTE: not used, calculated from the title)
#my $OUTPUT_FILE = 'output.tex';

# the data array, the format is as follows:
#  [ question_a, answer_1, answer_2, answer_3, ...],
#  [ question_b, answer_1, answer_2, answer_3, ...],
#  ...
my @DATA = ();

# the template latex file
my $LATEX_CODE = <<"END";
\\documentclass[a5paper,12pt]{article}

% PAGE LAYOUT

%\\usepackage[a5paper,portrait,margin=1cm,includefoot]{geometry} 
\\usepackage[a5paper,portrait,top=1cm,total={13cm,18cm}]{geometry} 

% FORMAT OF THE TITLE

\\makeatletter
\\renewcommand{\\\@maketitle}{
\\newpage
%\\null
\\vskip 0em%
\\begin{center}%
   {\\LARGE \\\@title \\par}%
\\end{center}%
\\par}
\\makeatother

% NEW FOOTERS

% change the footer

\\usepackage{lastpage}

\\makeatletter
\\renewcommand*{\\\@oddfoot}{%
    #SHORTTITLE\\hfill\\thepage{}#LASTPAGECOMMENT of \\pageref{LastPage}%
 }
 \\renewcommand*{\\\@evenfoot}{\\\@oddfoot}
\\makeatother


% TABLES

%\\usepackage{longtable}
%\\usepackage{array}
%%\\usepackage{multirow} % multirow has some vert align problem...
%\\renewcommand{\\arraystretch}{1.5}


% FONTS

\\usepackage{fontspec}
\\defaultfontfeatures{Ligatures=TeX}
\\setmainfont{Gentium}

\\newfontfamily\\myIpaFont{Doulos SIL}
\\newcommand{\\myIpaText}[1]{{\\myIpaFont{}#1}}

\\newfontfamily\\myGreekFont{IFAO-Grec Unicode}
\\newcommand{\\myGreekText}[1]{{\\myGreekFont{}#1}}


% OTHER COMMANDS

\\newcommand{\\q}[1]{{``#1''}}


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

\\begin{document}

\\title{#TITLE}
\\maketitle

\\thispagestyle{empty}

%\\noindent
%\\begin{longtable}{>{\\raggedright\\arraybackslash\\large}m{5.5cm} | %
%   >{\\raggedright\\arraybackslash}m{6.5cm} %
%   \@{\\hspace{\\tabcolsep}}>{\\rule{0cm}{0.7cm}\\arraybackslash}%
%      m{0cm}\@{}}
%#<USE THIS FOR THE TABULAR VERSION>LATEXCODE
%\\end{longtable}

#LATEXCODE

\\end{document}
END


########################################################################
# Check if the array given (question, answer1, answer2, ...) is already 
# in @DATA.
########################################################################

#sub exists_in_data {
#
#   my $r_array = shift;
#
#   for my $r_data (@DATA) {
#      return '' unless scalar @$r_data == scalar @$r_array;
#      for my $i (1..scalar @$r_data) {
#         return '' unless $r_data->[$i] eq $r_array->[$i];
#      }
#   }
#
#   return 1;
#
#}


########################################################################
# Parse the given content and return (TITLE, SHORT_TITLE,
# SHOW_PAGE_TOTAL).  Fill @DATA.
#
# The format of the content (the file):
#  - a voc line is as follows: "l1 word:: l2 word"
#  - if there is no double-colon, then the line is considered as a
#    second/third/etc definition of the preceding word
#  - same if there is nothing (but spaces) before the double colon
#  - note that the betacode may be between [[...]], or between
#    /no_space/: in the last case, the language code 'p' is added to
#    the string.
#  - comments: white line and #.
# 
# There are some directives:
#  - #title:TITLE || SHORT TITLE FOR FOOTER (or TITLE is used)
#    (this directive is mandatory)
#  - #section:SECTION (this include a section)
#  - #subsection:SUBSECTION (guess what it does...)
#  - #showpagetotal:TRUE|FALSE (include the total of pages)
#  - #default:BETACODE_LANG_CODE
#  - #type:TYPE
#      Types define how to consider questions:
#        - greekfont: questions are all greek, and \MyGreekText{...}
#          is supplied automatically
#
# Because questions and answers are converted as soon as there are
# read, you can change the default language or even the type over the
# vocabulary list.
#
# Here is an example:
#       #title:this is the title||short title
#       one /wʌn/::  eins
#       two::        zwei, duo
#       t(h)ree::    drei, tres
#                    Baum
#                    ::oder Baum
#       four::       vier
#       #default:G
#       [[pe/nte]]:: fünf
#       #type:greekfont
#       ἕξ::         sex
#       #type:NULL
#       seven::      sieben
#
# Duplicated questions are allowed, but the answer is written only
# once.
########################################################################

sub read_data {

   my $content = shift;

   print "$0: Analysing the data...\n";

   my $type = '';
   my $title = '';
   my $short_title = '';
   my $show_page_total = 1;
   #my $suppress_duplicates = '';

   for (split /\n/, $content) {

      # the title and short title
      if (m/^\s*+#title:\s*+(.+?)\s*+(?:\|\|\s*(.++)\s*+)?$/) {

         $title = $1;
         $short_title = $2 || $1;

      # section or subsection
      } elsif (m/^\s*+(#(?:sub)?section):\s*+(.+?)\s*+$/) {

         push @DATA, [ $1, $2 ];  # including the #!!!

      # show last page number
      } elsif (m/^\s*+#showpagetotal:\s*+(TRUE|FALSE)\s*+$/) {

         $show_page_total = ($1 eq 'TRUE');

      # allow duplicates
      #} elsif (m/^\s*+#suppressduplicates:\s*+(TRUE|FALSE)\s*+$/) {

         #$suppress_duplicates = ($1 eq 'TRUE');

      # type of document
      } elsif (m/^\s*+#type:\s*+([a-zA-Z]++)\s*+$/) {

         $type = $1;

      # default language for betacode
      } elsif (m/^\s*+#default:\s*+([a-zA-Z]++)\s*+$/) {

         #$BetaCode::Converter::DEFAULT_LANG = $1;

      # comment
      } elsif (m/^\s*+(?:#.*+)?$/) {

         next;

      # l1 word:: l2 word
      } elsif (m/^\s*+(.+?)\s*+::\s*+(.+?)\s*+$/) {

         my ($q, $a) = ($1, $2);

         # format according to the type of document
         if ($type eq 'greekfont') {
            $q = "\\myGreekText{$q}";
         }

         # format the string
         $q = format_string($q);
         $a = format_string($a);

         push @DATA, [ $q, $a ];

      # l2 (new entry for the same word)
      } elsif (m/^\s*+(?:::)?\s*+(.+?)\s*+$/) {

         # if no $last_question, die!
         die "$0: *** nothing in \@DATA yet for line: '$_' ***\n"
            unless scalar @DATA;

         my $a = format_string($1);
         push @{$DATA[-1]}, $a;

      }

   }

   die "$0: *** no title ***\n" unless $title;

   return $title, $short_title, $show_page_total;

}


########################################################################
# print the $latex_code with the given argument into the given file.
########################################################################

sub print_latex_code {

   my $latex_code = shift;
   my $title = shift;
   my $short_title = shift;
   my $show_page_total = shift;
   my $file = shift;

   print "$0: Building and writing latex code into $file\n";

   my %handlers = (
      TITLE => sub { $title; },
      LATEXCODE => sub { $latex_code; },
      SHORTTITLE => sub { $short_title; },
      LASTPAGECOMMENT => sub { $show_page_total ? '' : '%'; },
   );

   my $result = $LATEX_CODE;

   $result =~ s/#([a-zA-Z]++)/
      exists $handlers{$1} ? $handlers{$1}->() :
      die "$0: *** can't find handler '$1' ***\n"/eg;

   write_file($file, $result);

}


########################################################################
# Ask the user if he wants to compile, and compile.  Then show the
# pdf, and remove the file if it is not good.
########################################################################

sub post_process {

   my $file = shift;

   my $cmd = "latexmk -lualatex $file";
   (my $pdf = $file) =~ s/\.tex/.pdf/;

   # latex compilation

   if (Common::confirm_yn("$0: Do you want to COMPILE ($cmd) [Y/n]? ", 1)) {
      Common::run_system_cmd($cmd);
      Common::run_system_cmd("latexmk -c");
   }

   print "$0: Compilation done.\n";

   # pdf viewer

   # if (Common::confirm_yn(
   #          "$0: Do you want to SHOW the pdf file '$pdf' [Y/n]? ", 1)) {
   #    Common::run_system_cmd("evince $pdf &>/dev/null &");
   # }

   # print "$0: Opening of viewer done.\n";

   # # delete the file if requested

   # if (Common::confirm_yn(
   #          "$0: Do you want to REMOVE the files '$file' and '$pdf' "
   #          ."[y/N]? ", 0)) {
   #    unlink $pdf or die "$0: *** $1 ***\n";
   #    unlink $file or die "$0: *** $1 ***\n";
   #    print "$0: Deletion of\n   - $pdf\n   - $file\ndone.\n";
   # }


}




########################################################################
# Format the given string and return it.
########################################################################

sub format_string {

   my $text = shift;

   # beta code (+ phonetics /.../ -> lang = p)
   #$text =~ s/\[\[ (.+?) \]\]/BetaCode::Converter::convert($1)/gex;
   #$text =~ s{ / (\S+?) / }{BetaCode::Converter::convert("p:$1")}gex;

   # some quick shortcuts
   $text =~ s/\.\.\./\\ldots/g;
   $text =~ s/-->/\$\\rightarrow\$/g;
   $text =~ s/(<|>)/\$$1\$/g;
   $text =~ s/\+/\$+\$/g;
   $text =~ s/==/\$=\$/g;
   $text =~ s/’/'/g;
   
   return $text;

}


########################################################################
# Read the file and, if there is several section separated by a title,
# ask the user what to print.  Return the raw text to be
# analysed.
########################################################################

sub get_file_content {

   my $file = shift;

   print "$0: Reading file $file...\n";

   my $content = read_file($file);

   my @sections = split /(?:\n++|^)#title:\s*+/s, $content;
   shift @sections;

   die "$0: *** no section found in file ***\n" unless scalar @sections;

   return "#title:$sections[0]" if scalar @sections == 1;

   print "Which section do you want to print?\n";

   my $i = 1;
   for my $section (@sections) {
      if ($section =~ m/^(.+?) *+\n/) {
         printf "   - %03d: %s\n", $i, $1;
      } else {
         printf "   - %03d: (no title)\n", $i;
      }
      $i++;
   }

   while (1) {
      print "You answer (q to quit): ";
      my $buf = <STDIN>;
      chomp $buf;
      if ($buf =~ m/^\s*+(\d++)\s*+$/
            and $1 >= 1 and $1 <= scalar @sections) {
         return "#title:$sections[$1-1]";
      } elsif ($buf =~ m/^\s*+q\s*+$/) {
         die "$0: *** aborted by user ***\n";
      } else {
         print "+++ ill-formed answer +++\n";
      }
   }

}

########################################################################
# main()
########################################################################

sub main {

   # read the data

   my $input_file = $ARGV[0] || $DEFAULT_INPUT_FILE;

   my $file_content = get_file_content($input_file);

   my ($title, $short_title, $show_page_total)
      = read_data($file_content);

   #print Dumper \@DATA;
   #die;

   # make the latex code

   print "$0: Creating the latex code...\n";

   my $latex_code = '';

   for my $r_data (@DATA) {

      my $question = $r_data->[0];
      my @answers = (@$r_data)[1..(scalar @$r_data-1)];

      if ($question eq '#section') {

         $latex_code .= sprintf("\n\\section*\{%s\}\n\n", $answers[0]);

      } elsif ($question eq '#subsection') {

         $latex_code .= sprintf("\n\\subsection*\{%s\}\n\n", $answers[0]);

      } else {

         my $i = 1;
         for my $answer (@answers) {
            $latex_code .=
               sprintf("%s\\noindent %s\\hfill %s\\par\\vspace%s{0.1cm}\n",
               $i == 1 ? '' : '\\nopagebreak[4]',
               $i == 1 ? $question : '',
               $answer,
               ($i < scalar @answers) ? '*' : '' # because of \nopagebreak
               );
            $i++;
         } # for l2

      }

   } # for l1

   # make and print the whole latex file

   my $output_file = remove_diacritics($title);
   $output_file =~ s/\\\w++{([^}]*+)}/$1/g;
   $output_file =~ s/[^-a-zA-Zα-ωΑ-Ω0-9]++/_/g;
   $output_file =~ s/-++/-/g;
   $output_file =~ s/^_++//g;
   $output_file =~ s/_++$//g;
   $output_file = lc $output_file;
   $output_file = "$output_file.tex";
   #die "name: $output_file\n";

   print_latex_code($latex_code, $title, $short_title, $show_page_total,
      $output_file);

   post_process($output_file);

}

########################################################################
# Read a file and return its content.  Die on error
########################################################################

sub read_file {

   my $file = shift;

   open my $fh, $file or die "$0: *** can't open $file ***\n";

   local $/ = undef;

   my $content = <$fh>;

   close $fh or die "$0: *** can't close $file ***\n";

   return $content;

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
print "$0: done!\n";

