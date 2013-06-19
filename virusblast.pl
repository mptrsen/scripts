#!/usr/bin/perl
use strict;
use warnings;
use autodie;

use File::Spec;
use File::Basename;
use IO::File;
use IO::Dir;
use Getopt::Long;
use File::Basename;
use Data::Dumper;

my %opt = ();
GetOptions( \%opt,
	'db=s',
	'nodes=s',
	'blast-location=s',
	'blastdbcmd-location=s',
	'blast-threads=i',
	'delnodes=s',
	'division=s',
	'names=s',
	'outdir=s',
	'remote',
	'verbose|v',
);

# paths hardcoded to the ZFMK cluster unless specified
$opt{'db'}             //= '/share/pool/nr/2013-03-01/nr';
$opt{'blast-location'} //= '/share/apps/blastp_2.2.26+';
$opt{'blastdbcmd-location'} //= '/share/apps/blastdbcmd_2.2.26+';
$opt{'blast-threads'}  //= 1;
$opt{'division'}       //= '/share/pool/tax/2013-06-13/division.dmp';
$opt{'nodes'}          //= '/share/pool/tax/2013-06-13/nodes.dmp';
$opt{'names'}          //= '/share/pool/tax/2013-06-13/names.dmp';
$opt{'delnodes'}       //= '/share/pool/tax/2013-06-13/delnodes.dmp';
$opt{'outdir'}         //= '.';
$opt{'remote'}         //= undef;
my @queries = @ARGV;

# variables for easier access
my $blastp = File::Spec->catfile($opt{'blast-location'});
my $blastdbcmd = File::Spec->catfile($opt{'blastdbcmd-location'});
my $remote = $opt{'remote'};
my $verbose = $opt{'verbose'};
my $n = 0;
my $isvir = '';

# test whether files exist and stuff
unless (-f File::Spec->catfile($opt{'db'} . '.pal')) {
	die "Fatal: BLAST database not found at '" . $opt{'db'} . "'\n";
}
print "## BLAST database $opt{'db'}\n";

unless (-f File::Spec->catfile($opt{'nodes'})) {
	die "Fatal: Taxonomy nodes file not found at '". $opt{'nodes'} . "'\n";
}
print "## Taxonomy nodes file $opt{'nodes'}\n";

unless (-f File::Spec->catfile($opt{'division'})) {
	die "Fatal: Divisions file not found at '". $opt{'division'} . "'\n";
}
print "## Divisions file $opt{'division'}\n";

unless (-f File::Spec->catfile($opt{'names'})) {
	die "Fatal: Names file not found at '". $opt{'names'} . "'\n";
}
print "## Names file $opt{'names'}\n";

unless (-x File::Spec->catfile($opt{'blast-location'})) {
	die "Fatal: blastp not found or not executable at '" . $opt{'blast-location'} . "'\n";
}
print "## blastp at $opt{'blast-location'}\n";

unless (-x File::Spec->catfile($opt{'blastdbcmd-location'})) {
	die "Fatal: blastdbcmd not found or not executable at '" . $opt{'blastdbcmd-location'} . "'\n";
}
print "## blastdbcmd at $opt{'blastdbcmd-location'}\n";


my $division_of_node = nodes2division($opt{'nodes'}) or die;
my $division_name_of = divisions($opt{'division'}) or die;
my $taxon_name_of    = names($opt{'names'}) or die;
my $deleted_node     = delnodes($opt{'delnodes'}) or die;

foreach my $queryfile (@queries) {
	print "# $queryfile\n";

	my $blast_output_file = do_blastp_search($queryfile);

	my $blastresult = parse_blast_resultfile($blast_output_file)
		or print "No BLASTP hits obtained for $queryfile\n" and next;

	printf "# %-3s %-10s %-10s %-6s %-3s %-6s %-8s %s\n",
		'vir',
		'qsid',
		'tgid',
		'taxid',
		'div',
		'score',
		'evalue',
		'pident',
		'qstart',
		'qend',
		'sstart',
		'send',
		'taxon',
	;

	$n = 0;
	foreach my $result (@$blastresult) {
		$n++;

		# skip deleted nodes
		if ($deleted_node->{$result->[1]}) { next }

		# get information: taxon id, division, taxon name
		my $tax_id = get_taxon_id($result->[1], $n);
		my $div_id = $division_of_node->{$tax_id};
		my $taxon_name = $taxon_name_of->{$tax_id};

		# is this a virus hit?
		if ( $div_id == 9 or $taxon_name =~ /virus/i ) { $isvir = 'X' } else { $isvir = '' }

		printf "%-5s %-10s %-10s %-7s %-2d %6.1f %8.1e %.1f %d %d %d %d %s\n",
			$isvir,        # is this a virus sequence?
			$result->[0],  # query id
			$result->[1],  # target id
			$tax_id,       # taxon id
			$div_id,       # division id
			$result->[2],  # bit score
			$result->[3],  # e-value
			$result->[4],  # percent identity
			$result->[5],  # query start
			$result->[6],  # query end
			$result->[7],  # target start
			$result->[8],  # target end
			$taxon_name,   # taxon name
		;

	}
}

print "Done. Exiting.\n";

exit;


##################################
# subs
##################################
sub do_blastp_search {
	my $qf = shift @_;
	my $blastofn = File::Spec->catfile($opt{'outdir'}, basename($qf . '.blastout'));
	print "Using BLASTP output file $blastofn\n" if $verbose;

	# set database to 'nr' if using remote option
	my $db = $remote ? 'nr' : $opt{'db'};

	# number of threads only if running a local search
	my $threads = $remote ? "-num_threads $opt{'blast-threads'}" : '';

	return $blastofn if -s $blastofn;

	# output format
	my $outfmt = '7 qseqid sgi bitscore evalue pident qstart qend sstart send';

	my @blastcmd = qq( $blastp $threads -db $db -query $qf -outfmt '$outfmt' -out $blastofn );

	print "Executing '@blastcmd'\n" if $verbose;
	system(@blastcmd) and die "Fatal: $opt{'blast-location'} failed. $!\n";

	return $blastofn;
}

sub parse_blast_resultfile {
	my $ofn = shift @_;
	open my $ofh, '<', $ofn;
	my @blastresult = <$ofh>;
	undef $ofh;
	@blastresult = grep /^[^#]/, @blastresult;
	chomp @blastresult;
	my @results = ();
	if (scalar @blastresult > 0) {
		foreach my $line (@blastresult) {
			my @fields = split /\s+/, $line;
			push @results, \@fields;
		}
	}
	else { return undef }
	scalar @blastresult > 0 ? return \@results : return undef;
}

sub get_taxon_id {
	my $id = shift @_;
	my $n = shift @_;
	# replace every nonstandard character in order to form an ok filename
	(my $fn = $id) =~ s/[^a-zA-Z0-9_.\-+]/_/g;
	my $dbofn = File::Spec->catfile($opt{'outdir'}, $fn . '.dbo.'. $n);

	# output format: sequence_id tax_id
	# the tax_id can be found in the taxonomy dumpfiles
	my @blastdbcmdcmd = qq( $blastdbcmd -db $opt{'db'} -out $dbofn -entry $id -outfmt '%i %T' );
	print "Executing '@blastdbcmdcmd'\n" if $verbose;
	system(@blastdbcmdcmd) and die "Fatal: blastdbcmd failed. $!\n";

	open my $infh, '<', $dbofn;
	#my $infh = IO::File->new($dbofn, 'r');
	my $blastdbcmdresult = <$infh>;
	
	chomp $blastdbcmdresult;
	$blastdbcmdresult =~ /(\d+)$/;
	return $1;
}

sub nodes2division {
	my $nfn = shift @_;
	my $division_of_node = { };
	print "## Loading nodes into memory...\n";
	open my $nfh, '<', $nfn;
	#my $nfh = IO::File->new($nfn, 'r');
	while (<$nfh>) {
		chomp;
		my @fields = split /\s+\|\s+/;
		$division_of_node->{$fields[0]} = $fields[4];
	}
	$division_of_node ? return $division_of_node : return undef;
}

sub divisions { 
	my $fn = shift @_;
	my $division_name = { };
	print "## Loading divisions into memory...\n";
	open my $fh, '<', $fn;
	#my $fh = IO::File->new($fn, 'r');
	while (<$fh>) {
		chomp;
		my @fields = split /\s+\|\s+/;
		$division_name->{$fields[0]} = $fields[2];
	}
	$division_name ? return $division_name : return undef;
}

sub names {
	my $fn = shift @_;
	my $name_of = { };
	print "## Loading names into memory...\n";
	open my $fh, '<', $fn;
	while (<$fh>) {
		chomp;
		my @fields = split /\s+\|\s+/;
		$name_of->{$fields[0]} = $fields[1];
	}
	$name_of ? return $name_of : return undef;
}

sub delnodes {
	my $fn = shift @_;
	my $deleted_nodes = { };
	print "## Loading deleted nodes into memory...\n";
	open my $fh, '<', $fn;
	my @deleted_nodes = <$fh>;
	chomp @deleted_nodes;
	$deleted_nodes = { map { $_ => 1 } @deleted_nodes };
	$deleted_nodes ? return $deleted_nodes : return undef;
}
