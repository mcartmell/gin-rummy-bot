package Gin;
use Moose;
use Gin::Log;

my $log;

has 'log' => (
  isa     => 'Gin::Log',
  is      => 'rw',
  handles => [qw/print full_log/]
);

sub BUILD {
  my $self = shift;
  $log ||= new Gin::Log;
  $self->log($log);
}

require 5.10.0;
1;
