#!perl

use 5.010;
use strict;
use warnings;
#use Log::Any '$log';

use Complete::Bash qw(format_completion);
use Test::More;

subtest "accepts array too" => sub {
    is(format_completion([qw/a b c/]), "a\nb\nc\n");
};

subtest "escmode default" => sub {
    is(format_completion({completion=>['a /:$']}),
       "a\\ /:\\\$\n");
};

subtest "escmode none" => sub {
    is(format_completion({completion=>['a /:$'], escmode=>'none'}),
       "a /:\$\n");
};

subtest "escmode shellvar" => sub {
    is(format_completion({completion=>['a /:$'], escmode=>'shellvar'}),
       "a\\ /\\:\$\n");
};

subtest "as array" => sub {
    is_deeply(format_completion({completion=>['a ','b'], as=>'array'}),
              ["a\\ ",'b']);
};

subtest "path_sep /" => sub {
    is(format_completion({completion=>['a/'], path_sep=>'/'}),
       "a/\na/\\ \n");
    is(format_completion({completion=>['a/', 'b/'], path_sep=>'/'}),
       "a/\nb/\n");
};

subtest "path_sep ::" => sub {
    is(format_completion({completion=>['a/'], path_sep=>'::'}),
       "a/\n");
    is(format_completion({completion=>['a::'], path_sep=>'::'}),
       "a::\na::\\ \n");
    is(format_completion({completion=>['a::', 'b::'], path_sep=>'::'}),
       "a::\nb::\n");
};

DONE_TESTING:
done_testing;
