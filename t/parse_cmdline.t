#!perl

use 5.010;
use strict;
use warnings;
#use Log::Any '$log';

use Complete::Bash qw(parse_cmdline);
use Test::More;

sub _l {
    my $line = shift;
    my $point = index($line, '^');
    die "BUG: No caret in line <$line>" unless $point >= 0;
    $line =~ s/\^//;
    ($line, $point);
}

subtest "basic" => sub {
    is_deeply(parse_cmdline(_l(q|^aa|)), [['aa'], 0]);
    is_deeply(parse_cmdline(_l(q|a^a|)), [['aa'], 0]);
    is_deeply(parse_cmdline(_l(q|aa^|)), [['aa'], 0]);
    is_deeply(parse_cmdline(_l(q|aa ^|)), [['aa', ''], 1]);
    is_deeply(parse_cmdline(_l(q|aa b^|)), [['aa', 'b'], 1]);
    is_deeply(parse_cmdline(_l(q|aa b ^|)), [['aa', 'b', ''], 2]);
    is_deeply(parse_cmdline(_l(q|aa b c^|)), [['aa', 'b', 'c'], 2]);
};

subtest "whitespace before command" => sub {
    is_deeply(parse_cmdline(_l(q|  aa^|)), [['aa'], 0]);
};

subtest "middle" => sub {
    is_deeply(parse_cmdline(_l(q|aa b ^c|)), [['aa', 'b', 'c'], 2]);
    is_deeply(parse_cmdline(_l(q|aa b ^ c|)), [['aa', 'b', 'c'], 2]);
    is_deeply(parse_cmdline(_l(q|aa b ^  c|)), [['aa', 'b', '', 'c'], 2]);
};

subtest "escaped space" => sub {
    is_deeply(parse_cmdline(_l(q|aa b\\ ^|)), [['aa', 'b '], 1]);
    is_deeply(parse_cmdline(_l(q|aa b\\  ^|)), [['aa', 'b ', ''], 2]);
    is_deeply(parse_cmdline(_l(q|aa b\\ ^|), '', 1), [['aa', 'b\\ '], 1]);
    is_deeply(parse_cmdline(_l(q|aa b\\  ^|), '', 1), [['aa', 'b\\ ', ''], 2]);
};

subtest "double quotes" => sub {
    is_deeply(parse_cmdline(_l(q|aa "b c^|)), [['aa', 'b c'], 1]);
    is_deeply(parse_cmdline(_l(q|aa "b c ^|)), [['aa', 'b c '], 1]);
    is_deeply(parse_cmdline(_l(q|aa "b c'^|)), [['aa', 'b c\''], 1]);
    is_deeply(parse_cmdline(_l(q|aa "b c' ^|)), [['aa', 'b c\' '], 1]);
    is_deeply(parse_cmdline(_l(q|aa "b c\\"^|)), [['aa', 'b c"'], 1]);
    is_deeply(parse_cmdline(_l(q|aa "b c\\" ^|)), [['aa', 'b c" '], 1]);
    is_deeply(parse_cmdline(_l(q|aa "b c "^|)), [['aa', 'b c '], 1]);
    is_deeply(parse_cmdline(_l(q|aa "b c " ^|)), [['aa', 'b c ', ''], 2]);
};

subtest "double quotes (preserve quotes)" => sub {
    is_deeply(parse_cmdline(_l(q|aa "b c^|), '', 1), [['aa', '"b c'], 1]);
    is_deeply(parse_cmdline(_l(q|aa "b c ^|), '', 1), [['aa', '"b c '], 1]);
    is_deeply(parse_cmdline(_l(q|aa "b c'^|), '', 1), [['aa', '"b c\''], 1]);
    is_deeply(parse_cmdline(_l(q|aa "b c' ^|), '', 1), [['aa', '"b c\' '], 1]);
    is_deeply(parse_cmdline(_l(q|aa "b c\\"^|), '', 1), [['aa', '"b c\\"'], 1]);
    is_deeply(parse_cmdline(_l(q|aa "b c\\" ^|), '', 1), [['aa', '"b c\\" '], 1]);
    is_deeply(parse_cmdline(_l(q|aa "b c "^|), '', 1), [['aa', '"b c "'], 1]);
    is_deeply(parse_cmdline(_l(q|aa "b c " ^|), '', 1), [['aa', '"b c "', ''], 2]);
};

subtest "single quotes" => sub {
    is_deeply(parse_cmdline(_l(q|aa 'b c^|)), [['aa', 'b c'], 1]);
    is_deeply(parse_cmdline(_l(q|aa 'b c ^|)), [['aa', 'b c '], 1]);
    is_deeply(parse_cmdline(_l(q|aa 'b c"^|)), [['aa', 'b c"'], 1]);
    is_deeply(parse_cmdline(_l(q|aa 'b c" ^|)), [['aa', 'b c" '], 1]);
    is_deeply(parse_cmdline(_l(q|aa \\'b c^|)), [['aa', '\'b', 'c'], 2]);
    is_deeply(parse_cmdline(_l(q|aa 'b c '^|)), [['aa', 'b c '], 1]);
    is_deeply(parse_cmdline(_l(q|aa 'b c ' ^|)), [['aa', 'b c ', ''], 2]);
};

subtest "single quotes (preserve quotes)" => sub {
    is_deeply(parse_cmdline(_l(q|aa 'b c^|), '', 1), [['aa', '\'b c'], 1]);
    is_deeply(parse_cmdline(_l(q|aa 'b c ^|), '', 1), [['aa', '\'b c '], 1]);
    is_deeply(parse_cmdline(_l(q|aa 'b c"^|), '', 1), [['aa', '\'b c"'], 1]);
    is_deeply(parse_cmdline(_l(q|aa 'b c" ^|), '', 1), [['aa', '\'b c" '], 1]);
    is_deeply(parse_cmdline(_l(q|aa \\'b c^|), '', 1), [['aa', '\\\'b', 'c'], 2]);
    is_deeply(parse_cmdline(_l(q|aa 'b c '^|), '', 1), [['aa', '\'b c \''], 1]);
    is_deeply(parse_cmdline(_l(q|aa 'b c ' ^|), '', 1), [['aa', '\'b c \'', ''], 2]);
};

subtest "word breaks" => sub {
    is_deeply(parse_cmdline(_l(q|aa --bb=c^|)), [['aa', '--bb=c'], 1]);
    is_deeply(parse_cmdline(_l(q|aa --bb=c^|), ':='), [['aa', '--bb', '=', 'c'], 3]);
    is_deeply(parse_cmdline(_l(q|aa b:c=d^|), ':='), [['aa', 'b', ':', 'c', '=', 'd'], 5]);
    # backslash protects word break character
    is_deeply(parse_cmdline(_l(q|aa b\:c\=d^|), ':='), [['aa', 'b:c=d'], 1]);
    is_deeply(parse_cmdline(_l(q|aa b\:c\=d^|), ':=', 1), [['aa', 'b\\:c\\=d'], 1]);
    # quote protects word break character
    is_deeply(parse_cmdline(_l(q|aa "b:c=d^|), ':='), [['aa', 'b:c=d'], 1]);
    is_deeply(parse_cmdline(_l(q|aa "b:c=d^|), ':=', 1), [['aa', '"b:c=d'], 1]);
    is_deeply(parse_cmdline(_l(q|aa 'b:c=d^|), ':='), [['aa', 'b:c=d'], 1]);
    is_deeply(parse_cmdline(_l(q|aa 'b:c=d^|), ':=', 1), [['aa', '\'b:c=d'], 1]);
};

DONE_TESTING:
done_testing;
