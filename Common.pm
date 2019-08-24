package Common;
use strict;
use warnings;
use utf8;
use open ':utf8';
#use Data::Dumper;


########################################################################
# Print the given message and wait for 'y/n'. Return T/F.
# As second argument, a default value can be given (T/F): this is the
# value return if the user type nothing.
########################################################################

sub confirm_yn {

	my $message = shift || 'Confirm ? (y|n) ';
	my $default = shift;

	ITER: {
		print $message;
		my $ans = <STDIN>;
		print "\n" unless -t STDIN;
		return 1 if $ans =~ m/^\s*+y(?:es)?\s*+$/;
		return 0 if $ans =~ m/^\s*+n(?:o)?\s*+$/;
		return $default if (defined($default) and $ans =~ m/^\s*+$/);
		redo ITER;
	}

}


########################################################################
# Execute the shell command, after having printed it. Die if must.
#
# If there are more than one parameters given, apply a sprintf (the
# first param is the template).  For ex.:
#  run('echo "%s"', $truc);
########################################################################

sub run_system_cmd {

   my $cmd = '';

   if (scalar @_ > 1) {
      $cmd = sprintf(shift, @_);
   } else {
      $cmd = shift;
   }

   print "$0: Executing command: $cmd\n";

   system($cmd) and die "$0: *** error while running command ***\n$!\n";

}





########################################################################
# Analyze $ARGV and get options and parameters in a hash.
#
# First, make the difference between options (ex.: -i --input FILE)
# and parameters (what is not an option).
#
# The function accepts several parameters, which describe what to do
# we the content of $ARGV.  They are documented in the following
# snippet, which you can copy as a function in your program.
#
# Note that the option -h and --help are automatically present.
#
# sub get_cl_parameters {
# 
#    # default
#    $INPUT_FILE = '';
#    ...
# 
#    # note: make the difference between options (ex.: -i --input FILE)
#    # and parameters (what is not an option)
#    my %argv = Common::get_argv(
#       # options with values
#       [ qw/i o log-file/ ],
#       # option without values
#       [ qw/n dry-run v verbose/ ],
#       # required options
#       [ qw/i o/ ],
#       # associations options <-> variable/code
#       {
#         # options with value
#         i        => \$INPUT_FILE,
#         o        => \$OUTPUT_FILE,
#         log-file => \$LOG
#         # options without value (boolean operators)
#         dry-run  => \$DRY_RUN,
#         verbose  => \$VERBOSE,
#         # you can also define an "event handler":
#         option   => sub { print "hello world!\n"; },
#       },
#       # help text
#       $HELP,       # or undef to print a defaut msg
#       # long help text
#       $LONG_HELP,  # or undef to repeat the short help text
#       # number of parameters (not options) allowed (its an array, so
#       # you may list several numbers, if you want)
#       [ qw/1/ ]
#    ); 
#
#    # make some checks here (input file exists, etc.)
# 
# }
#
# The function returns a hash in which the keys are the options' names
# and the values the options' values.  Besides, the key '' as an array
# ref as value, in which all the parameters are listed (if no
# parameters, the array is empty).
# {
#     ''        => [ param1, param2, ... ],
#     'input'   => 'file',
#     'verbose' => 1,
#     ...
# }
# 
########################################################################

sub get_argv {

   my @val_options = @{shift(@_) || []}; # with value
   my @noval_options = @{shift @_ || []}; # with no value
   my @req_options = @{shift @_ || []}; # required
   my %assoc = %{shift @_ || {}}; # assocations to ref variables
   my $help_text = shift @_ || "No help available\n";
   my $long_help_text = shift @_ || $help_text;
   my @nb_allowed = @{shift @_ || []}; # nb of param (not options) allowed
                                       # its an array because they may
                                       # be several numbers allowed

   # make the variables

   my %argv = ('' => []);

   my %val_options = ();
   my %noval_options = ();
   my %nb_allowed = ();

   $val_options{(length($_)==1?'-':'--').$_} = $_ for (@val_options);
   $noval_options{(length($_)==1?'-':'--').$_} = $_ for (@noval_options);
   $nb_allowed{$_} = 1 for (@nb_allowed);

   # read ARGV

   while (my $item = shift @ARGV) {

      if ($item eq '-h') {

         print $help_text;
         exit 0;
      
      } elsif ($item eq '--help') {

         print $long_help_text;
         exit 0;

      } elsif (exists($val_options{$item})) {

         my $val = shift @ARGV;

         unless (defined($val) and $val !~ m/^-/) {
            die "$0: *** no value for parameter $item ***\n";
         }

         $argv{$val_options{$item}} = $val;

      } elsif (exists($noval_options{$item})) {

         $argv{$noval_options{$item}} = 1;

      } elsif ($item =~ m/^-/) {

         die "$0: *** not a valid parameter: $item ***\n";

      } else {

         push @{$argv{''}}, $item;

      }

   }

   # check for required parameters

   for (@req_options) {
      die "$0: *** no required parameter $_ ***\n"
         unless exists $argv{$_};
   }

   # associate values with reference variables

   while (my ($k, $v) = each %assoc) {

      if (exists $argv{$k}) {
         #if (exists $noval_options{$k}) { # true or false
         #   $$v = 1;
         #} else { # set the value
            if (ref $v eq "CODE") {
               $v->($k, $argv{$k});
            } else {
               $$v = $argv{$k};
            }
         #}
      } else {
         # nothing: leave the (default) value
      }

   }

   # check if there is the right number of parameters (apart from
   # options)

   unless (!@nb_allowed or exists ($nb_allowed{scalar @{$argv{''}}})) {
      die "$0: *** not the right number of parameters ***\n";
   }

   @ARGV = ();

   return %argv;

}

# TEST:
#use Data::Dumper;
#my $test1 = 'test1';
#my $test2 = 'test2';
#my %foo = get_argv([qw/a b c abc/], [qw/d e f def/], [qw/a c/],
#   { a => \$test1, b => \$test2 } );
#print Dumper \%foo;
#print "test 1: $test1\n";
#print "test 2: $test2\n";


1;


