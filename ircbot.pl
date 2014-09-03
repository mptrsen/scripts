#!/usr/bin/perl
use strict;
use warnings;
use autodie;

use Bot::BasicBot;

print "Call: $0 @ARGV\n";

my $server  = shift @ARGV;
my $channel = shift @ARGV or die  "Need a channel name!\n";

my $botname = 'Frida';

my $bot = HelpBot->new(
	server   => shift @ARGV || '131.220.75.133',
	port     => 6667,
	nick     => $botname,
	username => $botname,
	name     => "Boten $botname",
	channels => [$channel],
);

$bot->run();

package HelpBot;

use base qw( Bot::BasicBot );

my $msgcnt = 0;

sub query {
	$_[0] eq 'pubmed'  && return "http://www.ncbi.nlm.nih.gov/pubmed/?term=$_[1]";
	$_[0] eq 'jfgi'    && return "jfgi... http://lmgtfy.com/?q=$_[1]";
	$_[0] eq 'perldoc' && return "http://perldoc.perl.org/search.html?q=$_[1]";
	$_[0] eq 'wiki'    && return "http://en.wikipedia.org/w/index.php?search=$_[1]&fulltext=Search";
	$_[0] eq 'g'       && return "https://www.google.de/search?q=$_[1]&ie=utf-8&oe=utf-8";
};

sub said {
	my ($self, $msg) = @_;

	$msgcnt++;

	# starts with a ?something, is a query
	if ($msg->{body} =~ /^\?([a-zA-Z]+) (.+)/) {
		my $type  = $1;
		my $query = $2;

		$query =~ s/"/%22/g;  # replace quotes with %22
		$query =~ s/\s+/+/g;  # replace spaces with + for the query

		$self->say( channel => $msg->{channel}, body => query($type, $query) );
	}

	# starts with !slap, is a slap request
	elsif ($msg->{body} =~ /^!slap (.+)/) {
		$self->emote( channel => $msg->{channel}, body => sprintf(random_slap(), $1));
	}

	# ends with botname?, is probably a help request
	elsif ($msg->{body} =~ /$botname\?/i) {
		$self->say( channel => $msg->{channel}, body => 'I facepalm occasionally. Type "?jfgi whatever" or "?pubmed whatever" or "?perldoc whatever" or "?wiki whatever" or "?g whatever". "!slap someone" also works.');
	}

	# was addressed directly, dunno the answer
	elsif ($msg->{address} and $msg->{body} =~ /\?/) {
		$self->say( channel => $msg->{channel}, body => 'keine ahnung, ich kann doch nicht alles wissen :P' );
	}

	elsif ($msg->{body} =~ /\._\./) {
		$self->emote( channel => $msg->{channel}, body => 'taetschelt ' . $msg->{who} . ' den kopf' );
	}

	# contains kaffee or coffee, needs comment :D
	elsif ($msg->{body} =~ /\b(kaffee|coffee)\b/i and occasion(2)) {
		$self->say( channel => $msg->{channel}, body => 'du trinkst dauernd kaffee. kannst ja auch mal den automaten saubermachen :P');
	}

	# sometimes just facepalm
	else {
		if ($msgcnt % 20 == 0 && occasion(64)) {
			$self->say( channel => $msg->{channel}, body => random_emote());
		}
	}
}

sub occasion {
	if (int(time) % $_[0] == 0) { return 1 }
}

sub random_slap {
	my $slaps = [
		"slaps %s around a bit with a large trout",
		"smacks %s with a MAKER bug list",
		"whips %s with a wet noodle",
		"threatens %s with pictures of Nicolas Cage",
		"slaps %s around with a 500 lbs UNIX manual",
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
	return int(rand(7200));
}
