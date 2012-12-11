package Gin::HandSet;
use Moose;

extends 'Gin';

has 'hands' => (
  isa        => 'ArrayRef',
  is         => 'rw',
  required   => 1,
  auto_deref => 1
);

sub lowest_deadwood_score {
  my $self = shift;
  my ( $min_score, $min_hand );
  for my $hand ( $self->hands ) {
    my $deadwood_score = $hand->deadwood_score;
    if ( !defined $min_score || $deadwood_score < $min_score ) {
      $min_hand  = $hand;
      $min_score = $deadwood_score;
    }
  }
  return wantarray ? ( $min_score, $min_hand ) : $min_score;
}

1;
