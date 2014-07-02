#!perl

use 5.010;
use strict;
use warnings;

use Test::More 0.98;

use Complete::Bash qw(mimic_dir_completion);

test_complete(
    completion => [],
    result     => [],
);
test_complete(
    completion => ['a', 'a/'],
    result     => ['a', 'a/'],
);
test_complete(
    completion => ['a'],
    result     => ['a'],
);
test_complete(
    completion => ['a/'],
    result     => ['a/', 'a/ '],
);
test_complete(
    completion => ['a.'],
    sep        => '.',
    result     => ['a.', 'a. '],
);

wDONE_TESTING:
done_testing;

sub test_complete {
    my (%args) = @_;

    my $name = $args{name} // join(",", @{ $args{completion} });
    my $res = Complete::Bash::mimic_dir_completion($args{completion}, $args{sep});
    is_deeply($res, $args{result}, "$name (result)")
        or diag explain($res);
}
