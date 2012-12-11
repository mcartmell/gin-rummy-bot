package Gin::Player;
use Moose;
use Carp qw(croak);
use feature 'switch';
use Data::Dumper;
use List::Util qw(sum);

$| = 1;

extends 'Gin';
with 'Gin::AI';
with 'Gin::Scoring';

has 'match' => (
  isa     => 'Gin::Match',
  is      => 'rw',
  handles => [qw/game dealer players knock_score/]
);

has 'state' => (
  isa     => 'Str',
  is      => 'rw',
  default => 'wait'
);

has 'name' => (
  isa      => 'Str',
  is       => 'rw',
  required => 1
);

has 'hand' => (
  isa => 'Games::Cards::Hand',
  is  => 'rw',
);

has 'handset' => (
  isa     => 'Gin::HandSet',
  is      => 'rw',
  handles => [qw/lowest_deadwood_score/]
);

has 'number' => (
  isa      => 'Int',
  is       => 'rw',
  required => 1
);

has 'card_taken' => (
  isa => 'Games::Cards::Card',
  is  => 'rw',
);

has 'took_discard_card' => (
  isa => 'Bool',
  is  => 'rw'
);

sub go {
  my $self = shift;
  $self->pre_turn;
  $self->make_move;
}

sub reset_state {
  my $self = shift;
  $self->took_discard_card(0);
}

sub pre_turn {
  my $self = shift;
  print STDERR "*** " . $self->name . "'s turn ***\n";
  print STDERR $self->game->info . "\n";
  $self->handset( $self->find_melds( $self->hand->cards ) );

  my $x = 0;
  my ( $low_score, $best_hand ) = $self->handset->lowest_deadwood_score;
  print STDERR $best_hand->print;
  print STDERR $/;
}

sub make_move {
  my $self = shift;
  print "\nAction? ";
  my $action = <STDIN>;

  eval {
    given ($action)
    {
      when (/^td/)      { $self->take_from_discard };
      when (/^ts/)      { $self->take_from_stock };
      when (/^p/)       { $self->pass };
      when (/^d (\w+)/) { $self->discard($1) };
      when (/^k (\w+)/) { $self->knock($1) };
      when (/^q/)       { exit };
    }
  };
  warn $@ if $@;
}

sub take_from_discard {
  my $self = shift;
  if ( $self->state eq 'take' || $self->state eq 'take_or_pass' ) {
    $self->game->discard->give_cards( $self->hand, 1 );
    $self->card_taken( $self->hand->cards->[-1] );
    $self->state('discard');
  }
  else {
    croak( "Can't take from discard in state " . $self->state );
  }
  $self->aprint("takes from discard pile");
  $self->took_discard_card(1);
}

sub aprint {
  my $self = shift;
  my $msg  = shift;
  $self->print( $self->name . " $msg" );
}

sub is_dealer {
  my $self = shift;
  return ( $self->number == $self->dealer->number );
}

sub other_player {
  my $self = shift;
  for my $player ( $self->game->plist ) {
    if ( $player->number != $self->number ) {
      return $player;
    }
  }
}

sub knock {
  my $self       = shift;
  my $knock_card = shift;
  my @remaining_hand =
    grep { $_->truename ne $knock_card } @{ $self->hand->cards };
  my $handset = $self->find_melds( \@remaining_hand );
  my ( $low_score, $low_hand ) = $handset->lowest_deadwood_score;
  if ( $low_score <= $self->knock_score ) {
    $self->discard($knock_card);
    $self->aprint("knocks with $knock_card (deadwood $low_score)");
    $self->aprint("wins the game");
    $self->game->winner($self);
    $self->game->is_running(0);
    $self->state('wait');
    $self->other_player->state('wait');
  }
  else {
    die "Can't knock at $low_score!";
  }
}

sub pass {

  # Weird beginning-of-game semantic:
  # First player (non-dealer) can only take from discard or pass
  # Second player (dealer) can then take from discard or pass
  # Third player (non-dealer) can only take from stock
  my $self = shift;
  if ( $self->state eq 'take_or_pass' ) {
    if ( $self->is_dealer ) {

      # Third player (non-dealer) must take from stock
      $self->other_player->state('take_stock');
    }
    else {

      # Second player (dealer) can take or pass
      $self->other_player->state('take_or_pass');
    }
    $self->state('wait');
  }
  $self->aprint("passes");
  $self->other_player->aprint("to go");
}

sub take_from_stock {
  my $self = shift;
  if ( $self->state eq 'take' || $self->state eq 'take_stock' ) {
    $self->game->deck->give_cards( $self->hand, 1 );
    $self->card_taken( $self->hand->cards->[-1] );
    $self->state('discard');
  }
  else {
    croak "Can't take from stock in state " . $self->state;
  }
  $self->aprint("takes from the stock");
  $self->took_discard_card(0);
}

sub discard {
  my $self            = shift;
  my $card_to_discard = shift;
  if ( $self->state eq 'discard' ) {
    unless (
      $self->hand->give_a_card( $self->game->discard, $card_to_discard ) )
    {
      croak("You don't have that card");
    }
    $self->aprint("discards $card_to_discard");
    $self->game->end_current_turn;
  }
  else {
    croak( "Can't discard in state " . $self->state );
  }
}

sub top_card {
  my $self = shift;
  return $self->game->discard->top_card;
}

1;

