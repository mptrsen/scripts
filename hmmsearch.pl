#!/usr/bin/perl
use strict;
use warnings;

use File::Basename;
use File::Spec;
use IO::File;
use Data::Dumper;
use Getopt::Long;

my $outdir            = '.';
my $reportfile        = undef;
my $hmmsearch         = '/share/scientific_bin/hmmer-3.0/hmmsearch';
my $evalue_threshold  = '10e-5';
my $max               = 0;
my $ncpu              = 1;
my $data              = {};
my $help;
my %species           = ();
my $usage             = "Usage: $0 [OPTIONS]... HMMFILE ASSEMBLYFILES\n";

GetOptions(
	'outdir=s'     => \$outdir,
	'reportfile=s' => \$reportfile,
	'hmmsearch=s'  => \$hmmsearch,
	'E=f'          => \$evalue_threshold,
	'max'          => \$max,
	'ncpu=i'       => \$ncpu,
	'h|help'       => \$help,
) or die;

if ($help) { print $usage and exit; }
my $hmm = shift(@ARGV) or die($usage);
$hmm =~ /\.hmm$/ or die "Fatal: First argument must be a HMM file\n$usage" ;

unless (-f $hmm) { die "Fatal: HMM file '$hmm' does not exist\n" }

unless (-d $outdir) { mkdir $outdir or die "Fatal: could not create output directory '$outdir': $!\n" }

defined $reportfile or $reportfile = File::Spec->catfile(basename($hmm, '.hmm') . '.txt');

$max = $max ? '--max' : '';

# get the assembly->species list
while (<DATA>) {
	chomp;
	my @cols = split("\t");
	$species{$cols[0]} = $cols[1];
}

my $reportfh = IO::File->new($reportfile, 'w');

# what HMM we are using
print  $reportfh "########################################################\n";
printf $reportfh "# Results for %s with e-value threshold %1.1e %s\n", basename($hmm), $evalue_threshold, $max;
print  $reportfh "########################################################\n";

# go through all assembly files
foreach my $assfile (@ARGV) {
	# output file name
	my $outfile = File::Spec->catfile($outdir, basename($assfile) . '.domtblout');

	# do the HMM search with specified settings
	system(qq($hmmsearch -E $evalue_threshold $max --cpu $ncpu -o /dev/null --domtblout $outfile $hmm $assfile))
		and die("Fatal: hmmsearch failed for $assfile\: $!\n");


	# open hmmsearch output file
	my $fh = IO::File->new(File::Spec->catfile($outfile));

	# number of hits for this search
	my $num_hits = 0;

	# slurp assembly file
	my $sequences = &slurpfasta($assfile);

	# read the hmmsearch domtblout file
	while (<$fh>) {
		# skip comments and empty lines
		next if /^#/;
		next if /^\s*$/;

		# print this stuff only once
		if ($num_hits == 0) {
			# assembly information
			(my $assembly = basename($assfile)) =~ s/.*INS/INS/;
			$assembly =~ s/_(e[135]).*//;
			printf $reportfh "# Assembly: %s [%s] (%s)\n",
				$assembly,
				$1,
				$species{$assembly},
			;
			# field info
			printf $reportfh "# %- 90s %8s %5s %8s %6s %8s %-8s\n",
				'target_name',
				'i-Evalue',
				'score',
				'ali_from',
				'ali_to',
				'env_from',
				'env_to',
			;
			# lines
			printf $reportfh "# %- 90s %8s %5s %-8s %6s %-8s %-8s\n",
				'-' x 66,
				'-' x 8,
				'-' x 5,
				'-' x 8,
				'-' x 6,
				'-' x 8,
				'-' x 6,
			;
		}

		# we found something; also make sure the above gets printed only once
		++$num_hits;

		# split by whitespace
		my @fields = split(/\s+/, $_, 23);
		chomp(@fields);

		# print data
		printf $reportfh ">%- 67s %4.1e %- 6.1f %-8d %-8d %-8d %-8d\n%s\n", 
			$fields[0] . ' ' . $fields[22],
			$fields[12],
			$fields[13],
			$fields[17],
			$fields[18],
			$fields[19],
			$fields[20],
			$sequences->{$fields[0] . ' ' . $fields[22]}
		;
	}
	# record separator only if found something
	print $reportfh "#\n" unless $num_hits == 0;
	# free mem
	undef $fh;
	undef $sequences;
	print STDOUT "$num_hits hits for $hmm in $assfile\n";
}

# slurp a fasta file
# argument: scalar string filename
# returns: hash reference
sub slurpfasta {
	my $f = shift;
	my $content = {};
	my $fh = Seqload::Fasta->open($f);
	while (my ($h, $s) = $fh->next_seq()) {
		$$content{$h} = $s;
	}
	$fh->close();
	return $content;
}

# Object-oriented fasta file interface
package Seqload::Fasta;
use Carp;
# Constructor. Returns a sequence database object.
sub open {
	my ($class,$fn)=@_;
	open(my $fh, '<', $fn)
		or confess "Fatal: Could not open $fn\: $!\n";
	my $self={
		'fn'=>$fn,
		'fh'=>$fh
	};
	bless($self,$class);
	return $self;
}
# Returns the next sequence as an array (hdr, seq). 
sub next_seq {
	my $self=shift;
	my $fh=$self->{'fh'};
	local $/="\n>"; # change the line separator
	return unless defined(my $l=readline($fh));  # read the line(s)
	chomp $l;
	croak "Fatal: ".$self->{'fn'}."is not a FASTA file: Missing header line\n"
		if ($.==1 and $l!~/^>/);
	$l=~s/^>//;
	my ($h,$s)=split(/\n/,$l,2);
	if (defined $s) {
		$s=~s/>//g;
		$s=~s/\s+//g # remove all whitespace, including newlines
	}
	return($h,$s);
}
# Destructor. Closes the file and undefs the database object.
sub close {
	my $self=shift;
	my $fh=$self->{'fh'};
	my $fn=$self->{'fn'};
	close($fh) or carp("Warning: Could not close $fn\: $!\n");
	undef($self);
}
1;

=head1 SYNOPSIS

  hmmsearch.pl [OPTIONS]... HMMFILE ASSEMBLYFILES

=head1 IMPORTANT NOTICE

Make sure you double-check the assembly list at the end of this script. It must
be up to date and match your assembly files, or this script will be unable to
print out the correct species names!

=head1 OPTIONS

=head2 -E EVALUE

Specify the e-value threshold for the HMM search.

=head2 -h

Print short help message.

=head2 -hmmsearch /PATH/TO/HMMSEARCH

Specify the path to F<hmmsearch>.

=head2 -max

Toggle max sensitivity mode for the HMM search.

=head2 -ncpu NCPU

Specify the maximum number of CPUs to use for F<hmmsearch>. Useful when running
in parallel environments, and recommended because if unset, F<hmmsearch> will
try to use all available CPUs, which may crash your cluster.

=head2 -outdir OUTDIR

Specify the output directory. 

=head2 -reportfile REPORTFILE

Specify the report file.

=cut

__END__
INSbusTBNRABPEI-121	Andrena vaga
INSbusTBGRABPEI-127	Anthophora plumipes
INSbusTBCRABPEI-135	Bibio marci
INSbusTBKRAAPEI-76	Bombylius major
INSbusTBHRABPEI-138	Chrysura austriaca
INSbusTBRRAAPEI-83	Cleptes nitidulus
INSbusTBARABPEI-119	Colletes cunicularius
INSbusTBLRAAPEI-77	Corythucha ciliata
INSbusTBDRAAPEI-79	Eriocrania cf.
INSbusTBIRAAPEI-84	Hedychrum nobile
INSbusTBQRAAPEI-82	Nomada lathburiana
INSbusTBFRABPEI-126	Osmia cornuta
INSbusTBMRAAPEI-78	Prorhinotermes simplex
INSbusTBJRAAPEI-85	Pyrrhocoris apterus
INSbusTBPRAAPEI-81	Sphecodes albilabris
INSbusTBORAAPEI-80	Xylocopa violacea
INSbttTIRAAPEI-18	Folsomia candida
INSbttTJRAAPEI-19	Tricholepidion gertschi
INSbttTARAAPEI-83	Bittacus pilicornis
INSbttTARAAPEI-9	Platycentropus radiatus
INSbttTBRAAPEI-11	Dineutes sp.
INSbttTBRAAPEI-91	Chauliodes sp.
INSbttTCRAAPEI-12	Arrhenodes sp.
INSbttTCRAAPEI-92	Cheumatopsyche sp.
INSbttTDRAAPEI-118	Chimarra sp.
INSbttTDRAAPEI-13	Sympetrum vicinum
INSbttTERAAPEI-126	Leptocerus americanus
INSbttTERAAPEI-14	Argia fumipennis
INSbttTFRAAPEI-15	Ischnura hastata
INSbttTFRAAPEI-171	Nectopsyche albida
INSbttTGRAAPEI-13	Neohermes sp.
INSbttTGRAAPEI-16	Nehalennia gracilis
INSbttTHRAAPEI-15	Psychomyia flavida
INSbttTHRAAPEI-17	Ptilostomis sp.
INSbttTIRAAPEI-22	Pteronarcys sp.
INSbttTKRAAPEI-18	Corydalus cornutus
INSbttTLRAAPEI-19	Calosoma sp.
INSbttTMRAAPEI-20	Macromia illinoiensis
INSbttTNRAAPEI-21	Gomphus rogersi
INSbttTORAAPEI-22	Dromogomphus spinosus
INSbttTPRAAPEI-24	Celithemis elisa
INSbttTQRAAPEI-26	Enallagma aspersum
INSbttTRRAAPEI-27	Epitheca princeps
INSbttTSRAAPEI-29	Thermobia domestica
INSbusTBDRAAPEI-17	Glyphotaelius pellucidus
INShauTAARAAPEI-90	Mantis religiosa
INShauTABRAAPEI-93	Nemophora degeerella
INShauTACRAAPEI-94	Panorpa vulgaris
INShauTADRAAPEI-95	Drepanepteryx phalaenoides
INShauTAERAAPEI-8	Amata phegea
INShauTAFRAAPEI-9	Sminthurus viridis/nigromaculatus
INShauTAHRAAPEI-18	Mantispa styriaca
INShauTAIRAAPEI-88	Blasticotoma filiceti
INShauTAJRAAPEI-89	Pogonognathellus longicornis/flavescens
INShauTAKRAAPEI-90	Baetis pumilus
INShauTALRAAPEI-93	Perla marginata
INShauTAMRAAPEI-94	Metallyticus splendidus
INShauTANRAAPEI-95	Tetrix subulata
INShauTAORAAPEI-8	Graphocephala fennahi
INShauTAPRAAPEI-9	Notostira elongata
INShauTAQRABPEI-11	Chrysis viridula
INShauTARRAAPEI-12	Chrysis terminata
INShauTASRAAPEI-13	Hydrochara caraboides
INShauTATRAAPEI-14	Trichrysis cyanea
INShauTAURAAPEI-15	Gasteruption tournieri
INShauTAVRAAPEI-16	Amphipyra pyramidea
INShauTAWRAAPEI-17	Pseudospinolia neglecta
INShauTAXRAAPEI-18	Lagria hirta
INShauTAYRAAPEI-19	Meloe violaceus
INShauTAZRAAPEI-20	Sphinx pinastri
INShauTBARAAPEI-21	Cicindela hybrida
INShauTBBRAAPEI-22	Phryganea grandis
INShauTBCRAAPEI-30	Holopyga generosa
INShauTBDRAAPEI-31	Phragmatobia fuliginosa
INShauTBERAAPEI-33	Aleochara curtula
INShauTBFRAAPEI-34	Yponomeuta evonymella
INShauTBGRAAPEI-35	Polyommatus icarus
INSnfrTAARAAPEI-13	Orussus abietinus
INSnfrTABRAAPEI-14	Plea minutissima
INSnfrTACRAAPEI-15	Dichrostigma flavipes
INSnfrTADRAAPEI-16	Cybister lateralimarginalis
INSnfrTAERAAPEI-17	Brachygaster minutus
INSnfrTAFRAAPEI-18	Meinertellus cundinamarcensis
INSnfrTAGRAAPEI-19	Xanthostigma xanthostigma
INSnfrTAHRAAPEI-20	Pseudogonalos hahni
INSnfrTAIRAAPEI-21	Anurida maritima
INSnfrTAJRAAPEI-22	Machilis hrabei
INSnfrTALRAAPEI-31	Leuctra sp.
INSnfrTAKRAAPEI-30	Ephemera danica
INSnfrTAMRAAPEI-33	Stenobothrus lineatus
INSnfrTANRAAPEI-34	Cercopis vulnerata
INSnfrTAORAAPEI-35	Velia caprai
INSnfrTAPRAAPEI-36	Acanthosoma haemorrhoidale
INSnfrTAQRAAPEI-37	Cotesia vestalis
INSnfrTARRAAPEI-39	Dichochrysa prasina
INSnfrTATRAAPEI-43	Micromus variegatus
INSnfrTAURAAPEI-8	Chrysis mixta
INSnfrTAVRAAPEI-9	Triodia sylvina
INSnfrTAWRAAPEI-11	Episyrphus balteatus
INSnfrTAXRAAPEI-12	Pseudomalus pusillus
INSnfrTAYRAAPEI-13	Anthocharis cardamines
INSnfrTAZRAAPEI-14	Pentachrysis inaequalis
INSnfrTASRAAPEI-41	Chrysis analis
INSnfrTBBRAAPEI-16	Mesembrina meridiana
INSnfrTBDRAAPEI-18	Hedychridium ardens
INSnfrTBERAAPEI-19	Gyrinus marinus
INSnfrTBFRAAPEI-90	Triarthria setipennis
INSnfrTBGRAAPEI-93	Donacia marginata
INSnfrTBHRAAPEI-94	Trigoniophthalmus cf.
INSnfrTBIRAAPEI-95	Ceuthophilus sp.
INSnfrTBJRAAPEI-8	Hydroptilidae sp.
INSnfrTBNRAAPEI-13	Dasymutilla gloriosa
INSnfrTBORAAPEI-14	Sphecius convallis
INSnfrTBPRAAPEI-15	Timema cristinae
INSnfrTBARAAPEI-15	Ceratophyllus gallinae
INSnfrTBCRAAPEI-17	Thyatira batis
INSnfrTBKRAAPEI-9	Grylloblatta bifratrilecta
INSnfrTBLRAAPEI-11	Okanagana villosa
INSnfrTBMRAAPEI-12	Cimbex cf.
INSnfrTBQRAAPEI-16	Cyphoderris sp.
INSfrgTBERAAPEI-30	Chyphotes sp.
INSfrgTALRAAPEI-22	Apachyus charteceus
INSfrgTAMRAAPEI-30	Lepismachilis ysignata
INSfrgTANRAAPEI-31	Geometra papilionaria
INSfrgTAHRAAPEI-18	Epiophlebia superstes
INSfrgTAIRAAPEI-19	Bourletiella hortensis
INSfrgTAJRAAPEI-20	Polygonia c-album
INSfrgTAKRAAPEI-21	Galloisiana yuasai
INSfrgTAORAAPEI-33	Peruphasma schultei
INSfrgTAARAAPEI-19	Periplaneta americana
INSfrgTABRAAPEI-20	Epeorus assimilis
INSfrgTACRAAPEI-21	Diglyphus isaea
INSfrgTADRAAPEI-22	Pararge aegeria
INSfrgTAFRAAPEI-31	Menopon gallinae
INSfrgTAPRAAPEI-33	Trialeurodes vaporariorum
INSfrgTAQRAAPEI-34	Heteromurus nitidus
INSfrgTARRAAPEI-35	Coenagrion puella
INSfrgTASRAAPEI-36	Empusa pennata
INSfrgTATRAAPEI-37	Tenthredo koehleri
INSfrgTAVRAAPEI-41	Blaberus atropos
INSfrgTAWRAAPEI-43	Libellula quadrimaculata
INSfrgTAYRAAPEI-45	Aphidius colemani
INSfrgTAZRAAPEI-46	Aposthonia japonica
INSfrgTBARAAPEI-47	Pyrrhosoma nymphula
INSfrgTBBRAAPEI-56	Tanzaniophasma sp.
INSfrgTBCRAAPEI-57	Nilaparvata lugens
INSfrgTAERABPEI-30	Aphelinus abdominalis
INSfrgTAXRABPEI-44	Gryllotalpa sp.
INSfrgTBDRAAPEI-62	Sinella curviseta
INSfrgTBERAAPEI-74	Platycnemis pennipes
INSjdsTAARAAPEI-19	Gonolabis marginalis
INSjdsTABRAAPEI-20	Frankliniella cephalica
INSjdsTACRAAPEI-21	Thrips palmi
INSjdsTADRAAPEI-22	Gynaikothrips ficorum
INSjdsTAFRAAPEI-31	Cimex lectularius
INSjdsTAGRAAPEI-33	Isonychia bicolor
INSjdsTAHRAAPEI-34	Acerentomon sp.
INSjdsTAIRAAPEI-35	Planococcus citri
INSjdsTAJRAAPEI-36	Parides arcas
INSjdsTAKRAAPEI-37	Tetrodontophora bielanensis
INSjdsTALRAAPEI-39	Scopura montana
INSjdsTAMRAAPEI-41	Eucorydia yasumatsui
INSjdsTAERAAPEI-30	Stenopelmatus sp.
INSjdsTANRAAPEI-43	Occasjapyx japonicus
INSjdsTAORAAPEI-44	Thyreus orbatus
INSjdsTAPRAAPEI-45	Lepisma saccharina
INSjdsTAQRAAPEI-46	Zorotypus caudelli
INSjdsTASRAAPEI-56	Cordulia aenea
INSjdsTATRAAPEI-57	Euroleon nostras
INSjdsTAURAAPEI-62	Leptopilina clavipes
INSjdsTAVRAAPEI-37	Atelura formicaria
INSjdsTAWRAAPEI-39	Zygaena fausta
INSjdsTAXRAAPEI-41	Myrmecophilus sp.
INSjdsTBDRAAPEI-47	Cyphon laevipennis
INSjdsTBLRAAPEI-87	Libellula fulva
INSjdsTBMRAAPEI-88	Diodontus minutus
INSjdsTBRRAAPEI-8	Spercheus emarginatus
INSjdsTBSRAAPEI-9	Rhyacophila fasciata
INSjdsTARRAAPEI-47	Xenophysella greensladeae
INSjdsTAYRAAPEI-43	Dinetus pictus
INSjdsTAZRAAPEI-44	Xya sp.
INSjdsTBARAAPEI-45	Ptychoptera contaminata
INSjdsTBCRAAPEI-46	Perilampus aeneus
INSjdsTBERAAPEI-56	Trichocera fuscata
INSjdsTBFRAAPEI-57	Xenophyes metoponcus
INSjdsTBGRAAPEI-62	Ctenolepisma longicaudata
INSjdsTBHRAAPEI-74	Cordulegaster boltonii
INSjdsTBIRAAPEI-75	Oxybelus bipunctatus
INSjdsTBJRAAPEI-79	Osmylus fulvicephalus
INSjdsTBKRAAPEI-84	Cis boleti
INSjdsTBNRAAPEI-89	Forficula auricularia
INSjdsTBORAAPEI-90	Stephanus serrator
INSjdsTBPRAAPEI-93	Brachytron pratense
INSjdsTBQRAAPEI-94	Conwentzia psociformis
INStmbTAERAAPEI-56	Austroargiolestes icteromelas
INStmbTAFRAAPEI-57	Schulthesia lampridiformis
INStmbTAHRAAPEI-74	Xiphydria camelus
INStmbTAIRAAPEI-75	Lestes sponsa
INStmbTAJRAAPEI-79	Leucorrhinia caudalis
INStmbTAKRAAPEI-84	Shelfordella lateralis
INStmbTAMRAAPEI-88	Lamproblatta albipalpus
INStmbTANRAAPEI-89	Euglossa dilemma
INStmbTAORAAPEI-90	Dilta bitschi
INStmbTAPRAAPEI-93	Heterochaeta occidentalis
INStmbTARRAAPEI-95	Phyllocrania paradoxa
INStmbTATRAAPEI-9	Idolomantis diabolica
INStmbTAURAAPEI-11	Leucospis dorsigera
INStmbTAWRAAPEI-13	Boreus hyemalis
INStmbTAARAAPEI-84	Calopteryx splendens
INStmbTABRAAPEI-87	Campodea augens
INStmbTACRAAPEI-88	Eurytoma brunniventris
INStmbTADRAAPEI-56	Anataelia canariensis
INStmbTAQRAAPEI-94	Symploce sp.
INStmbTAVRAAPEI-12	Phyllothelys werneri
INStmbTAXRAAPEI-16	Pediaspis aceris
INStmbTAYRAAPEI-17	Ctenocephalides felis
INStmbTAZRAAPEI-18	Parasphendale sp.
INStmbTBARAAPEI-45	Oxyopsis gracilis
INStmbTBBRAAPEI-20	Torymus bedeguaris
INStmbTBDRAAPEI-22	Diphlebia lestoides
INStmbTALRABPEI-47	Conocephalus dorsalis
INStmbTBERAAPEI-30	Aretaon asperrimus
INStmbTBFRAAPEI-31	Cosmioperla kuna
INStmbTBGRAAPEI-33	Liposcelis bostrychophila
INStmbTBHRAAPEI-34	Nematus ribesii
INStmbTBIRAAPEI-35	Machilis sacra
INStmbTBJRAAPEI-36	Acantholyda hieroglyphica
INStmbTBKRAAPEI-37	Aeshna mixta
INStmbTBLRAAPEI-39	Nauphoeta cinerea
INStmbTBMRAAPEI-41	Pachycrepoideus vindemmiae
INStmbTBNRAAPEI-43	Eusynthemis guttata
INStmbTBORAAPEI-46	Parnopes grandior
INStmbTBCRBAPEI-33	Prosarthria teretrirostris
INStmbTBPRAAPEI-20	Mastotermes darwiniensis
INSytvTAARAAPEI-9	Meroplius fasciculatus
INSytvTABRAAPEI-11	Smicromyrme rufipes
INSytvTACRAAPEI-12	Ophiogomphus cecilia
INSytvTADRAAPEI-13	Scolia hirta
INSytvTAERAAPEI-14	Glycaspis brimblecombei
INSytvTAFRAAPEI-15	Methocha articulata
INSytvTAGRAAPEI-16	Diaeretus essigellae
INSytvTAHRAAPEI-17	Haploembia palaui
INSytvTAIRAAPEI-18	Sphex funerarius
INSytvTAJRAAPEI-19	Lepicerus sp.
INSytvTAKRAAPEI-34	Cephalonomia tarsalis
INSytvTALRAAPEI-35	Acanthocasuarina muellerianae
INSytvTAMRAAPEI-36	Tiphia femorata
INSytvTANRAAPEI-37	Ranatra linearis
INSytvTAORAAPEI-39	Megachile willughbiella
INSytvTAPRAAPEI-41	Episyron rufipes
INSytvTAQRAAPEI-43	Centrotus cornutus
INSytvTARRAAPEI-44	Stizoides tridentatus
INSytvTASRAAPEI-45	Trithemis kirbyi
INSytvTATRAAPEI-46	Psithyrus rupestris
INSytvTAURAAPEI-47	Liturgusa sp.
INSytvTAVRAAPEI-87	Metatropis rufescens
INSytvTAWRAAPEI-88	Trypoxylon figulus
INSytvTAXRAAPEI-89	Boyeria irene
INSytvTAYRAAPEI-90	Brunneria borealis
INSytvTAZRAAPEI-93	Megalodontes cephalotes
INSytvTBARAAPEI-94	Aquarius paludum
INSytvTBBRAAPEI-95	Pemphredon lugens
INSytvTBDRAAPEI-9	Alysson spinosus
INSytvTBERAAPEI-11	Gorytes laticinctus
INSytvTBFRAAPEI-12	Cerceris arenaria
INSytvTBGRAAPEI-13	Anaciaeschna isosceles
INSytvTBHRAAPEI-14	Essigella californica
INSytvTBIRAAPEI-15	Halictus quadricinctus
INSytvTBJRAAPEI-41	Nomia diversipes
INSytvTBKRAAPEI-43	Stylops melittae
INSytvTBLRAAPEI-44	Heriades truncorum
INSytvTBMRAAPEI-45	Stelis punctulatissima
INSytvTBNRAAPEI-46	Orthoderella ornata
INSytvTBORAAPEI-47	Macropis fulvipes
INSytvTBPRAAPEI-56	Andricus quercuscalicis
INSytvTBQRAAPEI-57	Chalybion californicum
INSytvTBRRAAPEI-62	Erythromma najas
INSytvTBSRAAPEI-74	Prionyx kirbii
INSytvTBTRAAPEI-75	Heterodontonyx sp.
INSytvTBURAAPEI-79	Monosapyga clavicornis
INSytvTBVRAAPEI-84	Sapyga quinquepunctata
INSytvTBWRAAPEI-20	Lipara lucens
INSytvTBXRAAPEI-21	Colpa sexmaculata
INSytvTBYRAAPEI-22	Polistes dominulus
INSytvTBZRAAPEI-30	Vespa crabro
INSytvTCARAAPEI-31	Celonites abbreviatus
INSytvTCBRAAPEI-33	Katamenes arbustorum
INSytvTCCRAAPEI-34	Epitheca bimaculata
INSytvTCDRAAPEI-35	Cryptocercus sp.
INSytvTCERAAPEI-36	Eurylophella sp.
INSytvTCFRAAPEI-37	Ectopsocus briggsi
INSytvTCGRAAPEI-39	Valenzuela badiostigma
INSytvTCFRAAPEI-43	Inocellia crassicornis
INSodkTAIRAAPEI-87	Nicoletia phytophila
INSodkTAKRAAPEI-89	Catara rugosicollis
INSswpTACRAAPEI-13	Tineola bisselliella
INSswpTAFRAAPEI-16	Harpactus elegans
INSswpTAXRAAPEI-17	Systropha curvicornis
INSswpTAZRAAPEI-19	Sceliphron curvatum
INSswpTBARAAPEI-20	Notiohilara paramonovi
INSswpTBBRAAPEI-21	Epeolus variegatus
INSswpTBDRAAPEI-30	Isodontia mexicana
INSswpTBERAAPEI-31	Odynerus spinipes
INSswpTBGRAAPEI-34	Nysson niger
INSswpTBHRAAPEI-35	Anabarhynchus dentiphallus
INSswpTBIRAAPEI-36	Meria tripunctata
INSswpTAIRAAPEI-19	Heteropsilopus ingenuus
INSswpTAJRAAPEI-20	Eupelmus urozonus
INSswpTARRAAPEI-11	Ceratina chalybaea
INSswpTATRAAPEI-13	Psenulus fuscipennis
INSswpTAVRAAPEI-15	Anthidium manicatum
INSswpTAWRAAPEI-16	Auplopus albifrons
INSswpTAYRAAPEI-18	Tetralonia macroglossa
INSswpTBCRAAPEI-22	Protaphorura fimata
INSswpTBJRAAPEI-37	Crabro peltarius
INSswpTBKRAAPEI-39	Pseudogalepsus nigricoxa
INSswpTBLRAAPEI-41	Coelioxys conoidea
INSswpTBMRAAPEI-43	Apiocera moerens
INSswpTBNRAAPEI-44	Bembix rostrata
INSswpTBPRAAPEI-46	Crossocerus quadrimaculatus
INSswpTBRRAAPEI-56	Podalonia hirsuta
INSswpTBURAAPEI-74	Tapeigaster digitata
INSswpTBVRAAPEI-75	Pergagrapta polita
INSswpTAARAAPEI-11	Hagiotata hofmanni
INSswpTABRAAPEI-12	Pompilus cinereus
INSswpTADRAAPEI-14	Dioxys cincta
INSswpTAKRAAPEI-21	Tachysphex fulvitarsis
INSswpTALRAAPEI-22	Acontista multicolor
INSswpTAORAAPEI-33	Lasioglossum xanthopus
INSswpTAPRAAPEI-34	Vespula germanica
INSswpTAQRAAPEI-35	Miomantis binotata
INSswpTBWRAAPEI-94	Magicicada septendecim
INSswpTBXRAAPEI-95	Magicicada tredecim
INSodkTAARAAPEI-47	Blattella germanica
INSodkTABRAAPEI-56	Diplatyidae gen.
INSodkTACRAAPEI-57	Galloisiana nipponensis
INSodkTADRAAPEI-62	Tomocerus cuspidatus
INSodkTAERAAPEI-74	Dicyrtomina leptothrix
INSodkTAFRAAPEI-75	Apteroperla tikumana
INSodkTAGRAAPEI-79	Lepidocampa weberi
INSodkTAHRAAPEI-84	Pedetontus okajimae
INSodkTAJRAAPEI-88	Machilontus sp.
INSodkTALRAAPEI-90	Zygonyx iris
INSodkTAMRAAPEI-93	Tyriobapta torrida
INSswpTAERAAPEI-15	Exaireta spinigera
INSswpTAGRAAPEI-17	Sapygina decemguttata
INSswpTAHRAAPEI-18	Chelostoma florisomne
INSswpTAMRAAPEI-30	Hylaeus variegatus
INSswpTANRAAPEI-31	Orchesella cincta
INSswpTAURABPEI-14	Aularches miliaris
INSswpTBORABPEI-45	Danuria thunbergi
INSswpTBSRABPEI-57	Podura aquatica
INSswpTBTRABPEI-62	Philanthus triangulum
INShkeTAARAAPEI-94	Apatania incerta
INShkeTABRAAPEI-95	Micrasema wataga
INShkeTACRAAPEI-8	Lepidostoma togatum
INShkeTADRAAPEI-9	Agapetus hessi
INShkeTAARAAPEI-79	Chrysis fasciata
INShkeTABRAAPEI-84	Ptosima flavoguttata
INShkeTAQRAAPEI-45	Hypochrysa elegans
INShkeTAURAAPEI-57	Phaeostigma major
INShkeTAVRAAPEI-62	Calliphora vomitoria
INShkeTACRAAPEI-87	Saturnia pyri
INShkeTAFRAAPEI-90	Hydraena nigrita/subimpressa
INShkeTAIRAAPEI-95	Acrotrichis sp.
INShkeTBDRAAPEI-74	Serica brunnea
INShkeTCCRAAPEI-37	Hydrometra aquatica
INShkeTADRAAPEI-88	Ips typographus
INShkeTAERAAPEI-89	Ergaula capucina
INShkeTAGRAAPEI-93	Thesprotia graminis
INShkeTAHRAAPEI-94	Corydalinae_VZ sp.
INShkeTAJRAAPEI-35	Mantispidae_VZ sp.
INShkeTAKRAAPEI-36	Xyela alpigena
INShkeTALRAAPEI-37	Noterus clavicornis
INShkeTAMRAAPEI-39	Catajapyx aquilonaris
INShkeTANRAAPEI-41	Lithobius forficatus
INShkeTAORAAPEI-43	Byturus ochraceus
INShkeTAPRAAPEI-44	Speleonectes tulumensis
INShkeTARRAAPEI-46	Sicus ferrugineus
INShkeTASRAAPEI-47	Rhamnusium bicolor
INShkeTATRAAPEI-56	Bicyclus anynana
INShkeTAWRABPEI-74	Sympherobius elegans
INShkeTAXRAAPEI-75	Stagmatoptera biocellata
INShkeTAYRAAPEI-79	Ptilinus pectinicornis
INShkeTAZRAAPEI-84	Raphidia mediteranea
INShkeTBARAAPEI-56	Byrrhus pilula
INShkeTBBRAAPEI-57	Microdon brachycerus
INShkeTBCRAAPEI-62	Crocothemis erythrea
INShkeTBERAAPEI-75	Cheddikulama straminea
INShkeTBFRAAPEI-79	Colias croceus
INShkeTBGRAAPEI-84	Gyna lurida
INShkeTBHRAAPEI-87	Chilocorus renipustulatus
INShkeTBIRAAPEI-88	Acanthops sp.
INShkeTBJRAAPEI-89	Dryops sp.
INShkeTBKRAAPEI-90	Elaphrus aureus
INShkeTBLRAAPEI-93	Trinotoperla montana
INShkeTBMRAAPEI-94	Diestrammena asynamora
INShkeTBNRAAPEI-95	Microcara testacea
INShkeTBQRAAPEI-11	Trachyaretaon brueckneri
INShkeTBRRAAPEI-12	Hallomenus binotatus
INShkeTBSRAAPEI-13	Trichogramma evanescens
INShkeTBURAAPEI-15	Paratemnopteryx couloniana
INShkeTBVRAAPEI-16	Hydrochus megaphallus
INShkeTBWRAAPEI-17	Diplectrona sp.
