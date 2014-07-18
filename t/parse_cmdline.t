#!perl

use 5.010;
use strict;
use warnings;
#use Log::Any '$log';

use Complete::Bash qw(parse_cmdline);
use Test::More;

is_deeply(
    parse_cmdline("foo bar baz qux", 0),
    [[qw/bar baz qux/], 0],
    "simple 1",
);
is_deeply(
    parse_cmdline("foo bar baz qux", 3),
    [[qw/bar baz qux/], 0],
    "simple 2",
);
is_deeply(
    parse_cmdline("foo bar baz qux", 4),
    [[qw/baz qux/], 0],
    "simple 3",
);
is_deeply(
    parse_cmdline("foo bar --baz=2 qux", 4, "="),
    [[qw/--baz 2 qux/], 0],
    "word_breaks 1",
);

# more tests in Rinci metadata's examples

done_testing;
