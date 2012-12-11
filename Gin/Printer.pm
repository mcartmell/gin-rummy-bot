package Gin::Printer;
use Moose::Role;

sub print_cards {
  my $self  = shift;
  my $cards = shift;

  my $str = eval {
    join '', map { $_->print } @$cards;
  };
  if ($@) {
    print Dumper($cards);
    use Data::Dumper;
  }
  else {
    return $str;
  }
}

sub print_card_sets {
  my $self     = shift;
  my $cardsets = shift;
  return join ' - ', map { $self->print_cards($_) } @$cardsets;
}

1;
