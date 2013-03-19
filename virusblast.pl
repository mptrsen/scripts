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
	'outdir=s',
);

$opt{'db'}             //= '/share/pool/nr/2013-03-01/nr';
$opt{'blast-location'} //= '/share/apps/blastx_2.2.26+';
$opt{'outdir'}         //= '.';
my @queries = @ARGV;
foreach my $queryfile (@queries) {
	my $blastofn = File::Spec->catfile($opt{'outdir'}, basename($queryfile . '.blastout'));
	my @blastcmd = qq($opt{'blast-location'} -db $opt{'db'} -query $queryfile -outfmt '7 sseqid sgi sacc sallseqid sallgi sallacc' -out $blastofn);
	system(@blastcmd) and die "Fatal: BLAST failed: $!\n";
	my $ofh = IO::File->new($blastofn, 'r');
	my @blastresult = <$ofh>;
	print @blastresult;
	@blastresult = grep /^[^#]/, @blastresult;
	if (scalar @blastresult == 0) {
		print "No hits obtained for $queryfile\n";
		next;
	}
	my @fields = split /\s+/, $blastresult[0];
	my $id = $fields[1];
	my @blastdbcmdcmd = qq( File::Spec->catfile(basename($opt{'blast-location'}), 'blastdbcmd') -db $opt{'db'} );
}
