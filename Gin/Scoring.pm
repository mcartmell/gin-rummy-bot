package Gin::Scoring;
use Moose::Role;
use List::Util qw(sum reduce);
use Carp qw(cluck);

with 'Gin::Constants';

sub score_cards {
  my $self  = shift;
  my $cards = shift;
  my $score = eval {
    sum( map { $self->values->{ $_->name } } @$cards );
  };
  if ($@) {
    warn Dumper($cards);
  }
  else {
    return $score;
  }
  use Data::Dumper;
}

sub highest_card {
  my $self  = shift;
  my $cards = shift;

  return reduce {
    $self->values->{ $a->name } > $self->values->{ $b->name } ? $a : $b;
  }
  @$cards;
}

sub lowest_card {
  my $self  = shift;
  my $cards = shift;
  return reduce {
    $self->values->{ $a->name } < $self->value->{ $b->name } ? $a : $b;
  }
  @$cards;
}

sub sort_cards {
  my $self  = shift;
  my $cards = shift;
  $cards = [ sort { $self->card_value($a) <=> $self->card_value($b) } @$cards ];
}

sub card_value {
  my $self = shift;
  my $card = shift;
  return $self->values->{ $card->name };
}

1;
