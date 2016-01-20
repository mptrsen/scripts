#!/usr/bin/perl
use strict;
use warnings;
use autodie;

use File::Spec::Functions;
use File::Path qw(make_path);
use File::Copy;
use Getopt::Long;
use Data::Dumper;

use Seqload::Fasta;

my $usage = <<END_USAGE;
USAGE: $0 [OPTIONS] <ORTHODBTABLEFILE> <OGSLIST>

ORTHODBTABLEFILE must be an OrthoDB 7 formatted table.
OGSLIST must be a tab-separated file containing one taxon name
	and the path to the corresponding OGS file per line.

Options:
	-o <dir>, --outdir <dir>       Output directory. Defaults to "hamstr_sets".
	-s <name>, --setname <name>    Set name. Defaults to "new_set".
	-n <i>, --num-threads <i>      Number of CPU threads to use for alignment and HMM building. Defaults to 1.
END_USAGE

my %opts; 
my $outdir = catdir('hamstr_sets');
my $setname = 'new_set';
my $num_threads = 1;

GetOptions( %opts,
	'outdir|o=s' => \$outdir,
	'setname|s=s' => \$setname,
	'num-threads|n=i' => \$num_threads,
) or die;

scalar @ARGV == 2 or die $usage;

my $orthodbtable = shift @ARGV;
my $ogslist      = shift @ARGV;

my $printformat = "% 13s: %s\n";
printf $printformat, 'OrthoDB table', $orthodbtable;
printf $printformat, 'OGS list',  $ogslist;
printf $printformat, 'output dir',  $outdir;
printf $printformat, 'set name',  $setname;

# read input data
my $clusters     = parse_orthodb_table($orthodbtable);
my $taxa         = get_taxa($clusters);
my $ogs_file_for = parse_ogs_list($ogslist, $taxa);
print_separator_line();
my $ogs_for      = load_ogs($ogs_file_for);
print_separator_line();

# create the directories
make_path($outdir);
my $blast_dir      = catdir($outdir, 'blast_dir');      make_path($blast_dir);
my $core_orthologs = catdir($outdir, 'core_orthologs'); make_path($core_orthologs);
my $set_dir        = catdir($core_orthologs, $setname); make_path($set_dir);
my $aln_dir        = catdir($set_dir, 'aln_dir');       make_path($aln_dir);
my $hmm_dir        = catdir($set_dir, 'hmm_dir');       make_path($hmm_dir);
my $fafile         = catfile($set_dir, $setname . '.fa');

# create the blast dbs
foreach my $name ( @$taxa ) {
	print "Creating BLAST database for $name...\n";
	makeblastdb($name, $ogs_file_for->{$name});
}

print_separator_line();

# create the HMMs
my $n_og = scalar keys %$clusters;
my $c = 1;
while ( my ($og, $data_for_og) = each %$clusters ) {
	print "($c/$n_og) Creating HMM for $og...\n";
	make_hmm($og, $data_for_og);
	++$c;
}

print_separator_line();
print "Done.\n";
exit;

sub makeblastdb {
	my $name = shift;
	my $infile = shift;
	my $dbdir = catdir($blast_dir, $name);
	my $dbfile = catfile($dbdir, $name . '_prot');
	my $logfile = catfile($outdir, 'makeblastdb_' . $name . '.log');
	my @makeblastdb = qq(makeblastdb -dbtype prot -title $name -in $infile -out $dbfile -logfile $logfile);
	make_path($dbdir);
	system( @makeblastdb ) and die "Fatal: could not make BLAST DB for $name: $?\n";
	copy($ogs_for->{$name}, catfile($dbdir, $name . '_prot.fa'));
}

sub make_hmm {
	my $id = shift;
	my $data = shift;
	# compile sequences
	my $seqs = get_sequences($data, $id);
	# make a fasta file from ogs sequence info
	my $fafile = make_fasta($seqs, $id);
	# align that fasta file
	my $alnfile = align($fafile, $id);
	# build hmm from msa
	my $hmmfile = hmmbuild($alnfile, $id);
}


sub get_sequences {
	my $data = shift;
	my $id = shift;
	my $d = { };
	foreach my $tax (keys %$data) {
		my $h = join '|', $id, $tax, $data->{$tax};
		$d->{$h} = $ogs_for->{$tax}->{$data->{$tax}};
	}
	return $d;
}

sub make_fasta {
	my $d = shift;
	my $id = shift;
	my $f = catfile($aln_dir, $id . '.fa');
	open my $fh, '>', $f;
	foreach my $h (sort {$a cmp $b} keys %$d) {
		printf $fh ">%s\n%s\n", $h, $d->{$h};
	}
	close $fh;
	return $f;
}

# Sub: align
# Generate a fasta alignment from a fasta file
sub align {
	my $fafile = shift;
	my $id = shift;
	my $alnf = catfile($aln_dir, $id . '.aln');
	my $logf = catfile($aln_dir, $id . '.log');
	# MAFFT L-INS-i
	my @alignment_cmd = qq(mafft --thread $num_threads --anysymbol --localpair --maxiterate 100 $fafile > $alnf 2> $logf);
	system(@alignment_cmd) and die "Fatal: alignment failed for $fafile: $!\n";
	return $alnf;
}

# Sub: hmmbuild
# Generates a hidden Markov model (HMM) file from an alignment (fasta) file.
sub hmmbuild {
	my $alnfile = shift;
	my $id = shift;
	my $hmmfile = catfile($hmm_dir, $id . '.hmm');
	my $logfile = catfile($hmm_dir, $id . '.log');
	my @hmmbuild_cmd = qq(hmmbuild --cpu $num_threads -n $id -o $logfile $hmmfile $alnfile );
	system("@hmmbuild_cmd") and die "Fatal: HMM building failed for $alnfile: $!\n";
	return $hmmfile;
}


sub parse_orthodb_table {
	my $f = shift;
	my $d = { };
	my $fields = [ ];
	my $n = 0;
	open my $fh, '<', $f;
	while (<$fh>) {
		chomp;
		$fields = [ split /\t/ ];
		$d->{$$fields[0]}->{$$fields[5]} = $$fields[2];
		$n++;
	}
	printf $printformat, 'genes', $n;
	printf $printformat, 'OGs', scalar keys %$d;
	return $d;
}

sub get_taxa {
	my $d = shift;
	my $t = { };
	foreach my $og (keys %$d) {
		$t->{$_} = 1 foreach keys $d->{$og};
	}
	printf $printformat, 'taxa', scalar(keys %$t) . ' (' . join(' ', keys(%$t)) . ')';
	return [ keys %$t ];
}

sub parse_ogs_list {
	my $f = shift;
	my $taxa = shift;
	my $d = { };
	my $fields = [ ];
	my $ogs = { };
	open my $fh, '<', $f;
	while (<$fh>) {
		chomp;
		$fields = [ split /\t/ ];
		# use only those that appear in the taxon list
		next unless grep { $_ eq $$fields[0] } @$taxa;
		$d->{$$fields[0]} = $$fields[1];
	}
	return $d;
}

sub load_ogs {
	my $d = shift;
	my $o = { };
	foreach my $tax ( keys %$d ) {
		print "Loading OGS for $tax...\n";
		$o->{$tax} = fasta2hash($d->{$tax});
	}
	return $o;
}

sub print_separator_line {
	print '-' x ( 15 + length $orthodbtable ), "\n";
}

sub fasta2hash {
	my $f = shift;
	my $d = { };
	my $fh = Seqload::Fasta->open($f);
	while (my ($h, $s) = $fh->next_seq()) {
		$d->{$h} = $s;
	}
	return $d;
}
