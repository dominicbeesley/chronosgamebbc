#!/usr/bin/env perl

use strict;

my  $vv = 0.99;
my  $aa = 0.01;

my	$p = 0;		# current ear state
my  $c = 0;		# last cycle number processed
my  $s = 0;     # sample value
my  $sc= 0;		# number of cycles since last sample

binmode(STDOUT);

while (<>) {
	my $l = $_;
	$l =~ s/\s+//g;
	$l =~ s/[\s\n\r]+$//;


	if ($l =~ /^(\d+):OUT:([0-9a-f]+):([0-9a-f]+)$/i) {
		my $cc = $1;
		my $a = hex($2);
		my $d = hex($3);
		if (($a & 0xFE) == 0xFE) {
			$p = ($d & 0x10)?1:0;

			addcycles($p, $cc-$c);
			$c = $cc;

		}
	} 
}


sub addcycles($$) {
	my ($v, $n) = @_;

	for (my $i = 0; $i<$n; $i++) {
		$s = ($s*$vv) + ($p*$aa);
		$sc++;
		if ($sc >= 72) {
			print pack("s", -32768+65000*$s);
			$sc = 0;
		}
	}

}

