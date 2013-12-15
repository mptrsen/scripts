#!/usr/bin/perl
use strict;
use warnings;

use File::Basename;
use IO::File;
use Data::Dumper;

my $assdir = shift @ARGV;
my $data = {};
my %species = ();

# get the assembly->species list
while (<DATA>) {
	chomp;
	my @cols = split("\t");
	$species{$cols[0]} = $cols[1];
}

# read all hmmsearch result files
foreach my $file (@ARGV) {
	# stitch together the real filename
	(my $assfile = $file) =~ s/\.domtblout$//;
	$assfile = File::Spec->catfile($assdir, basename($assfile));

	# open file
	my $fh = IO::File->new($file);
	while (<$fh>) {
		# skip comments and empty lines
		next if /^#/;
		next if /^\s*$/;

		# split by whitespace
		my @fields = split;

		# initialize the array only once
		unless(ref($$data{$assfile})) { $$data{$assfile} = [] }
		
		# store data
		push(@{$$data{$assfile}}, {
			'target_name' => $fields[0],
			'i-Evalue'    => $fields[12],
			'score'       => $fields[13],
			'ali_from'    => $fields[17],
			'ali_to'      => $fields[18],
			'env_from'    => $fields[19],
			'env_to'      => $fields[20]
		});
	}
	# free mem
	undef($fh);
}

# output
foreach my $ass (keys %$data) {
	# parse the assembly ID from the filename
	(my $assembly = basename($ass)) =~ s/.*INS/INS/;
	$assembly =~ s/_.*//;

	printf("# Assembly: %s (%s)\n", $assembly, $species{$assembly});

	# each data element is a list of hashes
	foreach my $hitlist (@$data{$ass}) {
		printf("# %- 46s %8s %5s %8s %-8s\n", 'target_name', 'i-Evalue', 'score', 'ali_from', 'ali_to', 'env_from', 'env_to');
		printf("# %- 46s %8s %5s %8s %-8s\n", '-' x 46, '-' x 8, '-' x 5, '-' x 8, '-' x 6);

		# get the hit sequences
		my $sequences = &slurpfasta($ass);

		foreach my $hit (@$hitlist) {
			printf(">%- 47s %4.1e %- 6.1f %-8d %-8d %-8d %-8d\n%s\n", 
				$$hit{'target_name'},
				$$hit{'i-Evalue'},
				$$hit{'score'},
				$$hit{'ali_from'},
				$$hit{'ali_to'},
				$$hit{'env_from'},
				$$hit{'env_to'},
				$$sequences{$$hit{'target_name'}}
			);
		}

		# free mem
		undef($sequences);
	}
	print "#\n";
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

package Seqload::Fasta;
use Carp;

# Constructor. Returns a sequence database object.
sub open {
  my ($class, $filename) = @_;
  open (my $fh, '<', $filename)
    or confess "Fatal: Could not open $filename\: $!\n";
  my $self = {
    'filename' => $filename,
    'fh'       => $fh
  };
  bless($self, $class);
  return $self;
}

# Returns the next sequence as an array (hdr, seq). 
# Useful for looping through a seq database.
sub next_seq {
  my $self = shift;
  my $fh = $self->{'fh'};
  local $/ = "\n>"; # change the line separator
  return unless defined(my $item = readline($fh));  # read the line(s)
  chomp $item;
  
  if ($. == 1 and $item !~ /^>/) {  # first line is not a header
    croak "Fatal: " . $self->{'filename'} . " is not a FASTA file: Missing descriptor line\n";
  }

  $item =~ s/^>//;

  my ($hdr, $seq) = split(/\n/, $item, 2);
  $seq =~ s/>//g if defined $seq;
  $seq =~ s/\s+//g if defined $seq; # remove all whitespace, including newlines

  return($hdr, $seq);
}

# Destructor. Closes the file and undefs the database object.
sub close {
  my $self = shift;
  my $fh = $self->{'fh'};
  my $filename = $self->{'filename'};
  close($fh) or croak "Fatal: Could not close $filename\: $!\n";
  undef($self);
}

# I dunno if this is required but I guess this is called when you undef() an object
sub DESTROY {
  my $self = shift;
  $self->close;
}


# validates a fasta file by looking at the FIRST (header, sequence) pair
# arguments: scalar string path to file
# returns: true on validation, false otherwise
sub check_if_fasta {
	my $infile = shift;
	my $infh = Seqload::Fasta->open($infile);
	my ($h, $s) = $infh->next_seq() or return 0;
	return 1;
}
# return true
1;

__END__
INSbusTBSRABPEI-146	Neotermes cubanus
INSbusTBNRABPEI-121	Andrena vaga
INSbusTBGRABPEI-127	Anthophora plumipes
INSbusTBCRABPEI-135	Bibio marci
INSbusTBKRAAPEI-76	Bombylius major
INSbusTBHRABPEI-138	Chrysura austriaca
INSbusTBRRAAPEI-83	Cleptes nitidulus
INSbusTBARABPEI-119	Colletes cunicularius
INSbusTBLRAAPEI-77	Corythucha ciliata
INSbusTBDRAAPEI-79	Eriocrania cf. subpurpurella
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
INSnfrTAYRAAPEI-13	Anthocharis  cardamines
INSnfrTAZRAAPEI-14	Pentachrysis inaequalis
INSnfrTASRAAPEI-41	Chrysis analis
INSnfrTBBRAAPEI-16	Mesembrina meridiana
INSnfrTBDRAAPEI-18	Hedychridium ardens
INSnfrTBERAAPEI-19	Gyrinus marinus
INSnfrTBFRAAPEI-90	Triarthria setipennis
INSnfrTBGRAAPEI-93	Donacia marginata
INSnfrTBHRAAPEI-94	Trigoniophthalmus cf. alternatus
INSnfrTBIRAAPEI-95	Ceuthophilus sp.
INSnfrTBJRAAPEI-8	Hydroptilidae sp.
INSnfrTBNRAAPEI-13	Dasymutilla gloriosa
INSnfrTBORAAPEI-14	Sphecius convallis
INSnfrTBPRAAPEI-15	Timema cristinae
INSnfrTBARAAPEI-15	Ceratophyllus gallinae
INSnfrTBCRAAPEI-17	Thyatira batis
INSnfrTBKRAAPEI-9	Grylloblatta bifratrilecta
INSnfrTBLRAAPEI-11	Okanagana villosa
INSnfrTBMRAAPEI-12	Cimbex cf. pacifica
INSnfrTBQRAAPEI-16	Cyphoderris sp.
INSfrgTBERAAPEI-30	Chyphotes sp.
INSfrgTALRAAPEI-22	Apachyus chartaceus
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
INSfrgTAURAAPEI-39	Cyphoderidae sp.
INSfrgTAVRAAPEI-41	Blaberus atropus
INSfrgTAWRAAPEI-43	Libellula quadrimaculata
INSfrgTAYRAAPEI-45	Aphidius colemani
INSfrgTAZRAAPEI-46	Aposthonia japonica
INSfrgTBARAAPEI-47	Pyrrhosoma nymphula
INSfrgTBBRAAPEI-56	Nilaparvata lugens
INSfrgTBCRAAPEI-57	Tanzaniophasma sp.
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
INSjdsTBHRAAPEI-74	Cordulegaster boltoni
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
