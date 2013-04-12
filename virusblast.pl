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

my %opt = ();
GetOptions( \%opt,
	'db=s',
	'blast-location=s',
	'blast-threads=i',
	'outdir=s',
	'verbose|v',
);

$opt{'db'}             //= '/share/pool/nr/2013-03-01/nr';
$opt{'blast-location'} //= '/share/apps/blastp_2.2.26+';
$opt{'blastdbcmd-location'} //= '/share/apps/blastdbcmd_2.2.26+';
$opt{'blast-threads'}  //= 1;
$opt{'outdir'}         //= '.';
my @queries = @ARGV;

my $blastp = File::Spec->catfile($opt{'blast-location'});
my $blastdbcmd = File::Spec->catfile($opt{'blastdbcmd-location'});
my $verbose = $opt{'verbose'};

foreach my $queryfile (@queries) {

	my $blastofn = File::Spec->catfile($opt{'outdir'}, basename($queryfile . '.blastout'));
	print "Using BLASTP output file $blastofn\n" if $verbose;

	my @blastcmd = qq( $blastp -num_threads $opt{'blast-threads'} -db $opt{'db'} -query $queryfile -outfmt '7 sseqid sgi sacc sallseqid sallgi sallacc' -out $blastofn);

	print "Executing '@blastcmd'\n" if $verbose;
	system(@blastcmd) and die "Fatal: $opt{'blast-location'} failed: $!\n";

	my $ofh = IO::File->new($blastofn, 'r');
	my @blastresult = <$ofh>;
	@blastresult = grep /^[^#]/, @blastresult;
	if (scalar @blastresult == 0) {
		print "No BLASTP hits obtained for $queryfile\n";
		next;
	}
	my @fields = split /\s+/, $blastresult[0];
	my $id = $fields[1];
	my $dbofn = File::Spec->catfile($blastofn . '.dbo');
	my @blastdbcmdcmd = qq( $blastdbcmd -db $opt{'db'} -out $dbofn -entry $id -outfmt '%i is taxid %T: %S (%L)');
	print "Executing '@blastdbcmdcmd'\n" if $verbose;
	system(@blastdbcmdcmd) and die "Fatal: blastdbcmd failed: $!\n";

}

print "Done. Exiting.\n";

exit;
