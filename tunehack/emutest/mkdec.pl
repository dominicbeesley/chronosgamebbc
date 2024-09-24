#!/usr/bin/env perl

use strict;

# these are all inverted on output
use constant {
	M1		=> 1<<8,
	RD		=> 1<<9,
	WR		=> 1<<10,
	MREQ	=> 1<<11,
	IOREQ	=> 1<<12,
	WAIT	=> 1<<13,
	RST		=> 1<<14,
	PHI		=> 1<<14,

	NODATA  => 0xFF
};


binmode STDOUT;

while (<>) {
	my $l = $_;
	$l =~ s/\s+//g;
	$l =~ s/[\s\n\r]+$//;

	print STDERR ":$l:\n";

	if ($l =~ /^\d+:FOP:([0-9a-f]+):([0-9a-f]+)$/i) {
		my $d = hex($2);
		cycle(M1|RD|MREQ, 	NODATA);#T1
		cycle(M1|RD|MREQ, 	$d);	#T2
		cycle(0,			NODATA);#T3/refresh
		cycle(MREQ,			NODATA);#T4
	} elsif ($l =~ /^\d+:F:([0-9a-f]+):([0-9a-f]+)$/i) {
		my $d = hex($2);
		cycle(RD|MREQ, 		NODATA);#T1
		cycle(RD|MREQ, 		$d);	#T2
		cycle(0,			NODATA);#T3
	} elsif ($l =~ /^\d+:RD:([0-9a-f]+):([0-9a-f]+)$/i) {
		my $d = hex($2);
		cycle(RD|MREQ, 		NODATA);#T1
		cycle(RD|MREQ, 		$d);	#T2
		cycle(0,			NODATA);#T3
	} elsif ($l =~ /^\d+:WR:([0-9a-f]+):([0-9a-f]+)$/i) {
		my $d = hex($2);
		cycle(MREQ, 		$d);#T1
		cycle(WR|MREQ, 		$d);#T2
		cycle(0,			$d);#T3
	} elsif ($l =~ /^\d+:IN:([0-9a-f]+):([0-9a-f]+)$/i) {
		my $d = hex($2);
		cycle(IOREQ,		NODATA);#T1
		cycle(RD|IOREQ,		$d);	#T2
		cycle(0,			NODATA);#T3
	} elsif ($l =~ /^\d+:OUT:([0-9a-f]+):([0-9a-f]+)$/i) {
		my $d = hex($2);
		cycle(WR|IOREQ,		$d);#T1
		cycle(WR|IOREQ,		$d);#T2
		cycle(0,			$d);#T3
	} else {
		die "Unrecognised line $l";
	}


}


sub cycle($$) {
	my ($flags, $data) = @_;
	printf STDERR "%X %X\n", $flags >> 8, $data;
	print pack("S", (($flags ^ 0xFF00) & 0xFF00) | $data);
}