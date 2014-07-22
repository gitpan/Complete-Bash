package Complete::Bash;

use 5.010001;
use strict;
use warnings;

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT_OK = qw(
                       parse_cmdline
                       format_completion
               );

our $DATE = '2014-07-22'; # DATE
our $VERSION = '0.07'; # VERSION

our %SPEC;

$SPEC{break_cmdline_into_words} = {
    v => 1.1,
    summary => 'Break command-line string into words',
    description => <<'_',

Note to users: this is an internal function. Normally you only need to use
`parse_cmdline`.

The first step of shell completion is to break the command-line string
(e.g. from COMP_LINE in bash) into words.

Bash by default split using these characters (from COMP_WORDBREAKS):

 COMP_WORDBREAKS=$' \t\n"\'@><=;|&(:'

We don't necessarily want to split using default bash's rule, for example in
Perl we might want to complete module names which contain colons (e.g.
`Module::Path`).

By default, this routine splits by spaces and tabs and takes into account
backslash and quoting. Unclosed quotes won't generate error.

_
    args_as => 'array',
    args => {
        cmdline => {
            schema => 'str*',
            req => 1,
            pos => 0,
        },
        word_breaks => {
            schema  => 'str*',
            pos => 1,
        },
    },
    result_naked => 1,
    result => {
        schema => 'array*',
    },
};
sub break_cmdline_into_words {
    my ($cmdline, $word_breaks) = @_;

    $word_breaks //= '';

    # BEGIN stolen from Parse::CommandLine, with some mods
    $cmdline =~ s/\A\s+//ms;
    $cmdline =~ s/\s+\z//ms;

    my @argv;
    my $buf;
    my $escaped;
    my $double_quoted;
    my $single_quoted;

    for my $char (split //, $cmdline) {
        if ($escaped) {
            $buf .= $char;
            $escaped = undef;
            next;
        }

        if ($char eq '\\') {
            if ($single_quoted) {
                $buf .= $char;
            } else {
                $escaped = 1;
            }
            next;
        }

        if ($char =~ /\s/) {
            if ($single_quoted || $double_quoted) {
                $buf .= $char;
            } else {
                push @argv, $buf if defined $buf;
                undef $buf;
            }
            next;
        }

        if ($char eq '"') {
            if ($single_quoted) {
                $buf .= $char;
                next;
            }
            $double_quoted = !$double_quoted;
            next;
        }

        if ($char eq "'") {
            if ($double_quoted) {
                $buf .= $char;
                next;
            }
            $single_quoted = !$single_quoted;
            next;
        }

        if (index($word_breaks, $char) >= 0) {
            if ($escaped || $single_quoted || $double_quoted) {
                $buf .= $char;
                next;
            }
            push @argv, $buf if defined $buf;
            undef $buf;
            next;
        }

        $buf .= $char;
    }
    push @argv, $buf if defined $buf;

    #if ($escaped || $single_quoted || $double_quoted) {
    #    die 'invalid command line string';
    #}
    \@argv;
    # END stolen from Parse::CommandLine
}

$SPEC{parse_cmdline} = {
    v => 1.1,
    summary => 'Parse shell command-line for processing by completion routines',
    description => <<'_',

Currently only supports bash.

_
    args_as => 'array',
    args => {
        cmdline => {
            summary => 'Command-line, defaults to COMP_LINE environment',
            schema => 'str*',
            pos => 0,
        },
        point => {
            summary => 'Point/position to complete in command-line, '.
                'defaults to COMP_POINT',
            schema => 'int*',
            pos => 1,
        },
        word_breaks => {
            summary => 'Extra characters to break word at',
            description => <<'_',

In addition to space and tab.

Example: `=:`.

Note that the characters won't break words if inside quotes or escaped.

_
            schema => 'str*',
            pos => 2,
        },
    },
    result => {
        schema => ['array*', len=>2],
        description => <<'_',

Return a 2-element array: `[$words, $cword]`. `$words` is array of str,
equivalent to `COMP_WORDS` provided by shell to bash function. `$cword` is an
integer, equivalent to shell-provided `COMP_CWORD` variable to bash function.
The word to be completed is at `$words->[$cword]`.

_
    },
    result_naked => 1,
    examples => [
        {
            argv    => ['cmd ', 4],
            result  => [[], 0],
            summary => 'The command (first word) is never included',
        },
        {
            argv    => ['cmd -', 5],
            result  => [['-'], 0],
        },
        {
            argv    => ['cmd - ', 6],
            result  => [['-'], 1],
        },
        {
            argv    => ['cmd --opt val', 6],
            result  => [['--', 'val'], 0],
        },
        {
            argv    => ['cmd --opt val', 9],
            result  => [['--opt', 'val'], 0],
        },
        {
            argv    => ['cmd --opt val', 10],
            result  => [['--opt'], 1],
        },
        {
            argv    => ['cmd --opt val', 13],
            result  => [['--opt', 'val'], 1],
        },
        {
            argv    => ['cmd --opt val ', 14],
            result  => [['--opt', 'val'], 2],
        },
        {
            argv    => ['cmd --opt=val', 13],
            result  => [['--opt=val'], 0],
            summary => 'Other word-breaking characters (other than whitespace)'.
                ' is not used by default',
        },
        {
            argv    => ['cmd --opt=val', 13, '='],
            result  => [['--opt', 'val'], 1],
            summary => "Breaking at '=' too",
        },
        {
            argv    => ['cmd --opt=val ', 14, '='],
            result  => [['--opt', 'val'], 2],
            summary => "Breaking at '=' too (2)",
        },
        {
            argv    => ['cmd "--opt=val', 13],
            result  => [['--opt=va'], 0],
            summary => 'Double quote protects word-breaking characters',
        },
    ],
};
sub parse_cmdline {
    my ($line, $point, $word_breaks) = @_;

    $line  //= $ENV{COMP_LINE};
    $point //= $ENV{COMP_POINT} // 0;

    die "$0: COMP_LINE not set, make sure this script is run under ".
        "bash completion (e.g. through complete -C)\n" unless defined $line;

    my $left  = substr($line, 0, $point);
    my $right = substr($line, $point);
    #$log->tracef("line=<%s>, point=%s, left=<%s>, right=<%s>",
    #             $line, $point, $left, $right);

    my @left;
    if (length($left)) {
        @left = @{ break_cmdline_into_words($left, $word_breaks) };
        # shave off $0
        substr($left, 0, length($left[0])) = "";
        $left =~ s/^\s+//;
        shift @left;
    }

    my @right;
    if (length($right)) {
        # shave off the rest of the word at "cursor"
        $right =~ s/^\S+//;
        @right = @{ break_cmdline_into_words($right, $word_breaks) }
            if length($right);
    }
    #$log->tracef("\@left=%s, \@right=%s", \@left, \@right);

    my $words = [@left, @right],
    my $cword = @left ? scalar(@left)-1 : 0;

    # is there a space after the final word (e.g. "foo bar ^" instead of "foo
    # bar^" or "foo bar\ ^")? if yes then cword is on the next word.
    my $tmp = $left;
    my $nspc_left = 0; $nspc_left++ while $tmp =~ s/\s$//;
    $tmp = $left[-1];
    my $nspc_lastw = 0;
    if (defined($tmp)) { $nspc_lastw++ while $tmp =~ s/\s$// }
    $cword++ if $nspc_lastw < $nspc_left;

    return [$words, $cword];
}

$SPEC{format_completion} = {
    v => 1.1,
    summary => 'Format completion for output (for shell)',
    description => <<'_',

Bash accepts completion reply in the form of one entry per line to STDOUT. Some
characters will need to be escaped. This function helps you do the formatting,
with some options.

This function accepts an array (the result of a `complete_*` function), _or_ a
hash (which contains the completion array from a `complete_*` function as well
as other metadata for formatting hints). Known keys:

* `completion` (array): The completion array. You can put the result of
  `complete_*` function here.

* `as` (str): Either `string` (the default) or `array` (to return array of lines
  instead of the lines joined together). Returning array is useful if you are
  doing completion inside `Term::ReadLine`, for example, where the library
  expects an array.

* `escmode` (str): Escaping mode for entries. Either `default` (most
  nonalphanumeric characters will be escaped), `shellvar` (like `default`, but
  dollar sign `$` will not be escaped, convenient when completing environment
  variables for example), `filename` (currently equals to `default`), `option`
  (currently equals to `default`), or `none` (no escaping will be done).

* `path_sep` (str): If set, will enable "path mode", useful for
  completing/drilling-down path. Below is the description of "path mode".

  In shell, when completing filename (e.g. `foo`) and there is only a single
  possible completion (e.g. `foo` or `foo.txt`), the shell will display the
  completion in the buffer and automatically add a space so the user can move to
  the next argument. This is also true when completing other values like
  variables or program names.

  However, when completing directory (e.g. `/et` or `Downloads`) and there is
  solely a single completion possible and it is a directory (e.g. `/etc` or
  `Downloads`), the shell automatically adds the path separator character
  instead (`/etc/` or `Downloads/`). The user can press Tab again to complete
  for files/directories inside that directory, and so on. This is obviously more
  convenient compared to when shell adds a space instead.

  The `path_sep` option, when set, will employ a trick to mimic this behaviour.
  The trick is, if you have a completion array of `['foo/']`, it will be changed
  to `['foo/', 'foo/ ']` (the second element is the first element with added
  space at the end) to prevent bash from adding a space automatically.

  Path mode is not restricted to completing filesystem paths. Anything path-like
  can use it. For example when you are completing Java or Perl package name
  (e.g. `com.company.product.whatever` or `File::Spec::Unix`) you can use this
  mode (with `path_sep` appropriately set to, e.g. `.` or `::`). But note that
  in the case of `::` since colon is a word-breaking character in Bash by
  default, when typing you'll need to escape it (e.g. `mpath File\:\:Sp<tab>`)
  or use it inside quotes (e.g. `mpath "File::Sp<tab>`).

_
    args_as => 'array',
    args => {
        shell_completion => {
            summary => 'Result of shell completion',
            description => <<'_',

Either an array or hash. See function description for more details.

_
            schema=>['any*' => of => ['hash*', 'array*']],
            req=>1,
            pos=>0,
        },
    },
    result => {
        summary => 'Formatted string (or array, if `as` is set to `array`)',
        schema => ['any*' => of => ['str*', 'array*']],
    },
    result_naked => 1,
};
sub format_completion {
    my ($hcomp) = @_;

    $hcomp = {completion=>$hcomp} unless ref($hcomp) eq 'HASH';
    my $comp     = $hcomp->{completion};
    my $as       = $hcomp->{as} // 'string';
    my $escmode  = $hcomp->{escmode} // 'default';
    my $path_sep = $hcomp->{path_sep};

    if (defined($path_sep) && @$comp == 1 && $comp->[0] =~ /\Q$path_sep\E\z/) {
        $comp = [$comp->[0], "$comp->[0] "];
    }

    my @lines = @$comp;
    for (@lines) {
        if ($escmode eq 'shellvar') {
            # don't escape $
            s!([^A-Za-z0-9,+._/\$-])!\\$1!g;
        } elsif ($escmode eq 'none') {
            # no escaping
        } else {
            # default
            s!([^A-Za-z0-9,+._/:-])!\\$1!g;
        }
    }

    if ($as eq 'array') {
        return \@lines;
    } else {
        return join("", map {($_, "\n")} @lines);
    }
}

1;
#ABSTRACT: Completion module for bash shell

__END__

=pod

=encoding UTF-8

=head1 NAME

Complete::Bash - Completion module for bash shell

=head1 VERSION

This document describes version 0.07 of Complete::Bash (from Perl distribution Complete-Bash), released on 2014-07-22.

=head1 DESCRIPTION

Bash allows completion to come from various sources. The simplest is from a list
of words (C<-W>):

 % complete -W "one two three four" somecmd
 % somecmd t<Tab>
 two  three

Another source is from a bash function (C<-F>). The function will receive input
in two variables: C<COMP_WORDS> (array, command-line chopped into words) and
C<COMP_CWORD> (integer, index to the array of words indicating the cursor
position). It must set an array variable C<COMPREPLY> that contains the list of
possible completion:

 % _foo()
 {
   local cur
   COMPREPLY=()
   cur=${COMP_WORDS[COMP_CWORD]}
   COMPREPLY=($( compgen -W '--help --verbose --version' -- $cur ) )
 }
 % complete -F _foo foo
 % foo <Tab>
 --help  --verbose  --version

And yet another source is an external command (including, a Perl script). The
command receives two environment variables: C<COMP_LINE> (string, raw
command-line) and C<COMP_POINT> (integer, cursor location). Program must split
C<COMP_LINE> into words, find the word to be completed, complete that, and
return the list of words one per-line to STDOUT. An example:

 % cat foo-complete
 #!/usr/bin/perl
 use Complete::Bash qw(parse_cmdline format_completion);
 use Complete::Util qw(complete_array_elem);
 my ($words, $cword) = parse_cmdline();
 my $res = complete_array_elem(array=>[qw/--help --verbose --version/], word=>$words->[$cword]);
 print format_completion($res);

 % complete -C foo-complete foo
 % foo --v<Tab>
 --verbose --version

This module provides routines for you to be doing the above.

Instead of being called by bash as an external command every time user presses
Tab, you can also use Perl to I<generate> bash C<complete> scripts for you. See
L<Complete::BashGen>.

=head1 FUNCTIONS


=head2 break_cmdline_into_words(@args) -> array

Break command-line string into words.

Note to users: this is an internal function. Normally you only need to use
C<parse_cmdline>.

The first step of shell completion is to break the command-line string
(e.g. from COMP_LINE in bash) into words.

Bash by default split using these characters (from COMP_WORDBREAKS):

 COMP_WORDBREAKS=$' \t\n"\'@><=;|&(:'

We don't necessarily want to split using default bash's rule, for example in
Perl we might want to complete module names which contain colons (e.g.
C<Module::Path>).

By default, this routine splits by spaces and tabs and takes into account
backslash and quoting. Unclosed quotes won't generate error.

Arguments ('*' denotes required arguments):

=over 4

=item * B<cmdline>* => I<str>

=item * B<word_breaks> => I<str>

=back

Return value:

 (array)


=head2 format_completion(@args) -> array|str

Format completion for output (for shell).

Bash accepts completion reply in the form of one entry per line to STDOUT. Some
characters will need to be escaped. This function helps you do the formatting,
with some options.

This function accepts an array (the result of a C<complete_*> function), I<or> a
hash (which contains the completion array from a C<complete_*> function as well
as other metadata for formatting hints). Known keys:

=over

=item * C<completion> (array): The completion array. You can put the result of
C<complete_*> function here.

=item * C<as> (str): Either C<string> (the default) or C<array> (to return array of lines
instead of the lines joined together). Returning array is useful if you are
doing completion inside C<Term::ReadLine>, for example, where the library
expects an array.

=item * C<escmode> (str): Escaping mode for entries. Either C<default> (most
nonalphanumeric characters will be escaped), C<shellvar> (like C<default>, but
dollar sign C<$> will not be escaped, convenient when completing environment
variables for example), C<filename> (currently equals to C<default>), C<option>
(currently equals to C<default>), or C<none> (no escaping will be done).

=item * C<path_sep> (str): If set, will enable "path mode", useful for
completing/drilling-down path. Below is the description of "path mode".

In shell, when completing filename (e.g. C<foo>) and there is only a single
possible completion (e.g. C<foo> or C<foo.txt>), the shell will display the
completion in the buffer and automatically add a space so the user can move to
the next argument. This is also true when completing other values like
variables or program names.

However, when completing directory (e.g. C</et> or C<Downloads>) and there is
solely a single completion possible and it is a directory (e.g. C</etc> or
C<Downloads>), the shell automatically adds the path separator character
instead (C</etc/> or C<Downloads/>). The user can press Tab again to complete
for files/directories inside that directory, and so on. This is obviously more
convenient compared to when shell adds a space instead.

The C<path_sep> option, when set, will employ a trick to mimic this behaviour.
The trick is, if you have a completion array of C<['foo/']>, it will be changed
to C<['foo/', 'foo/ ']> (the second element is the first element with added
space at the end) to prevent bash from adding a space automatically.

Path mode is not restricted to completing filesystem paths. Anything path-like
can use it. For example when you are completing Java or Perl package name
(e.g. C<com.company.product.whatever> or C<File::Spec::Unix>) you can use this
mode (with C<path_sep> appropriately set to, e.g. C<.> or C<::>). But note that
in the case of C<::> since colon is a word-breaking character in Bash by
default, when typing you'll need to escape it (e.g. C<< mpath File\:\:SpE<lt>tabE<gt> >>)
or use it inside quotes (e.g. C<< mpath "File::SpE<lt>tabE<gt> >>).

=back

Arguments ('*' denotes required arguments):

=over 4

=item * B<shell_completion>* => I<array|hash>

Result of shell completion.

Either an array or hash. See function description for more details.

=back

Return value:

Formatted string (or array, if `as` is set to `array`) (any)


=head2 parse_cmdline(@args) -> array

Parse shell command-line for processing by completion routines.

Examples:

 parse_cmdline("cmd ", 4); # -> [[], 0]


The command (first word) is never included.


 parse_cmdline("cmd -", 5); # -> [["-"], 0]
 parse_cmdline("cmd - ", 6); # -> [["-"], 1]
 parse_cmdline("cmd --opt val", 6); # -> [["--", "val"], 0]
 parse_cmdline("cmd --opt val", 9); # -> [["--opt", "val"], 0]
 parse_cmdline("cmd --opt val", 10); # -> [["--opt"], 1]
 parse_cmdline("cmd --opt val", 13); # -> [["--opt", "val"], 1]
 parse_cmdline("cmd --opt val ", 14); # -> [["--opt", "val"], 2]
 parse_cmdline("cmd --opt=val", 13); # -> [["--opt=val"], 0]


Other word-breaking characters (other than whitespace) is not used by default.


 parse_cmdline("cmd --opt=val", 13, "="); # -> [["--opt", "val"], 1]


Breaking at '=' too.


 parse_cmdline("cmd --opt=val ", 14, "="); # -> [["--opt", "val"], 2]


Breaking at '=' too (2).


 parse_cmdline("cmd \"--opt=val", 13); # -> [["--opt=va"], 0]


Double quote protects word-breaking characters.


Currently only supports bash.

Arguments ('*' denotes required arguments):

=over 4

=item * B<cmdline> => I<str>

Command-line, defaults to COMP_LINE environment.

=item * B<point> => I<int>

Point/position to complete in command-line, defaults to COMP_POINT.

=item * B<word_breaks> => I<str>

Extra characters to break word at.

In addition to space and tab.

Example: C<=:>.

Note that the characters won't break words if inside quotes or escaped.

=back

Return value:

 (array)

Return a 2-element array: `[$words, $cword]`. `$words` is array of str,
equivalent to `COMP_WORDS` provided by shell to bash function. `$cword` is an
integer, equivalent to shell-provided `COMP_CWORD` variable to bash function.
The word to be completed is at `$words->[$cword]`.

=head1 TODOS

Accept regex for path_sep.

=head1 SEE ALSO

L<Complete>

L<Complete::BashGen>

Other modules related to bash shell tab completion: L<Bash::Completion>,
L<Getopt::Complete>. L<Term::Bash::Completion::Generator>

Programmable Completion section in Bash manual:
L<https://www.gnu.org/software/bash/manual/html_node/Programmable-Completion.html>

=head1 HOMEPAGE

Please visit the project's homepage at L<https://metacpan.org/release/Complete-Bash>.

=head1 SOURCE

Source repository is at L<https://github.com/sharyanto/perl-Complete-Bash>.

=head1 BUGS

Please report any bugs or feature requests on the bugtracker website L<https://rt.cpan.org/Public/Dist/Display.html?Name=Complete-Bash>

When submitting a bug or request, please include a test-file or a
patch to an existing test-file that illustrates the bug or desired
feature.

=head1 AUTHOR

Steven Haryanto <stevenharyanto@gmail.com>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2014 by Steven Haryanto.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
