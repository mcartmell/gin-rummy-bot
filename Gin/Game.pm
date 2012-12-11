package Gin::Game;
use Moose;
use Games::Cards;

extends 'Gin';

has 'match' => (
  isa     => 'Gin::Match',
  is      => 'rw',
  handles => [qw/dealer players knock_score/]
);

has 'game' => (
  isa => 'Games::Cards::Game',
  is  => 'rw',
);

has 'deck' => (
  isa => 'Games::Cards::Deck',
  is  => 'rw',
);

has 'discard' => (
  isa => 'Games::Cards::Stack',
  is  => 'rw'
);

has 'is_running' => (
  isa     => 'Bool',
  is      => 'rw',
  default => 1
);

has 'winner' => (
  isa => 'Maybe[Gin::Player]',
  is  => 'rw'
);

sub BUILD {
  my $self = shift;
  $self->game(
    new Games::Cards::Game(
      {
        cards_in_suit => {
          "Ace"   => 1,
          2       => 2,
          3       => 3,
          4       => 4,
          5       => 5,
          6       => 6,
          7       => 7,
          8       => 8,
          9       => 9,
          10      => 10,
          "Jack"  => 11,
          "Queen" => 12,
          "King"  => 13,
        }
      }
    )
  );
  $self->deck( new Games::Cards::Deck( $self->game, 'Deck' ) );
  $self->discard( new Games::Cards::Stack( $self->game, 'Open Stack' ) );
  $self->deck->shuffle;
  for my $player ( values %{ $self->match->players } ) {
    $player->hand(
      new Games::Cards::Hand( $self->game, $player->name . "'s hand" ) );
    $self->deck->give_cards( $player->hand, 10 );
  }
  $self->deck->give_cards( $self->discard, 1 );
}

sub start {
  my $self = shift;
  $self->winner(undef);
  for my $player ( $self->plist ) {
    $player->reset_state;
  }
  $self->dealer->other_player->state('take_or_pass');
  $self->dealer->state('wait');
}

sub current_player {
  my $self = shift;
  for my $player ( $self->plist ) {
    if ( $player->state ne 'wait' ) {
      return $player;
    }
  }
}

sub plist {
  my $self = shift;
  return ( values %{ $self->players } );
}

sub end_current_turn {
  my $self = shift;
  for my $player ( $self->plist ) {
    if ( $player->state eq 'wait' ) {
      $player->state('take');
    }
    else {
      $player->state('wait');
    }
  }
  $self->current_player->aprint("to go");
}

sub info {
  my $self = shift;
  my $str  = $self->dealer->name . " is the dealer\n";
  for my $player ( values %{ $self->players } ) {
    $str .= $player->name . ": \n";
    $player->hand->sort_by_value;
    $str .= "\tHand: " . $player->hand->print('short');
    $str .= "\tState: " . $player->state . "\n\n";
  }
  $str .= "Deck has " . $self->deck->size . " cards left\n";
  if ( $self->discard->size > 0 ) {
    $str .= "Top of discard is " . $self->discard->top_card->print('short');
  }
  return $str;
}

1;
