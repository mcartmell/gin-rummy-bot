package Gin::Web;
use Moose;
use Gin::Match;
use Template;
extends 'HTTP::Server::Simple::CGI';
use HTTP::Server::Simple::Static;
use File::Basename qw(dirname);
use Cwd qw(abs_path);
use Module::Refresh;

my $BASE_DIR = abs_path( dirname(__FILE__) . "/.." );
my $IMG_DIR  = "$BASE_DIR/images";

my $template = q{
  <html>
  <head>
  <title>Gin</title>
  <style type="text/css">
  a { border: 0; text-decoration: none; }
  img { border: 0 }
  img#last_card_taken { border: 2px solid red }
  body { background: #efe }
  
  #main {
    float: left;
    width: 85%
  }
  #sidebar {
    background: #ddd;
    float: right;
    width: 15%;
    height: 100%;
  }
  
  </style>
  </head>
  <body>
  <div id="main">
  [% IF error %]
  <h1 style="color:red">[% error %]</h1>
  [% END %]
  <h1>
  [% IF game.winner %]
  [% game.winner.name %] wins!
  [% ELSE %]
  [% player.name %] vs [% player.other_player.name %]
  [% END %]
  </h1>
  <h3>State: [% player.state %]</h3>
  <p>
  [% IF player.state == "take_or_pass" %]
  <a href="/pass">pass</a><br />
  [% END %]
  <table>
  <tr>
  [% FOREACH card = player.hand.cards %]
  <td>
  [% IF player.state == "discard" %]
  <a href="/discard?discard_card=[% card.truename %]"><img src="images/[% card.truename FILTER lower %].gif" [% IF player.card_taken && card.truename == player.card_taken.truename %] id="last_card_taken" [% END %]></a>
  [% ELSE %]
  <img src="images/[% card.truename FILTER lower %].gif">
  [% END %]
  </td>
  [% END %]
  <tr>
  [% FOREACH card = player.hand.cards %]
  <td>
  [% IF player.state == "discard" %]
  [% SET card_value = card.value %]
  [% IF card_value > 10 %]
  [% SET card_value = 10 %]
  [% END %]
  [% IF deadwood_score - card_value <= game.knock_score %]
  <a href="/knock?knock_card=[% card.truename %]">knock</a>
  [% END %]
  [% END %]
  </td>
  [% END %]
  </tr>
  </table>
  </p>
  <p>
  <table style="margin-left: auto; margin-right: auto; width: 30%">
  <tr>
  <td>Stack</td>
  <td>Discard</td>
  </tr>
  <tr>
  <td>
  [% IF player.state == "take" || player.state == "take_stock" %]
  <a href = "/take_stock">
  <img src="images/b.gif">
  </a>
  [% ELSE %]
  <img src="images/b.gif">
  [% END %]
  </td>
  <td>
  [% IF game.discard.size > 0 %]
  [% IF player.state == "take" || player.state == "take_or_pass" %]
  <a href = "/take_discard">
  <img src="images/[% game.discard.top_card.truename FILTER lower %].gif">
  [% ELSE %]
  <img src="images/[% game.discard.top_card.truename FILTER lower %].gif">
  [% END %]
  [% ELSE %]
  <p>(empty)</p>
  [% END %]
  </a>
  </td>
  </tr>
  <tr>
  <td>[% game.deck.size %]</td>
  <td></td>
  </table>
  </p>
  <p>
  <h2>Deadwood: [% deadwood_score %]</h2>

  <h3>[% player.other_player.name %]'s hand:</h3>
  <p>
  
  [% FOREACH card = player.other_player.hand.cards %]
    [% UNLESS game.is_running && !cheat %]
  <img src="images/[% card.truename FILTER lower %].gif">
    [% ELSE %]
  <img src="images/b.gif">
    [% END %]
  [% END %]
  <br />
  [% IF player.other_player.took_discard_card %]
  <p>Took discarded card:<br />
  <img src="images/[% player.other_player.card_taken.truename FILTER lower %].gif">
  </p>
  [% END %]
  <a href="/new_round">Start a new round</a>
  </p>
  </div>
  <div id="sidebar">
  <h3>Log</h3>
  <p>
  [% FILTER html_line_break %]
  [% log %]
  [% END %]
  </p>
  </div>
  </body>
  </html>
};

override 'new' => sub {
  my $self = super;
  $self->BUILD;
  return $self;
};

has 'match' => (
  isa     => 'Gin::Match',
  is      => 'rw',
  handles => [qw/game/]
);

has 'hero' => (
  isa     => 'Gin::Player',
  is      => 'rw',
  handles => [qw/hand/]
);

my %dispatch = (
  show         => \&show,
  take_stock   => \&take_stock,
  take_discard => \&take_discard,
  knock        => \&knock,
  discard      => \&discard,
  pass         => \&pass,
  new_round    => \&new_round
);

sub BUILD {
  my $self = shift;
  $self->match( new Gin::Match );

  $self->match->players(
    {
      1 => new Gin::Player::Bot(
        name   => 'GinBot',
        number => 1,
        match  => $self->match
      ),
      2 => $self->hero(
        new Gin::Player(
          name   => 'Player',
          number => 2,
          match  => $self->match
        )
      )
    }
  );
  $self->match->start;
}

sub new_round {
  my $self = shift;
  $self->match->new_round;
  $self->show(@_);
}

sub take_stock {
  my $self = shift;
  $self->hero->take_from_stock;
  $self->show(@_);
}

sub take_discard {
  my $self = shift;
  $self->hero->take_from_discard;
  $self->show(@_);
}

sub discard {
  my $self            = shift;
  my $cgi             = shift;
  my $card_to_discard = $cgi->Vars->{'discard_card'};
  print STDERR "got $card_to_discard";
  $self->hero->discard($card_to_discard);
  $self->show($cgi);
}

sub knock {
  my $self       = shift;
  my $cgi        = shift;
  my $knock_card = $cgi->Vars->{knock_card};
  $self->hero->knock($knock_card);
  $self->show($cgi);
}

sub pass {
  my $self = shift;
  my $cgi  = shift;
  $self->hero->pass;
  $self->show($cgi);
}

sub handle_request {
  my $self = shift;
  $self->{error} = '';
  my $cgi = shift;
  my $path = substr( $cgi->path_info, 1 );
  $path ||= 'show';

  my $handler = $dispatch{$path};
	print "HTTP/1.0 200 OK\r\n";
  if ( defined $handler ) {
		print $cgi->header;
    eval { $handler->( $self, $cgi ); };
    if ($@) {
      $self->{error} = $@;
      $self->show;
    }
  }
  else {
    $self->serve_static( $cgi, $BASE_DIR, $path );
  }
}

sub show {
  my $self = shift;
  my $cgi  = shift;
  my $vars = {};
  if ( $self->match->is_running && $self->match->game->is_running ) {
    if ( $self->match->current_player->isa('Gin::Player::Bot') ) {
      $self->match->current_player->go;
    }
    $self->hero->hand->sort_by_value;
    my $handset      = $self->hero->find_melds( $self->hero->hand->cards );
    my $lowest_score = $handset->lowest_deadwood_score;
    $vars->{deadwood_score} = $lowest_score;

  }
  $vars->{game}   = $self->game;
  $vars->{player} = $self->hero;
  $vars->{log}    = (
    join "\n",
    grep { defined $_ }
      ( reverse split "\n", $self->match->full_log )[ 0 .. 15 ]
  );
  $vars->{error} = $self->{error};
  $vars->{cheat} = 0;
  my $tt = new Template;
  $tt->process( \$template, $vars ) or die $tt->error();

}

1;
