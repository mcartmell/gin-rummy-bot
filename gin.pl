#!perl

use strict;
use warnings;
use Gin::Web;
my $m = new Gin::Web('8082');
$m->run;
print "ok, running";
