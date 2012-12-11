package Gin::Log;
use Moose;

has 'full_log' => (
  isa     => 'Str',
  default => '',
  is      => 'rw'
);

sub print {
  my $self = shift;
  my $msg  = shift;
  $msg .= $/;
  print STDERR $msg;
  $self->full_log( $self->full_log . $msg );
}

1;
