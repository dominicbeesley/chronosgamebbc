#!/usr/bin/env perl

use strict;
use File::Temp qw/ tempfile /;
use feature 'try';
use Fcntl qw(SEEK_SET SEEK_CUR SEEK_END); # better than using 0, 1, 2
use List::Util qw/ min max /;
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
`decode6502 --trigger=${\sprintf("%X,%X,1", $addr_start, 65535) } --cpu=65816 --dp=0 --db=0 --phi2= -ay $fn_bin >$fn_dec`;

$? and die "Error running decode6502 : $?";

printf "SCAN %X to %X\n", $addr_start, $addr_end;;

seek $fh_dec, 0, SEEK_SET;
my $state = 0;
my $curcycles = 0;
my @runs = ();
while(<$fh_dec>) {
	
	if (/([0-9A-F]+)\s*:[^:]+:\s*([0-9]+)/) {
			
		my ($a, $c) = (hex($1), $2);
		if ($state == 0 && $a == $addr_start) {
			$curcycles = $c;
			$state = 1;
		} elsif ($state == 1 && $a == $addr_end) {			
			push @runs, $curcycles;
			$state = 0;
		} elsif ($state == 1) {
			$curcycles += $c;
		}
	} 
}

printf "RUNS:\t%d\n", scalar(@runs);
printf "MIN:\t%d\n", min(@runs);
printf "MAX:\t%d\n", max(@runs);
printf "MEAN:\t%d\n", mean(@runs);

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