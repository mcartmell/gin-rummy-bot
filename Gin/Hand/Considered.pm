package Gin::Hand::Considered;
use Moose;
use List::Util qw(reduce sum);

extends 'Gin';
with 'Gin::Scoring';
with 'Gin::Printer';

has 'melds' => (
  isa      => 'ArrayRef',
  is       => 'rw',
  required => 1
);

has 'deadwood' => (
  isa      => 'ArrayRef',
  is       => 'rw',
  required => 1
);

sub highest_deadwood_card {
  my $self = shift;
  return $self->highest_card( $self->deadwood );
}

sub number_of_cards_in_melds {
  my $self = shift;
  return ( sum( map { scalar @$_ } @{ $self->melds } ) || 0 );
}

sub deadwood_score {
  my $self = shift;
  return $self->score_cards( $self->deadwood ) || 0;
}

sub print {
  my $self = shift;
  my $str  = "Melds: " . $self->print_card_sets( $self->melds ) . "\n";
  $str .= "Deadwood: "
    . $self->print_cards( $self->sort_cards( $self->deadwood ) ) . "\n";
  $str .= "Deadwood score: " . $self->deadwood_score . "\n";
  return $str;
}

1;
