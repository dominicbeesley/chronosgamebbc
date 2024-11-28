#!/usr/bin/env perl

use strict;
use File::Temp qw/ tempfile /;
use feature 'try';
use Fcntl qw(SEEK_SET SEEK_CUR SEEK_END); # better than using 0, 1, 2
use Statistics::Basic qw / mean /;

$#ARGV == 3 or Usage("Wrong number of arguments");

my ($fn_bin, $fn_map, $sym_start, $sym_end) = @ARGV;

($fn_bin and -e $fn_bin) or die "Cannot find capture file \"$fn_bin\"";
($fn_map and -e $fn_map) or die "Cannot find map file \"$fn_map\"";

($sym_end and $sym_start) or die "Missing start/end symbol";

my ($addr_start, $addr_end) = (-1, -1);

open (my $fh_map, "<", $fn_map) or die "Cannot open \"$fn_map\" for input : $!";
while (<$fh_map>) {

	if (/(^|\b)\Q$sym_start\E\b\s+([0-9A-F]+)/i) {
		$addr_start = hex($2);
	}

	if (/(^|\b)\Q$sym_end\E\b\s+([0-9A-F]+)/i) {
		$addr_end = hex($2);
	}
}
close $fh_map;


($addr_start != -1 && $addr_end != -1) or die "Cannot find $sym_start or $sym_end in map file";

my ($fh_dec, $fn_dec) = tempfile();
`decode6502 --trigger=${\sprintf("%X,%X,1", $addr_start, 65535) } --cpu=65816 --dp=0 --db=0 --phi2= -ayY $fn_bin >$fn_dec`;

$? and die "Error running decode6502 : $?";

printf "SCAN %X to %X\n", $addr_start, $addr_end;;

seek $fh_dec, 0, SEEK_SET;
my $state = 0;
my $curcycles = 0;
my $curstart = 0;
my @runs = ();
while(<$fh_dec>) {
	
	if (/([0-9A-F]+)\s*:\s*([0-9A-F]+)\s*:[^:]+:\s*([0-9]+)/) {
			
		my ($s, $a, $c) = (hex($1), hex($2), $3);
		if ($state == 0 && $a == $addr_start) {
			$curcycles = $c;
			$curstart = $s;
			$state = 1;
		} elsif ($state == 1 && $a == $addr_end) {			
			push @runs, { cycles=>$curcycles, start=>$curstart };
			$state = 0;
		} elsif ($state == 1) {
			$curcycles += $c;
		}
	} 
}

my ($min, $minsam, $max, $maxsam, $mean, $n) = (-1, -1, -1, -1, 0, 0);

foreach my $r (@runs) {

	if ($min<0 || $r->{cycles} < $min) {
		$min = $r->{cycles};
		$minsam = $r->{start};
	}
	if ($max<0 || $r->{cycles} > $max) {
		$max = $r->{cycles};
		$maxsam = $r->{start};
	}
	$mean += $r->{cycles};
	$n++;
}

if ($n > 0) {
	$mean = $mean / $n;

	printf "RUNS:\t%d\n", $n;
	printf "MIN:\t%d @ %08x\n", $min, $minsam;
	printf "MAX:\t%d @ %08x\n", $max, $maxsam;
	printf "MEAN:\t%d\n", $mean;

	# histogram

	my $peak = 0;

	if (($max - $min) > 100) {

		my $NH = 10;
		my $S = (($max - $min) / ($NH-1));
		my @r = (0) x $NH;

		foreach my $r (@runs) {
			my $ix = int(($r->{cycles} - $min) / $S);
			my $c = $r[$ix] + 1;
			if ($c > $peak) {
				$peak = $c;
			}
			$r[$ix] = $c;
		}

		my $scale = 50 / $peak;

		for (my $i = 0; $i < $NH; $i++) {
			printf "%8d : ", $min+$i*$S;
			print "#" x (@r[$i] * $scale);
			print "\n";
		}

	}


} else {
	die "No runs found";
}
END {
	if (-e $fn_dec) {
		unlink $fn_dec;
	}
}


sub Usage($) {
	my ($msg) = @_;

	print STDERR "ERROR: $msg\n";

	print STDERR "Usage: stats <fx2sharp.bin> <game.map> <symbol_start> <symbol_end>\n";

	exit 10;
}