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

our $msgcnt = 0;
our $today = 1;

sub query {
	$_[0] eq 'pubmed'  && return "http://www.ncbi.nlm.nih.gov/pubmed/?term=$_[1]";
	$_[0] eq 'jfgi'    && return "jfgi... http://lmgtfy.com/?q=$_[1]";
	$_[0] eq 'perldoc' && return "http://perldoc.perl.org/search.html?q=$_[1]";
	$_[0] eq 'wiki'    && return "http://en.wikipedia.org/w/index.php?search=$_[1]&fulltext=Search";
	$_[0] eq 'g'       && return "https://www.google.de/search?q=$_[1]&ie=utf-8&oe=utf-8";
	$_[0] eq 'mensa'   && return "http://www.studentenwerk-bonn.de/gastronomie/speiseplaene/diese-woche/";
	$_[0] eq 'bistro'  && return "http://www.kartoffel-catering.de/shared/menus/57/speiseplan.doc";
};

sub help {
	return 'I facepalm occasionally. Type "?jfgi whatever" or "?pubmed whatever" or "?perldoc whatever" or "?wiki whatever" or "?g whatever". "?mensa", "?bistro" and "!slap someone" also work.';
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
		$self->say( channel => $msg->{channel}, body => 'guten morgen zusammen!' );
		$today = $mday;
	}

	# starts with a ?something, is a query
	if ($msg->{body} =~ /^\?([a-zA-Z]+)( (.+))?/) {
		my $type  = $1;
		if ($3) {
			my $query = $3;

			$query =~ s/"/%22/g;  # replace quotes with %22
			$query =~ s/\s+/+/g;  # replace spaces with + for the query

			$self->reply( $msg, query($type, $query) );
		}
		else {
			$self->reply( $msg, query($type) );
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
		$self->say( channel => $msg->{channel}, body => 'keine ahnung, ich kann doch nicht alles wissen :P' );
	}

	# someone ._.'d, comfort them
	elsif ($msg->{body} =~ /\._\./) {
		$self->emote( channel => $msg->{channel}, body => 'taetschelt ' . $msg->{who} . ' den kopf' );
	}

	# contains kaffee or coffee, needs comment :D
	elsif ($msg->{body} =~ /\b(kaffee|coffee)\b/i and occasion(2)) {
		$self->say( channel => $msg->{channel}, body => 'du trinkst dauernd kaffee. kannst ja auch mal den automaten saubermachen :P');
	}

	# sometimes just facepalm
	else {
		if (occasion(128)) {
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
