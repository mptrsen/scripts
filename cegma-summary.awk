#!/usr/bin/awk

function min(lst) {
	m = lst[0];
	for (i = 0; i < length(lst); i++) {
		if (lst[i] < m) { m = lst[i] }
	}
	return m;
}

function max(lst) {
	m = lst[0];
	for (i = 0; i < length(lst); i++) {
		if (lst[i] > m) { m = lst[i] }
	}
	return m;
}

function mean(lst) {
	s = 0;
	for (i = 0; i < length(lst); i++) {
		s += lst[i];
	}
	return s / length(lst);
}

function stdev(lst) {
	s = 0;
	m = mean(lst);
	sd = 0;
	for (i = 0; i < length(lst); i++) {
		sd += (lst[i] - m) ^ 2;
	}
	return sqrt((1/(n-1)) * sd);
}

function median(lst) {
	n = asort(lst, lst_sort);
	if (n % 2 != 0) { return lst_sort[(n/2)+1]; }
	else  { return lst_sort[n/2]; }
}

BEGIN {
	printf "%23s %9s %10s %3s %7s %8s %7s\n", "Species name", "#Prots", "%Completeness", "-", "#Total", "Average", "%Ortho";
	print "-------------------------------------------------------------------------------";
	n = 0;
	format_d_partl = "%23s (partial)  %9d %10.2f %6s %5d %8.2f % 9.2f\n";
	format_d_compl = "%23s (complete) %9d %10.2f %6s %5d %8.2f % 9.2f\n";
	format_f = "%23s %9.2f %10.2f %6s %8.2f %5.2f % 9.2f\n";
}

/^\s+Complete\y/ { 
	prots_c[n] = $2;
	complts_c[n] = $3;
	totals_c[n] = $5;
	avgs_c[n] = $6;
	orthos_c[n] = $7;
	species = FILENAME;
	sub("\\..*$", "", species);
	sub("^cegma/", "", species);
	printf format_d_compl, species, prots_c[n], complts_c[n], "-", totals_c[n], avgs_c[n], orthos_c[n];
	n++;
}

/^\s+Partial\y/ { 
	prots_p[n] = $2;
	complts_p[n] = $3;
	totals_p[n] = $5;
	avgs_p[n] = $6;
	orthos_p[n] = $7;
	printf format_d_partl, species, prots_p[n], complts_p[n], "-", totals_p[n], avgs_p[n], orthos_p[n];
}

END {
	print "-------------------------------------------------------------------------------";
	printf format_d, "Min complete:",   min(prots_c), min(complts_c), "-", min(totals_c), min(avgs_c), min(orthos_c);
	printf format_d, "Max complete:",   max(prots_c), max(complts_c), "-", max(totals_c), max(avgs_c), max(orthos_c);
	printf format_d, "Min partial:",   min(prots_p), min(complts_p), "-", min(totals_p), min(avgs_p), min(orthos_p);
	printf format_d, "Max partial:",   max(prots_p), max(complts_p), "-", max(totals_p), max(avgs_p), max(orthos_p);
	#printf format_f, "Mean:", mean(prots_c), mean(complts_c), "-", mean(totals_c), mean(avgs_c), mean(orthos_c);
	#printf format_f, "Median:", median(prots_c), median(complts_c), "-", median(totals_c), median(avgs_c), median(orthos_c);
	#printf format_f, "Stdev:", stdev(prots_c), stdev(complts_c), "-", stdev(totals_c), stdev(avgs_c), stdev(orthos_c);
}

