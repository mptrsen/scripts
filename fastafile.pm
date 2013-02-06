package fastafile;
use Carp;

sub new {
	my $filename = shift;
	open (my $fh, '<', $filename)
		or croak "Could not open $filename\: $!\n";
	my $self = {
		'filename' => $filename,
		'fh'       => $fh
	}
	bless($self, $class);
	return $self;
}

sub next_seq {
	my $self = shift;
	local $/ = "\n>";	# change the line separator
	# read the line(s)
	return unless $item = readline($self);
	chomp $item;
	
	if ($. == 1 and $item !~ /^>/) {
		croak "Not a FASTA file\n";
	}

	$item =~ s/^>//;

	my ($hdr, $seq) = split(/\n/, $item, 2);
	$seq =~ s/>//g if defined $seq;

	return($hdr, $seq);
}
