package Gin::Player::Bot;
use Moose;
extends 'Gin::Player';

override 'make_move' => sub {
  my $self = shift;
  if ( $self->state eq 'take_stock' ) {
    $self->take_from_stock;
    return $self->discard_a_card;
  }
  my ( $lowest_score, $best_hand ) = $self->lowest_deadwood_score;

  # Try adding the discard card
  my @new_cards = ( @{ $self->hand->cards }, $self->top_card );
  my $new_handset = $self->find_melds( \@new_cards );
  my $best_action;

  # Take from discard if it forms a meld or if we can knock with it
  for my $hand ( $new_handset->hands ) {
    my $new_hand_score =
      $hand->deadwood_score -
      $self->values->{ $hand->highest_deadwood_card->name };

    if ( $new_hand_score < $lowest_score ) {
      if ( $new_hand_score < $lowest_score - 7 ) {
        $best_action = 'take_from_discard';
      }

      print STDERR
        "Hey, we can get $new_hand_score by taking the top card and discarding "
        . $hand->highest_deadwood_card->print . "\n";
      if (
        $hand->number_of_cards_in_melds > $best_hand->number_of_cards_in_melds )
      {
        $best_action = 'take_from_discard';
        print STDERR "And it forms a meld!\n";
      }
      else {
        if ( $new_hand_score < $self->knock_score ) {
          $best_action = 'take_from_discard';
        }
      }

    }
  }
  unless ($best_action) {
    $best_action = 'take_from_stock';
  }
  my $cmd = "try_$best_action";
  $self->$cmd;
  $self->discard_a_card unless $self->state eq 'wait';
};

sub try_take_from_discard {
  my $self = shift;
  warn "  TAKING FROM DISCARD";
  $self->take_from_discard;
}

sub try_take_from_stock {
  my $self = shift;
  warn "  TAKING FROM STOCK";
  if ( $self->state eq 'take_or_pass' ) {
    $self->pass;
  }
  else {
    $self->take_from_stock;
  }
}

sub discard_a_card {
  my $W_CARD_1              = 30;
  my $W_CARD_2              = 5;
  my $W_CARD_SAME           = 25;
  my $W_CARD_VALUE          = 40;
  my $value_rand_multiplier = rand(0.4) + 0.6;
  $W_CARD_VALUE *= $value_rand_multiplier;

  #warn "using $W_CARD_VALUE for the weight";
  my $self        = shift;
  my $new_handset = $self->find_melds( $self->hand->cards );
  my ( $score, $best_hand ) = $new_handset->lowest_deadwood_score;
  my $melds = $best_hand->melds;

  # Only consider deadwood cards or cards in big melds for distance / similarity
  my @other_cards = @{ $best_hand->deadwood },
    grep { length(@$_) > 3 } @{$melds};

  #warn "considering:  ".join ', ', map { $_->truename } @other_cards;
  my %potential;
  my %lost_cards;
  my %is_in_meld;
  @lost_cards{ map { $_->truename } @{ $self->game->discard->cards } } =
    (1) x $self->game->discard->size;
  for my $card ( map { @$_ } @{ $best_hand->melds } ) {
    $is_in_meld{ $card->truename } = 1;
  }
  for my $hand ( $new_handset->hands ) {

    for my $card ( @{ $hand->deadwood } ) {
      my $this_score = $hand->deadwood_score - $self->values->{ $card->name };
      if ( !defined $potential{ $card->truename }
        || $this_score < $potential{ $card->truename }->{new_score} )
      {
        $potential{ $card->truename } =
          { new_score => $this_score, card => $card };
      }
    }
  }

  for my $card ( @{ $self->hand->cards } ) {
    my @ocards = grep { $_->truename ne $card->truename } @other_cards;
    $potential{ $card->truename } ||= { card => $card };
    my $e = $potential{ $card->truename };

    # forget about cards in melds

    my $keep_score;

    # to consider:
    # cards within 1 or 2 (for making runs)
    # - modified by remaining cards of that suit
    #warn "ON ".$card->truename;
    my @cards_within_1 = $self->cards_within_distance( 1, $card, \@ocards );
    my @cards_within_2 = $self->cards_within_distance( 2, $card, \@ocards );

    my @lost_cards_within_2 =
      $self->cards_within_distance( 2, $card, $self->game->discard->cards );

    #warn "  ".@cards_within_1." cards within 1";
    #warn "  ".@cards_within_2." cards within 2";

    $keep_score += $W_CARD_1
      if @cards_within_1;    # +15 if we've got an immediate run of 2
    $keep_score +=
      ( (@cards_within_2) * $W_CARD_2 );    # +15 if we have 2 cards within 2

#print STDERR $card->truename." has ".(@cards_within_1 - 1). " cards within 1\n";
#print STDERR $card->truename." has ".(@cards_within_2 - 1). " cards within 2\n";

    # cards of same value (for making sets)
    my @cards_of_same_value = $self->cards_of_value( $card, \@ocards );

    #warn "  ".@cards_of_same_value." cards of same value";

    my @lost_cards_of_same_value =
      $self->cards_of_value( $card, $self->game->discard->cards );

#warn "  ".@lost_cards_of_same_value."  lost cards of this value";
#print STDERR $card->truename." has ".(@cards_of_same_value - 1). " cards of the same value\n";
    $keep_score +=
      ( $W_CARD_SAME - ( @lost_cards_of_same_value * ( $W_CARD_SAME / 2 ) ) )
      if (@cards_of_same_value);

    # card value
    # - modified by number of cards remaining
    $keep_score +=
      ( $W_CARD_VALUE /
        ( $self->values->{ $card->name } * ( $W_CARD_VALUE / 10 ) ) );
    $e->{discard_score} = 100 - $keep_score;
    if ( $is_in_meld{ $card->truename } ) {

      # big penalty for melded cards
      $e->{discard_score} -= 50;
    }

    # - modified by remaining cards of that value

  }

  my @potential =
    sort { $b->{discard_score} <=> $a->{discard_score} } values %potential;
  my @knock_cards =
    grep { defined $_->{new_score} && $_->{new_score} <= $self->knock_score }
    @potential;
  if (@knock_cards) {
    warn $knock_cards[0]->{new_score};

    # if we can knock, just do it!
    return $self->knock( $knock_cards[0]->{card}->truename );
  }
  for ( sort keys %potential ) {
    print STDERR "$_ -> $potential{$_}{discard_score}\n";
  }
  my $discard_card = $potential[0]->{card};
  warn "  DISCARDING " . $discard_card->truename;
  $self->discard( $discard_card->truename );
}

1;
