package Complete::Bash;

our $DATE = '2014-12-29'; # DATE
our $VERSION = '0.15'; # VERSION

use 5.010001;
use strict;
use warnings;

#use Complete;

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT_OK = qw(
                       parse_cmdline
                       parse_options
                       format_completion
               );

our %SPEC;

$SPEC{':package'} = {
    v => 1.1,
    summary => 'Completion module for bash shell',
    links => [
        {url => 'pm:Complete'},
    ],
};

$SPEC{parse_cmdline} = {
    v => 1.1,
    summary => 'Parse shell command-line for processing by completion routines',
    description => <<'_',

This function basically converts COMP_LINE (str) and COMP_POINT (int) to become
COMP_WORDS (array) and COMP_CWORD (int), like what bash supplies to shell
functions. The differences with bash are: 1) quotes and backslashes are by
default stripped, unless you specify `preserve_quotes`; 2) no word-breaking
characters aside from whitespaces are used, unless you specify more
word-breaking characters by setting `word_breaks`.

Caveats:

* Due to the way bash parses the command line, the two below are equivalent:

    % cmd --foo=bar
    % cmd --foo = bar

Because they both expand to `['--foo', '=', 'bar']`, when `=` is used as a
word-breaking character. But obviously `Getopt::Long` does not regard the two as
equivalent.

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
            schema => 'str',
            pos => 2,
        },
        preserve_quotes => {
            summary => 'Whether to preserve quotes, like bash does',
            schema => 'bool',
            default => 0,
            pos => 3,
        },
    },
    result => {
        schema => ['array*', len=>2],
        description => <<'_',

Return a 2-element array: `[$words, $cword]`. `$words` is array of str,
equivalent to `COMP_WORDS` provided by bash to shell functions. `$cword` is an
integer, equivalent to `COMP_CWORD` provided by bash to shell functions. The
word to be completed is at `$words->[$cword]`.

Note that COMP_LINE includes the command name. If you want the command-line
arguments only (like in `@ARGV`), you need to strip the first element from
`$words` and reduce `$cword` by 1.


_
    },
    result_naked => 1,
    links => [
        {
            url => 'pm:Parse::CommandLine',
            description => <<'_',

The module `Parse::CommandLine` has a function called `parse_command_line()`
which is similar, breaking a command-line string into words (in fact, currently
`parse_cmdline()`'s implementation is stolen from this module). However,
`parse_cmdline()` does not die on unclosed quotes and allows custom
word-breaking characters.

_
        },
    ],
};
sub parse_cmdline {
    my ($line, $point, $word_breaks, $preserve_quotes) = @_;

    $line  //= $ENV{COMP_LINE};
    $point //= $ENV{COMP_POINT} // 0;
    $word_breaks //= '';

    die "$0: COMP_LINE not set, make sure this script is run under ".
        "bash completion (e.g. through complete -C)\n" unless defined $line;

    my $pos = 0;
    my $len = length($line);
    # first word is ltrim-ed by bash
    $line =~ s/\A(\s+)//gs and $pos += length($1);

    my @words;
    my $buf;
    my $cword;
    my $escaped;
    my $inserted_empty_word;
    my $double_quoted;
    my $single_quoted;

    my @chars = split //, $line;
    $pos--;
    for my $char (@chars) {
        $pos++;
        #say "D:pos=$pos, char=$char, \@words=[".join(", ", @words)."]";
        if (!defined($cword) && $pos == $point) {
            $cword = @words;
            #say "D:setting cword to $cword";
        }

        if ($escaped) {
            $buf .= $preserve_quotes ? "\\$char" : $char;
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
                if (defined $buf) {
                    #say "D:pushing word <$buf>";
                    push @words, $buf;
                    undef $buf;
                } elsif (!$inserted_empty_word &&
                             $pos==$point && $chars[$pos-1] =~ /\s/ &&
                                 $pos+1 < $len && $chars[$pos+1] =~ /\s/) {
                    #say "D:insert empty word";
                    push @words, '' unless $words[-1] eq '';
                    $inserted_empty_word++;
                }
            }
            next;
        } else {
            $inserted_empty_word = 0;
        }

        if ($char eq '"') {
            if ($single_quoted) {
                $buf .= $char;
                next;
            }
            $double_quoted = !$double_quoted;
            if (!$double_quoted) {
                $buf .= '"' if $preserve_quotes;
            }
            next;
        }

        if ($char eq "'") {
            if ($double_quoted) {
                $buf .= $char;
                next;
            }
            $single_quoted = !$single_quoted;
            if (!$single_quoted) {
                $buf .= "'" if $preserve_quotes;
            }
            next;
        }

        if (index($word_breaks, $char) >= 0) {
            if ($escaped || $single_quoted || $double_quoted) {
                $buf .= $single_quoted ? "'":'"' if !defined($buf) && $preserve_quotes;
                $buf .= $char;
                next;
            }
            push @words, $buf if defined $buf;
            push @words, $char;
            undef $buf;
            next;
        }

        $buf .= $single_quoted ? "'" : $double_quoted ? '"' : '' if !defined($buf) && $preserve_quotes;
        $buf .= $char;
    }

    if (defined $buf) {
        #say "D:pushing last word <$buf>";
        push @words, $buf;
        $cword //= @words-1;
    } else {
        if (!@words || $words[-1] ne '') {
            $cword //= @words;
            $words[$cword] //= '';
        } else {
            $cword //= @words-1;
        }
    }

    return [\@words, $cword];
}

$SPEC{parse_options} = {
    v => 1.1,
    summary => 'Parse command-line for options and arguments, '.
        'more or less like Getopt::Long',
    description => <<'_',

Parse command-line into words using `parse_cmdline()` then separate options and
arguments. Since this routine does not accept `Getopt::Long` (this routine is
meant to be a generic option parsing of command-lines), it uses a few simple
rules to server the common cases:

* After `--`, the rest of the words are arguments (just like Getopt::Long).

* If we get something like `-abc` (a single dash followed by several letters) it
  is assumed to be a bundle of short options.

* If we get something like `-MData::Dump` (a single dash, followed by a letter,
  followed by some letters *and* non-letters/numbers) it is assumed to be an
  option (`-M`) followed by a value.

* If we get something like `--foo` it is a long option. If the next word is an
  option (starts with a `-`) then it is assumed that this option does not have
  argument. Otherwise, the next word is assumed to be this option's value.

* Otherwise, it is an argument (that is, permute is assumed).

_

    args => {
        cmdline => {
            summary => 'Command-line, defaults to COMP_LINE environment',
            schema => 'str*',
        },
        point => {
            summary => 'Point/position to complete in command-line, '.
                'defaults to COMP_POINT',
            schema => 'int*',
        },
        words => {
            summary => 'Alternative to passing `cmdline` and `point`',
            schema => ['array*', of=>'str*'],
            description => <<'_',

If you already did a `parse_cmdline()`, you can pass the words result (the first
element) here to avoid calling `parse_cmdline()` twice.

_
        },
        cword => {
            summary => 'Alternative to passing `cmdline` and `point`',
            schema => ['array*', of=>'str*'],
            description => <<'_',

If you already did a `parse_cmdline()`, you can pass the cword result (the
second element) here to avoid calling `parse_cmdline()` twice.

_
        },
    },
    result => {
        schema => 'hash*',
    },
};
sub parse_options {
    my %args = @_;

    my ($words, $cword) = @_;
    if ($args{words}) {
        ($words, $cword) = ($args{words}, $args{cword});
    } else {
        ($words, $cword) = @{parse_cmdline($args{cmdline}, $args{point}, '=')};
    }

    my @types;
    my %opts;
    my @argv;
    my $type;
    $types[0] = 'command';
    my $i = 1;
    while ($i < @$words) {
        my $word = $words->[$i];
        if ($word eq '--') {
            if ($i == $cword) {
                $types[$i] = 'opt_name';
                $i++; next;
            }
            $types[$i] = 'separator';
            for ($i+1 .. @$words-1) {
                $types[$_] = 'arg,' . @argv;
                push @argv, $words->[$_];
            }
            last;
        } elsif ($word =~ /\A-(\w*)\z/) {
            $types[$i] = 'opt_name';
            for (split '', $1) {
                push @{ $opts{$_} }, undef;
            }
            $i++; next;
        } elsif ($word =~ /\A-([\w?])(.*)/) {
            $types[$i] = 'opt_name';
            # XXX currently not completing option value
            push @{ $opts{$1} }, $2;
            $i++; next;
        } elsif ($word =~ /\A--(\w[\w-]*)\z/) {
            $types[$i] = 'opt_name';
            my $opt = $1;
            $i++;
            if ($i < @$words) {
                if ($words->[$i] eq '=') {
                    $types[$i] = 'separator';
                    $i++;
                }
                if ($words->[$i] =~ /\A-/) {
                    push @{ $opts{$opt} }, undef;
                    next;
                }
                $types[$i] = 'opt_val';
                push @{ $opts{$opt} }, $words->[$i];
                $i++; next;
            }
        } else {
            $types[$i] = 'arg,' . @argv;
            push @argv, $word;
            $i++; next;
        }
    }

    return {
        opts      => \%opts,
        argv      => \@argv,
        cword     => $cword,
        words     => $words,
        word_type => $types[$cword],
        #_types    => \@types,
    };
}

$SPEC{format_completion} = {
    v => 1.1,
    summary => 'Format completion for output (for shell)',
    description => <<'_',

Bash accepts completion reply in the form of one entry per line to STDOUT. Some
characters will need to be escaped. This function helps you do the formatting,
with some options.

This function accepts completion answer structure as described in the `Complete`
POD. Aside from `words`, this function also recognizes these keys:

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
  can use it. For example when you are completing Java or Perl module name (e.g.
  `com.company.product.whatever` or `File::Spec::Unix`) you can use this mode
  (with `path_sep` appropriately set to, e.g. `.` or `::`).

_
    args_as => 'array',
    args => {
        completion => {
            summary => 'Completion answer structure',
            description => <<'_',

Either an array or hash. See function description for more details.

_
            schema=>['any*' => of => ['hash*', 'array*']],
            req=>1,
            pos=>0,
        },
        opts => {
            schema=>'hash*',
            pos=>1,
        },
    },
    result => {
        summary => 'Formatted string (or array, if `as` is set to `array`)',
        schema => ['any*' => of => ['str*', 'array*']],
    },
    result_naked => 1,
};
sub format_completion {
    my ($hcomp, $opts) = @_;

    $opts //= {};

    $hcomp = {words=>$hcomp} unless ref($hcomp) eq 'HASH';
    my $comp     = $hcomp->{words};
    my $as       = $hcomp->{as} // 'string';
    my $escmode  = $hcomp->{escmode} // 'default';
    my $path_sep = $hcomp->{path_sep};

    if (defined($path_sep) && @$comp == 1) {
        my $re = qr/\Q$path_sep\E\z/;
        my $word;
        if (ref($comp->[0]) eq 'HASH') {
            $comp = [$comp->[0], {word=>"$comp->[0] "}] if
                $comp->[0]{word} =~ $re;
        } else {
            $comp = [$comp->[0], "$comp->[0] "]
                if $comp->[0] =~ $re;
        }
    }

    # XXX this is currently an ad-hoc solution, need to formulate a
    # name/interface for the more generic solution. since bash breaks words
    # differently than us (we only break using '" and whitespace, while bash
    # breaks using characters in $COMP_WORDBREAKS, by default is "'><=;|&(:),
    # this presents a problem we often encounter: if we want to provide with a
    # list of strings containing ':', most often Perl modules/packages, if user
    # types e.g. "Text::AN" and we provide completion ["Text::ANSI"] then bash
    # will change the word at cursor to become "Text::Text::ANSI" since it sees
    # the current word as "AN" and not "Text::AN". the workaround is to chop
    # /Text::/ from completion answers. this doesn't always work perfectly (e.g.
    # we can also provide completion for "t::an" (exp_im_path and ci feature)
    # but a good-enough workaround for common cases. and we currently only
    # consider ':' since that occurs often.
    if (defined($opts->{word})) {
        if ($opts->{word} =~ s/(.+:)//) {
            my $prefix = $1;
            for (@$comp) {
                if (ref($_) eq 'HASH') {
                    $_->{word} =~ s/\A\Q$prefix\E//;
                } else {
                    s/\A\Q$prefix\E//;
                }
            }
        }
    }

    my @res;
    for my $entry (@$comp) {
        my $word = ref($entry) eq 'HASH' ? $entry->{word} : $entry;
        if ($escmode eq 'shellvar') {
            # don't escape $
            $word =~ s!([^A-Za-z0-9,+._/\$~-])!\\$1!g;
        } elsif ($escmode eq 'none') {
            # no escaping
        } else {
            # default
            $word =~ s!([^A-Za-z0-9,+._/:~-])!\\$1!g;
        }
        push @res, $word;
    }

    if ($as eq 'array') {
        return \@res;
    } else {
        return join("", map {($_, "\n")} @res);
    }
}

1;
# ABSTRACT: Completion module for bash shell

__END__

=pod

=encoding UTF-8

=head1 NAME

Complete::Bash - Completion module for bash shell

=head1 VERSION

This document describes version 0.15 of Complete::Bash (from Perl distribution Complete-Bash), released on 2015-12-29.

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
 my ($words, $cword) = @{ parse_cmdline() };
 my $res = complete_array_elem(array=>[qw/--help --verbose --version/], word=>$words->[$cword]);
 print format_completion($res);

 % complete -C foo-complete foo
 % foo --v<Tab>
 --verbose --version

This module provides routines for you to be doing the above.

=head1 FUNCTIONS


=head2 format_completion($completion, $opts) -> array|str

Format completion for output (for shell).

Bash accepts completion reply in the form of one entry per line to STDOUT. Some
characters will need to be escaped. This function helps you do the formatting,
with some options.

This function accepts completion answer structure as described in the C<Complete>
POD. Aside from C<words>, this function also recognizes these keys:

=over

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
can use it. For example when you are completing Java or Perl module name (e.g.
C<com.company.product.whatever> or C<File::Spec::Unix>) you can use this mode
(with C<path_sep> appropriately set to, e.g. C<.> or C<::>).

=back

Arguments ('*' denotes required arguments):

=over 4

=item * B<completion>* => I<array|hash>

Completion answer structure.

Either an array or hash. See function description for more details.

=item * B<opts> => I<hash>

=back

Return value:

Formatted string (or array, if `as` is set to `array`) (any)


=head2 parse_cmdline($cmdline, $point, $word_breaks, $preserve_quotes) -> array

Parse shell command-line for processing by completion routines.

This function basically converts COMP_LINE (str) and COMP_POINT (int) to become
COMP_WORDS (array) and COMP_CWORD (int), like what bash supplies to shell
functions. The differences with bash are: 1) quotes and backslashes are by
default stripped, unless you specify C<preserve_quotes>; 2) no word-breaking
characters aside from whitespaces are used, unless you specify more
word-breaking characters by setting C<word_breaks>.

Caveats:

=over

=item * Due to the way bash parses the command line, the two below are equivalent:

% cmd --foo=bar
% cmd --foo = bar

=back

Because they both expand to C<['--foo', '=', 'bar']>, when C<=> is used as a
word-breaking character. But obviously C<Getopt::Long> does not regard the two as
equivalent.

Arguments ('*' denotes required arguments):

=over 4

=item * B<cmdline> => I<str>

Command-line, defaults to COMP_LINE environment.

=item * B<point> => I<int>

Point/position to complete in command-line, defaults to COMP_POINT.

=item * B<preserve_quotes> => I<bool> (default: 0)

Whether to preserve quotes, like bash does.

=item * B<word_breaks> => I<str>

Extra characters to break word at.

In addition to space and tab.

Example: C<=:>.

Note that the characters won't break words if inside quotes or escaped.

=back

Return value:

 (array)

Return a 2-element array: C<[$words, $cword]>. C<$words> is array of str,
equivalent to C<COMP_WORDS> provided by bash to shell functions. C<$cword> is an
integer, equivalent to C<COMP_CWORD> provided by bash to shell functions. The
word to be completed is at C<< $words-E<gt>[$cword] >>.

Note that COMP_LINE includes the command name. If you want the command-line
arguments only (like in C<@ARGV>), you need to strip the first element from
C<$words> and reduce C<$cword> by 1.

See also:

=over

* L<Parse::CommandLine>

The module C<Parse::CommandLine> has a function called C<parse_command_line()>
which is similar, breaking a command-line string into words (in fact, currently
C<parse_cmdline()>'s implementation is stolen from this module). However,
C<parse_cmdline()> does not die on unclosed quotes and allows custom
word-breaking characters.

=back


=head2 parse_options(%args) -> [status, msg, result, meta]

Parse command-line for options and arguments, more or less like Getopt::Long.

Parse command-line into words using C<parse_cmdline()> then separate options and
arguments. Since this routine does not accept C<Getopt::Long> (this routine is
meant to be a generic option parsing of command-lines), it uses a few simple
rules to server the common cases:

=over

=item * After C<-->, the rest of the words are arguments (just like Getopt::Long).

=item * If we get something like C<-abc> (a single dash followed by several letters) it
is assumed to be a bundle of short options.

=item * If we get something like C<-MData::Dump> (a single dash, followed by a letter,
followed by some letters I<and> non-letters/numbers) it is assumed to be an
option (C<-M>) followed by a value.

=item * If we get something like C<--foo> it is a long option. If the next word is an
option (starts with a C<->) then it is assumed that this option does not have
argument. Otherwise, the next word is assumed to be this option's value.

=item * Otherwise, it is an argument (that is, permute is assumed).

=back

Arguments ('*' denotes required arguments):

=over 4

=item * B<cmdline> => I<str>

Command-line, defaults to COMP_LINE environment.

=item * B<cword> => I<array>

Alternative to passing `cmdline` and `point`.

If you already did a C<parse_cmdline()>, you can pass the cword result (the
second element) here to avoid calling C<parse_cmdline()> twice.

=item * B<point> => I<int>

Point/position to complete in command-line, defaults to COMP_POINT.

=item * B<words> => I<array>

Alternative to passing `cmdline` and `point`.

If you already did a C<parse_cmdline()>, you can pass the words result (the first
element) here to avoid calling C<parse_cmdline()> twice.

=back

Return value:

Returns an enveloped result (an array).

First element (status) is an integer containing HTTP status code
(200 means OK, 4xx caller error, 5xx function error). Second element
(msg) is a string containing error message, or 'OK' if status is
200. Third element (result) is optional, the actual result. Fourth
element (meta) is called result metadata and is optional, a hash
that contains extra information.

 (hash)

=head1 TODOS

format_completion(): Accept regex for path_sep.

=head1 SEE ALSO

Other modules related to bash shell tab completion: L<Bash::Completion>,
L<Getopt::Complete>. L<Term::Bash::Completion::Generator>

Programmable Completion section in Bash manual:
L<https://www.gnu.org/software/bash/manual/html_node/Programmable-Completion.html>


L<Complete>

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

perlancar <perlancar@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2014 by perlancar@cpan.org.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
