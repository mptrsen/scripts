#!/usr/bin/perl
use strict;
use warnings;
use autodie;
use POSIX;

my $usage = <<EOF;
$0 N M

Calculates task distribution so that each element of the set of (1 .. N)
is compared to every other element in the same set. These comparisons are
distributed across M workers.
EOF

my $nitems = shift @ARGV or die $usage;
my $nworkers = shift @ARGV or die $usage;

# calculate total number of tasks and tasks per worker
my $total  = 0;
for (my $i = 0; $i < $nitems; $i++) {
	for (my $j = 0; $j <= $i; $j++) { $total++ }
}
my $tasksperworker = ceil($total / $nworkers);

my $worker = [  ];
push @$worker, { 'imin' => 1, 'imax' => 1, 'jmin' => 1, 'jmax' => 1 } for (1 .. $nworkers);
my $k = 0;
my $tasksforthisworker = 0;

# status report
print "\n";
print "number of items: $nitems\n";
print "number of workers: $nworkers\n";
print "total tasks: $total\n";
print "tasks per worker: $tasksperworker\n";
print "\n";

for (my $i = 0; $i < $nitems; $i++) {
	for (my $j = 0; $j <= $i; $j++) {
		# start a new worker if this one would be overloaded
		if ($tasksforthisworker + 1 > $tasksperworker) {
			if ($k + 1 > scalar(@$worker)) {
				die "out of range!\n"
			}
			$k++;

			$$worker[$k]{'imin'} = $i;
			$$worker[$k]{'imax'} = $i;
			$$worker[$k]{'jmin'} = $j;
			$$worker[$k]{'jmax'} = $j;

			$tasksforthisworker = 1;
		}

		else {
			$$worker[$k]{'imin'} = $i if $$worker[$k]{'imin'} > $i;
			$$worker[$k]{'imax'} = $i if $$worker[$k]{'imax'} < $i;
			$$worker[$k]{'jmin'} = $j if $$worker[$k]{'jmin'} > $j;
			$$worker[$k]{'jmax'} = $j if $$worker[$k]{'jmax'} < $j;

			$tasksforthisworker++;
		}
	}
}

for (my $i = 0; $i < @$worker; $i++) {
	printf "tasks for worker %d: %d - %d %d - %d\n",
		$i + 1,
		$$worker[$i]{'imin'} + 1,
		$$worker[$i]{'imax'} + 1,
		$$worker[$i]{'jmin'} + 1,
		$$worker[$i]{'jmax'} + 1,
	;
}
