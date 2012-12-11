package Gin::AI;
use Moose::Role;
use Gin::HandSet;
use Gin::Hand::Considered;

sub find_melds {
  my $self    = shift;
  my $cardset = shift;
  my %cards   = map { $_ => $_ } @$cardset;
  my @cards   = $self->sort_cards( values %cards );
  my %seen;
  for my $i ( 0 .. $#cards ) {
    my %cards_copy = %cards;
    delete $cards_copy{ $cards[$i] };
    my ( $melds, $dead, $hands ) =
      $self->find_melds_for_card( $cards[$i], [], [], \%cards_copy, [] );
    if ( grep { !defined $_ } @$dead ) {
      warn "undef in dead";
    }
    for my $hand ( @$hands, [ $melds, $dead ] ) {
      my $melds = $hand->[0];

      # get the melds ordered
      my @cardsorted_melds = map { [ $self->sort_cards(@$_) ] } @$melds;

      # now sort the melds themselves (by their lowest card)
      my @sorted_melds = sort {
             $a->[0]->suit_value <=> $b->[0]->suit_value
          || $a->[0]->value <=> $b->[0]->value
      } @cardsorted_melds;

      # now get a key for them
      my $handstr = join '-', map {
        my $cards = $_;
        join '', map { $_->print } @$cards
      } @sorted_melds;
      $seen{$handstr} = $hand;
    }
  }
  my $handset = Gin::HandSet->new(
    hands => [
      map {
        Gin::Hand::Considered->new(
          melds    => $_->[0],
          deadwood => $_->[1]
          )
        } values %seen
    ]
  );
  return $handset;
}

sub sort_cards {
  my $self  = shift;
  my @cards = @_;
  return
    sort { $a->suit_value <=> $b->suit_value || $a->value <=> $b->value }
    @cards;
}

sub find_melds_for_card {
  my $self            = shift;
  my $card            = shift;
  my $melds           = shift;
  my $dead_cards      = shift;
  my $remaining_cards = shift;
  my $hands           = shift;
  my $next_lowest;
  my $found_set;
  my ( $rest_melds, $rest_dead_cards );
  my $rest_hands = [];
  $dead_cards = [@$dead_cards];
  $hands      = [@$hands];

  unless ( values %$remaining_cards ) {
    push @$dead_cards, $card if defined $card;
    return ( $melds, $dead_cards, $hands );
  }
  my @new_hands;

  #TODO: get all the hands with melds and hash them in some way
  # like this:
  # 1) if we have a set, recurse to find total melds for that hand
  # 2) if we have a run, do the same

  # 2) get all the runs for this card
  if ( my @set = $self->get_set_for_card( $card, $remaining_cards ) ) {
    $found_set = 1;
    my %rem_cards_copy = %$remaining_cards;
    delete @rem_cards_copy{@set};
    my @sorted_cards = $self->sort_cards( values %rem_cards_copy );

    $next_lowest = shift @sorted_cards || undef;
    delete $rem_cards_copy{$next_lowest} if $next_lowest;
    ( $rest_melds, $rest_dead_cards, $rest_hands ) =
      $self->find_melds_for_card( $next_lowest, [ @$melds, \@set ],
      $dead_cards, \%rem_cards_copy, $hands );
    push @new_hands, [ $rest_melds, $rest_dead_cards ];
  }

  if ( my @run = $self->get_runs_for_card( $card, $remaining_cards ) ) {
    my %rem_cards_copy = %$remaining_cards;
    delete @rem_cards_copy{@run};
    my @sorted_cards = $self->sort_cards( values %rem_cards_copy );

    $next_lowest = shift @sorted_cards || undef;
    delete $rem_cards_copy{$next_lowest} if $next_lowest;
    ( $rest_melds, $rest_dead_cards, my $run_hands ) =
      $self->find_melds_for_card( $next_lowest, [ @$melds, \@run ],
      $dead_cards, \%rem_cards_copy, [ @$hands, @new_hands ] );

    # If we have both a set and a run from this card, we need to remember it
    return ( $rest_melds, $rest_dead_cards, [@$run_hands] );
  }
  else {
    if ($found_set) {
      return ( $rest_melds, $rest_dead_cards, $rest_hands );
    }
  }

  push @$dead_cards, $card if defined $card;
  my @sorted_cards = $self->sort_cards( values %$remaining_cards );

  my $next_lowest_card = shift @sorted_cards;
  delete $remaining_cards->{$next_lowest_card};
  return (
    $self->find_melds_for_card(
      $next_lowest_card, $melds, $dead_cards, $remaining_cards, $hands
    )
  );

}

sub get_set_for_card {
  my $self            = shift;
  my $card            = shift;
  my $remaining_cards = shift;
  my @set = grep { $_->value == $card->value } ( values %$remaining_cards );
  if ( @set > 1 ) {
    return ( $card, @set );
  }
  else {
    return;
  }
}

sub get_runs_for_card {
  my $self                 = shift;
  my $card                 = shift;
  my $remaining_cards_orig = shift;
  my @run_so_far           = $card;
  my $remaining_cards      = {%$remaining_cards_orig};
  my @cards_not_considered = values %$remaining_cards;

  while (1) {
    my $last_card = $run_so_far[-1];
    if (
      my ($next_card) = grep {
             $_->suit eq $last_card->suit
          && $_->value == $last_card->value + 1
      } @cards_not_considered
      )
    {
      push @run_so_far, $next_card;
      delete $remaining_cards->{$next_card};
      @cards_not_considered = values %$remaining_cards;
    }
    else {
      last;
    }
  }
  if ( @run_so_far > 2 ) {
    return @run_so_far;
  }
  else {
    return;
  }
}

sub cards_of_value {
  my $self  = shift;
  my $card  = shift;
  my $cards = shift;
  warn "  considering " . @$cards . " cards";
  return grep { $_->value == $card->value } @$cards;
}

sub cards_within_distance {
  my $self        = shift;
  my $distance    = shift;
  my $card        = shift;
  my $cards       = shift;
  my $lower_limit = $card->value - $distance;
  my $upper_limit = $card->value + $distance;
  return grep {
         $_->suit_value == $card->suit_value
      && $_->value >= $lower_limit
      && $_->value <= $upper_limit
  } @$cards;
}

1;
