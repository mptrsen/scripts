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
	'division=s',
	'names=s',
	'outdir=s',
	'verbose|v',
);

$opt{'db'}             //= '/share/pool/nr/2013-03-01/nr';
$opt{'blast-location'} //= '/share/apps/blastp_2.2.26+';
$opt{'blastdbcmd-location'} //= '/share/apps/blastdbcmd_2.2.26+';
$opt{'blast-threads'}  //= 1;
$opt{'outdir'}         //= '.';
$opt{'nodes'}          //= '/share/pool/tax/2013-06-13/nodes.dmp';
$opt{'names'}          //= '/share/pool/tax/2013-06-13/nodes.dmp';
$opt{'division'}       //= '/share/pool/tax/2013-06-13/division.dmp';
my @queries = @ARGV;

my $blastp = File::Spec->catfile($opt{'blast-location'});
my $blastdbcmd = File::Spec->catfile($opt{'blastdbcmd-location'});
my $verbose = $opt{'verbose'};
my $n = 0;
my $isvir = '';

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

foreach my $queryfile (@queries) {
	print "# $queryfile\n";
	printf "# %-3s %-10s %-6s %-3s\n", 'vir', 'gid', 'taxid', 'div';

	my $blast_output_file = do_blastp_search($queryfile);

	my $blastresult = parse_blast_resultfile($blast_output_file)
		or print "No BLASTP hits obtained for $queryfile\n" and next;

	$n = 0;
	foreach my $gid (@$blastresult) {
		$n++;

		my $tax_id = get_taxon_id($gid);
		my $div_id = $division_of_node->{$tax_id};
		if ($div_id == 9) { $isvir = 'X' } else { $isvir = ' ' }
		printf "%-5s %-10s %-6s %-3s\n", $isvir, $gid, $tax_id, $div_id;

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

	return $blastofn if -s $blastofn;

	my @blastcmd = qq( $blastp -num_threads $opt{'blast-threads'} -db $opt{'db'} -query $qf -outfmt '7 sseqid sgi sacc sallseqid sallgi sallacc' -out $blastofn );

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
	my @gids = ();
	if (scalar @blastresult > 0) {
		foreach my $line (@blastresult) {
			my @fields = split /\s+/, $line;
			push @gids, $fields[1];
		}
	}
	else { return undef }
	scalar @blastresult > 0 ? return \@gids : return undef;
}

sub get_taxon_id {
	my $id = shift @_;
	# replace every nonstandard character in order to form an ok filename
	(my $fn = $id) =~ s/[^a-zA-Z0-9_.\-+]/_/g;
	my $dbofn = File::Spec->catfile($opt{'outdir'}, $fn . '.dbo'. $n);

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
	print "##  Loading nodes into memory...\n";
	open my $nfh, '<', $nfn;
	#my $nfh = IO::File->new($nfn, 'r');
	while (<$nfh>) {
		chomp;
		my @fields = split /\s+\|\s+/;
		$division_of_node->{$fields[0]} = $fields[4];
	}
	return $division_of_node;
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
	return $division_name;
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
	return $name_of;
}
