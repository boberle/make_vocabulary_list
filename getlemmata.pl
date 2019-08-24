#!/usr/bin/perl
use strict;
use warnings;
use utf8;
use open ':utf8';
use Unicode::Normalize;
use LWP::Simple;

use Data::Dumper;



BEGIN {
   unshift @INC, '.';
}

use Common;

$0 = 'getlemmata';
my $VERSION = '2014-09-13';


########################################################################
# GLOBAL VARIABLES

# input and output file
my $SOURCE_FILE = '';
my $OUTPUT_FILE = '';
my $WORDS = '';

# url to retrieve the lemmata (%s = utf8 words)
my $URL_PERSEUS_GREEK = "http://www.perseus.tufts.edu/hopper/morph?l=%s&la=greek";
my $URL_PERSEUS_LATIN = "http://www.perseus.tufts.edu/hopper/morph?l=%s&la=la";

# if true, don't search on perseus
my $DRY_RUN = 0;

# if true, write the retrieved perseus web pages
my $WRITE_WEBPAGES = 0;

########################################################################



########################################################################
# Get the command line parameters.
########################################################################

my $HELP = <<"END";
USAGE
  $0 [OPTIONS]

DESCRIPTION
  This script reads an input file (-i), which is a list of words (one per
  line, commented (#) and white line are ignored).  Then all diacritics are
  removed, and the word is search on Perseus (Greek or Latin Word Tool) to
  get the associated lemma(ta).  They are written in the ouput file (-o).

  Instead of -i, you can specify a comma separated list of word with the -w
  option.

OPTIONS
  -h --help       Print this help.
  -i FILE         Input file.
  -w WORD1,WORD2  Comma separated list of word (if no -i is specified).
  -o FILE         Output file (default print to stdout).
  -n --dry-run    Complete process, except downloading files.
  --write-pages   Complete process AND writing of the downloaded pages.

Version: $VERSION
END

sub get_cl_parameters {

   # default
   $SOURCE_FILE = '';
   $OUTPUT_FILE = '';
   $WORDS = '';
   $DRY_RUN = 0;
   $WRITE_WEBPAGES = 0;

   my %argv = Common::get_argv(
      # params with values
      [ qw/i o w/ ],
      # params without values
      [ qw/n dry-run write-pages/ ],
      # required params
      [ qw// ],
      # associations
      { i => \$SOURCE_FILE,
        o => \$OUTPUT_FILE,
        w => \$WORDS,
        n => sub { $DRY_RUN = 1; },
        'dry-run' => sub { $DRY_RUN = 1; },
        'write-pages' => sub { $WRITE_WEBPAGES = 1; },
      },
      # help text
      $HELP,
      # long help text
      undef,
      # number of parameters (not options) allowed
      [ qw/0/ ]
   ); 

   die "$0: *** source file $SOURCE_FILE doesn't exist ***\n"
      unless -e $SOURCE_FILE or $WORDS;

}


########################################################################
# Read the words of the source file and return them in an array.  The
# format is as follows:
#  - one line = one word
#  - commented lines (#) and white lines are ignored
#
# Diacritics are removed.
#
# Duplicates are removed.
########################################################################

sub read_source_file {

   my $file = shift;
   my $words = shift;

   my @words = ();
   if ($words) {
      @words = split /\s*,\s*/, $words;
   } else {
      print "$0: Reading file '$file'...\n";
      open my $fh, $file or die "*** can't open $file ***\n";
      while (<$fh>) {
         chomp;
         next if m/^\s*+(?:#.*+)?$/;
         s/^\s++//;
         s/\s++$//;
         push @words, $_
      }
      close $fh or die "*** can't open $file ***\n";
   }

   my @new_words = ();
   my %words_for_dups = ();
   for my $word (@words) {
      $word = NFD($word);
      $word =~ s/\p{NonspacingMark}//g;
      $word = lc $word;
      unless (exists $words_for_dups{$word}) {
         push @new_words, $word;
         $words_for_dups{$word} = 1;
      }
   }

   return @new_words;

}


########################################################################
# Perform some formatting on the words.
########################################################################

sub format_words {

   my $language = shift;
   my $r_words = shift;

   if ($language eq 'latin') {

      for (@$r_words) {
         s/j/i/ig;
         s/v/u/ig;
      }

   } else {

      # nothing

   }

}


########################################################################
# Perform some formatting on the lemmata.
########################################################################

sub format_lemmata {

   my $language = shift;
   my $r_words = shift;

   if ($language eq 'latin') {

      for (@$r_words) {
         next if m/^\s*+#/;
         s/j/i/ig;
         s/v/u/ig;
         s/[0-9]//g;
      }

   } else {

      # nothing

   }

}



########################################################################
# Write the output file, which contains the list of lemmata found on
# perseus.
########################################################################

sub write_output_file {

   my $file = shift;
   my @lemmata = @_;

   my $fh;
   if ($file) {
      print "$0: Writing the output file '$file'...\n";
      open $fh, ">", $file or die "*** can't open $file ***\n";
   } else {
      print "="x72, "\n";
      $fh = *STDOUT;
   }

   print $fh "# The lemmata found on Perseus are:\n";
   print $fh "$_\n" for (@lemmata);

   if ($file) {
      close $fh or die "*** can't open $file ***\n";
   }

}


########################################################################
# Download the lemmata from Perseus. The url to be used are:
#    http://www.perseus.tufts.edu/hopper/morph?l=%s&la=greek 
#    http://www.perseus.tufts.edu/hopper/morph?l=%s&la=la 
# where %s is the word (utf8 works).
#
# The page that we get is the famous page where all lemmata and
# morphological analysis are shown. All the lemmata are un h4 tags, and
# only the lemmata are in these tags.
#
# Return an array with the lemmata.
########################################################################

sub download_lemmata {

   my $url_template = shift;
   my @words = @_;

   my @lemmata = ();

   for my $word (@words) {

      my $url = sprintf $url_template, $word;

      print "$0: Downloading: '$url' for '$word'...\n";

      push @lemmata, "# for word $word:";

      if ($DRY_RUN) {
         print "$0: +++ DRY-RUNN: NOTHING DOWNLOADED +++\n";
         next;
      }

      my $webpage = get($url) # LWP::Simple
            or die "$0: *** unable to get page ***\n";

      my $counter = 0;
      while ($webpage =~ m{<h4[^>]*+> ([^<]++) </h4>}gcxi) {
         print "$0:    ... found lemma $1\n";
         $counter++;
         push @lemmata, $1;
      }

      if ($WRITE_WEBPAGES) {
         write_file("webpage_$word.html", $webpage);
      }

      printf "$0:    ... found %d lemma(ta)\n", $counter;

   }

   return @lemmata;

}


########################################################################
# main()
########################################################################

sub main {

   get_cl_parameters();

   # get the words

   my @words = read_source_file($SOURCE_FILE, $WORDS);

   unless (@words) {
      print "$0: No words.\n";
      return;
   }

   # determine the language

   my $language = '';
   my $url = '';
   if ($words[0] =~ m/[α-ωΑ-Ω]/) {
      $language = 'greek';
      $url = $URL_PERSEUS_GREEK;
   } else {
      $language = 'latin';
      $url = $URL_PERSEUS_LATIN;
   }

   # download the lemmata from Perseus

   format_words($language, \@words);

   my @lemmata = download_lemmata($url, @words);

   format_lemmata($language, \@lemmata);

   # write the output file

   write_output_file($OUTPUT_FILE, @lemmata);

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



main();
