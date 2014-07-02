#!perl

use 5.010;
use strict;
use warnings;
#use Log::Any '$log';

use Complete::Bash;
use Test::More;

is_deeply(Complete::Bash::break_cmdline_into_words(q[]), [qw//]);
is_deeply(Complete::Bash::break_cmdline_into_words(q[a]), [qw/a/]);
is_deeply(Complete::Bash::break_cmdline_into_words(q[a b ]), [qw/a b/]);
is_deeply(Complete::Bash::break_cmdline_into_words(q[ a b]), [qw/a b/]);
is_deeply(Complete::Bash::break_cmdline_into_words(q[a "b c"]), ["a", "b c"]);
is_deeply(Complete::Bash::break_cmdline_into_words(q[a "b c]), ["a", "b c"]);
is_deeply(Complete::Bash::break_cmdline_into_words(q[a 'b "c']), ['a', 'b "c']);
is_deeply(Complete::Bash::break_cmdline_into_words(q[a\ b]), ["a b"]);

done_testing;
