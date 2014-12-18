#!/usr/bin/perl
use strict;
use warnings;
use autodie;
use POSIX;

my $usage = <<EOF;
$0 N M

Calculates task distribution so that each element of the set of (1 .. N) is compared to every other element in the same set. These comparisons are distributed across M workers.
EOF

my $nitems = shift @ARGV or die $usage;
my $nparts = shift @ARGV or die $usage;

my $matrix = [ ];
my $total  = 0;

for (my $i = 0; $i < $nitems; $i++) {
	for (my $j = 0; $j < $nitems; $j++) {
		if ($i >= $j) { $total++ }
	}
}

my $tasksperworker = ceil($total / $nparts);
my $worker = [  ];
push @$worker, { 'imin' => 1, 'imax' => 1, 'jmin' => 1, 'jmax' => 1 } for (1 .. $nparts);
my $k = 0;
my $tasksforthisworker = 0;

##########################
# pretty-print the matrix. don't do this for values of N above 25 or so unless
# you have a REALLY LARGE screen.
##########################

#--------------------------------------------------
# print ' ' x (length($nitems)), '| ';
# foreach (1 .. $nitems) {
# 	print $_ < 9 ? $_ . ' ' x length($nitems)  : $_ . ' ';
# }
# print "\n";
# print '-' x length($nitems), '+', '-' x ($nitems * (length($nitems) + 1) - 1);
# print "\n";
#-------------------------------------------------- 

for (my $i = 0; $i < $nitems; $i++) {
	# pretty-print the matrix
	#print $i + 1, $i < 9 ? ' | ' : '| ';
	for (my $j = 0; $j < $nitems; $j++) {
		if ($i >= $j) {

			# start a new worker if this one would be overloaded
			if ($tasksforthisworker + 1 > $tasksperworker) {
				$k++;

				$$worker[$k]{'imin'} = $i + 1;
				$$worker[$k]{'imax'} = $i + 1;
				$$worker[$k]{'jmin'} = $j + 1;
				$$worker[$k]{'jmax'} = $j + 1;

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
		# pretty-print the matrix
		#print $$matrix[$i][$j], '  ';
	}
	# pretty-print the matrix
	#print "\n";
}

print "\n";
print "number of items: $nitems\n";
print "total tasks: $total\n";
print "tasks per worker: $tasksperworker\n";
print "\n";

for (my $i = 0; $i < @$worker; $i++) {
	printf "tasks for worker %d: %d - %d %d - %d\n", $i + 1, $$worker[$i]{'imin'}, $$worker[$i]{'imax'}, $$worker[$i]{'jmin'}, $$worker[$i]{'jmax'};
}
