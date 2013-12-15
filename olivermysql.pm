package MySQL;
# MySQL.pm - library file with utility method for connecting to mysql via Perl DBI module

# Required modules
use strict;
use warnings;
use DBI;
use Carp;

# Initilize variables with default values
my $host_name   = "localhost";
my $user_name   = "malty";
my $password    = "malty";
my $port_num    = undef;
my $socket_file = undef;

# Establish a connection to mysql database, returning a database handle
# Raise an exception if connection cannot be established
sub connect {

    my ($arg_ref) = @_;

	# Obligatory user input    
	my $db_name = $arg_ref->{database};
	if (!defined $db_name) {croak 'Database name missing'};

	# Facultative user input
    $user_name   = $arg_ref->{user}        if $arg_ref->{user};
    $password    = $arg_ref->{password}    if $arg_ref->{password};
    $port_num    = $arg_ref->{port_number} if $arg_ref->{socket_file};
    $socket_file = $arg_ref->{socket_file} if $arg_ref->{socket_file};

	# Database connection parameters for DBI module
	my $dsn = "DBI:mysql:host=$host_name;database=$db_name";
	$dsn   .= ";mysql_socket=$socket_file" if defined $socket_file;
	$dsn   .= ";port=$port_num"            if defined $port_num;
	my %conn_attrs = (PrintError => 0, RaiseError => 1, AutoCommit => 1);

	# Establish connection to mysql database and return database handle
	return (DBI->connect ($dsn, $user_name, $password, \%conn_attrs));
}
1;
