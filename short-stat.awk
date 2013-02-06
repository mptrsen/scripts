#!/usr/bin/awk
BEGIN {
	e_min = 99999999;
	e_max = 0;
	e_sum = 0;
	s_min = 99999999;
	s_max = 0;
	s_sum = 0;
	l_min = 999999;
	l_max = 0;
	l_sum = 0;
	sum = 0;
}

!/^#/ {
	sum++;
	if ($13 < e_min) {e_min = $13};
	if ($13 > e_max) {e_max = $13};
	e_sum += $13;
	if ($14 < s_min) {s_min = $14};
	if ($14 > s_max) {s_max = $14};
	s_sum += $14;
	if ($21-$20 < l_min) {l_min = $21-$20};
	if ($21-$20 > l_max) {l_max = $21-$20};
	l_sum += $21-$20;
}

END {
	printf("%d hits\n", sum);
	printf("%-7s %-7s %-7s %-7s %-7s %-7s\n", "e_min", "e_max", "e_mean", "s_min", "s_max", "s_mean");
	printf("%-1.1e %-1.1e %-1.1e %-7.1f %-7.1f %-7.1f\n", e_min, e_max, e_sum/sum, s_min, s_max, s_sum/sum); 
	printf("minimal hit length: %d\nmaximal hit length: %d\nmean hit length: %d\n", l_min, l_max, l_sum/sum);
}
