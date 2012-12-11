package Gin::Match;

use Moose;
use Gin::Game;
use Gin::Player;
use Gin::Player::Bot;

extends 'Gin';

has 'knock_score' => (
  isa     => 'Int',
  is      => 'ro',
  default => 10
);

has 'scorelimit' => (
  isa => 'Int',
  is  => 'rw'
);

has 'game' => (
  isa     => 'Gin::Game',
  is      => 'rw',
  handles => [qw/current_player/]
);

has 'dealer' => (
  isa => 'Gin::Player',
  is  => 'rw'
);

has 'players' => (
  isa        => 'HashRef',
  is         => 'rw',
  default    => sub { {} },
  auto_deref => 0
);

has 'is_running' => (
  isa     => 'Bool',
  is      => 'rw',
  default => 0
);

sub start {
  my $self = shift;
  $self->create_players;
  $self->new_round;
  $self->is_running(1);
  $self->print("Match started");
}

sub new_round {
  my $self = shift;
  $self->game( new Gin::Game( match => $self ) );
  $self->dealer( $self->dealer->other_player );
  $self->game->start;
  $self->print("New round started");
  $self->print( $self->game->current_player->name . " to go" );
}

sub loop {
  my $self = shift;
  while ( $self->is_running ) {
    while ( $self->game->is_running ) {
      $self->game->current_player->go;
    }
    $self->new_round;
  }
}

sub finish {
  my $self = shift;
  $self->is_running(0);
}

sub create_players {
  my $self = shift;
  unless ( values %{ $self->players } == 2 ) {
    for ( 1 .. 2 ) {
      my $class = ( $_ == 1 ? 'Gin::Player::Bot' : 'Gin::Player' );
      my $player =
        $class->new( match => $self, name => "Player $_", number => $_ );
      $player->state('wait');
      $self->players->{$_} = $player;
    }
  }
  $self->dealer( $self->players->{1} );
}

1;
