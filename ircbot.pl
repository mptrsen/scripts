#!/usr/bin/perl
use strict;
use warnings;
use autodie;

use Bot::BasicBot;

print "Call: $0 @ARGV\n";

my $botname = 'Frida';
my $botfullname = "Boten $botname";

$0 = $botname;

my $default_server  =  'localhost';
my $default_channel = '#gbr';

my $server  = shift @ARGV or warn "Server name or address required, falling back to $default_server\n";
my $channel = shift @ARGV or warn "Channel name required, falling back to $default_channel\n";

my $bot = HelpBot->new(
	server   => $server || $default_server,
	port     => 6667,
	nick     => $botname,
	username => $botname,
	name     => $botfullname,
	channels => [ $channel || $default_channel ],
);

my $facts = RandomFact->new();

$bot->run();


package HelpBot;

use base qw( Bot::BasicBot );

our $msgcnt = 0;
our $today = 1;

sub answer {
	$_[0] eq 'pubmed'  && return "http://www.ncbi.nlm.nih.gov/pubmed/?term=$_[1]";
	$_[0] eq 'jfgi'    && return "jfgi... http://lmgtfy.com/?q=$_[1]";
	$_[0] eq 'perldoc' && return "http://perldoc.perl.org/search.html?q=$_[1]";
	$_[0] eq 'wiki'    && return "http://en.wikipedia.org/w/index.php?search=$_[1]&fulltext=Search";
	$_[0] eq 'g'       && return "https://www.google.de/search?q=$_[1]&ie=utf-8&oe=utf-8";
	$_[0] eq 'mensa'   && return "http://www.studentenwerk-bonn.de/gastronomie/speiseplaene/diese-woche/";
	$_[0] eq 'bistro'  && return "http://www.kartoffel-catering.de/bistro-2/speiseplan";
	return "I have no idea what you want from me."
};

sub help {
	return 'I facepalm occasionally. Try "?jfgi whatever" or "?pubmed whatever" or "?perldoc whatever" or "?wiki whatever" or "?g whatever". "?mensa", "?bistro" and "!slap someone" also work.';
}

sub emoted {
	my ($self, $msg) = @_;
	if ($msg->{body} =~ /$botname/i) {
		$self->reply( $msg, 'wtf?' );
	}
}

sub said {
	my ($self, $msg) = @_;

	$msgcnt++;

	# say hi on first msg
	my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
	if (!$today or $today != $mday) {
		sleep 1;
		$self->say( channel => $msg->{channel}, body => 'guten morgen zusammen!' );
		# and update the facts list
		$facts->update();
		$today = $mday;
	}

	# starts with a ?something, is a query
	if ($msg->{body} =~ /^\?([a-zA-Z]+)( (.+))?/) {
		my $type  = $1;
		if ($3) {
			my $query = $3;

			$query =~ s/"/%22/g;  # replace quotes with %22
			$query =~ s/\s+/+/g;  # replace spaces with + for the query

			$self->reply( $msg, answer($type, $query) );
		}
		else {
			$self->reply( $msg, answer($type) );
		}
	}

	# starts with !slap, is a slap request
	elsif ($msg->{body} =~ /^!slap (.+)/) {
		$self->emote( channel => $msg->{channel}, body => sprintf(random_slap(), $1));
	}

	# ends with botname?, is probably a help request
	elsif ($msg->{body} =~ /$botname\?/i) {
		$self->say( channel => $msg->{channel}, body => help() );
	}

	# was addressed directly, dunno the answer
	elsif ($msg->{address} and $msg->{body} =~ /\?/) {
		sleep 1;
		$self->say( channel => $msg->{channel}, body => 'keine ahnung, ich kann doch nicht alles wissen :P' );
	}

	# someone ._.'d, comfort them
	elsif ($msg->{body} =~ /\._\./) {
		sleep 1;
		$self->emote( channel => $msg->{channel}, body => 'taetschelt ' . $msg->{who} . ' den kopf' );
	}

	# contains kaffee or coffee, needs comment :D
	elsif ($msg->{body} =~ /\b(kaffee|coffee)\b/i and occasion(2)) {
		sleep 1;
		$self->say( channel => $msg->{channel}, body => 'du trinkst dauernd kaffee. kannst ja auch mal den automaten saubermachen :P');
	}

	# sometimes just facepalm
	else {
		if (occasion(128)) {
			sleep 1;
			$self->say( channel => $msg->{channel}, body => random_emote());
		}
		elsif (occasion(129)) {
			sleep 4;
			$self->say( channel => $msg->{channel}, body => random_fact() );
		}
	}
}

sub occasion {
	if (int(time) % $_[0] == 0) { return 1 }
}

sub random_fact {
	return 'did you know that ' . $facts->fact() . '?';
}

sub random_slap {
	my $slaps = [
		"slaps %s around a bit with a large trout",
		"smacks %s with a MAKER bug list",
		"whips %s with a wet noodle",
		"threatens %s with pictures of Nicolas Cage",
		"punches %s with a 500 lbs UNIX manual",
		"beats %s over the head with the Camel book",
	];
	return $slaps->[rand @$slaps];
}

sub random_emote {
	my $emote = [
	 '*facepalm*',
	 '*giggles*',
	 '*wails in sympathy*',
	];
	return $emote->[rand @$emote];
}

sub tick {
	my $self = shift;
	$self->say( { who => 'hannah', channel => 'msg', body => 'malte says he loves you.' } );
	return 3600 + int(rand(7200));
}


=head1 NAME

RandomFact

=head1 DESCRIPTION

A class to get random facts of the day from uselessfacts.net.  It can download
a fact list using an ugly curl pipeline and return a random fact at request.

=head1 SYNOPSIS

  my $facts = RandomFact->new()
  print 'did you know that ', $facts->fact(), "?\n";

=cut

package RandomFact;

sub new {
	my $class = shift;
	my $self  = { };
	bless $self, $class;
	return $self;
}

sub update {
	my $self = shift;
	# fetch the fact list for today
	my @factlist = `curl -s http://uselessfacts.net/category/facts-of-the-day/ | grep -A 1 "facttext" | grep "<p>" | sed -e "s#<p>##" -e "s#</p>##"`;
	chomp @factlist;
	$self->{'factlist'} = \@factlist;
	return $self->has_facts();
}

sub fact {
	my $self = shift;
	my $nfacts = $self->has_facts();
	if ( not defined $nfacts) { $nfacts = $self->update() }
	my $i = int( rand( $nfacts ) );
	my $fact = $self->{'factlist'}->[$i];
	$fact =~ s/^(.)/\l$1/;
	$fact =~ s/\.$//;
	return $fact;
}

sub all_facts {
	my $self = shift;
	if (! $self->has_facts() ) { $self->update() }
	return $self->{'factlist'};
}

sub has_facts {
	my $self = shift;
	if ( not defined $self->{'factlist'} ) { $self->update() }
	return scalar @{$self->{'factlist'}};
}
