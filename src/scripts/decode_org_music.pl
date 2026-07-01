#!/usr/bin/env perl

use strict;
use feature 'try';
use Fcntl qw(SEEK_SET SEEK_CUR SEEK_END); # better than using 0, 1, 2

$#ARGV == 1 or Usage("Wrong number of arguments");

my ($fn_bin, $fn_asm) = @ARGV;

($fn_bin and -e $fn_bin) or Usage("Cannot find capture file \"$fn_bin\"");

my $STREAM_X_START = 0x70E4;	# IX stream start
my $bin = ();

open (my $fh_bin, "<", $fn_bin) or Usage("Cannot open \"$fn_bin\" for input : $!");
binmode $fh_bin;
my $l = read($fh_bin, $bin, 0x10000);
$l == 0x10000 or Usage("$fn_bin is not exactly 64K, expecting a memory dump $l");

close $fh_bin;

# convert $bin to an array of bytes
my @bin = unpack("C*", $bin);

open (my $fh_asm, ">", $fn_asm) or Usage("Cannot open \"$fn_asm\" for output : $!");

print $fh_asm	"\t\t; Music generated - do not edit\n\n";
print $fh_asm	"\t\t.include \"music.inc\"\n";

my $offs = $STREAM_X_START;
my $echo = 0;
print $fh_asm	"\t\t.export music_x_stream\n";
printf $fh_asm	"music_x_stream:\t; X stream starts at \$%04X\n", $offs;
while ($offs < 0x10000) {

	my $x_c = @bin[$offs++];

	if ($x_c == 0x00) {
		printf $fh_asm "\t\tMX_END\n";
		printf $fh_asm "\t\t; End of X stream found at \$0x%04X\n\n", $offs;
		last;
	} elsif ($x_c == 0x01) {
		printf $fh_asm "\t\tMX_LOOP_END\n\n"
	} elsif ($x_c == 0x02) {
		my $x_r = @bin[$offs++];
		printf $fh_asm "\n\t\tMX_LOOP_START\t%d\n", $x_r + 1;
		if (!@bin[$offs]) {
			printf $fh_asm "\t\tMX_RESET_IY_5C3A\t\t; TODO: check this out?\n";
			$offs++;
		}
	} elsif ($x_c == 0xFF) {
		my $x_sc = @bin[$offs++];
		if ($x_sc == 0x01) {
			my $x_p0 = @bin[$offs++];
			my $x_p1 = @bin[$offs++];
			my $x_p2 = @bin[$offs++];
			my $x_p3 = @bin[$offs++];

			printf $fh_asm "\t\tMX_CMD_ENVELOPE\t%d, %d, %d, %d\n", $x_p0, $x_p1, $x_p2, $x_p3;
		} elsif ($x_sc == 0x02) {
			printf $fh_asm "\t\tMX_ARP_RESTART\n";
		} elsif ($x_sc == 0x03) {
			printf $fh_asm "\t\tMX_ARP_OFF\n";
		} elsif ($x_sc == 0x04) {
			printf $fh_asm "\t\tMX_ARP_ON_1\n";
		} elsif ($x_sc == 0x05) {
			printf $fh_asm "\t\tMX_ARP_ON_2\n";
		} elsif ($x_sc == 0x08) {
			my $ay_m = @bin[$offs++];
			printf $fh_asm "\t\tMX_AY_MUL %d\n", $ay_m;
		} elsif ($x_sc == 0x09) {
			$echo = 1;
			print $fh_asm "\t\tMX_ECHO_ON\n";
		} elsif ($x_sc == 0x0A) {
			$echo = 0;
			print $fh_asm "\t\tMX_ECHO_OFF\n";
		} 
	} elsif ($echo) {
		my ($e_p, $h_p, $dur) = ($x_c, @bin[$offs++], @bin[$offs++]);
		printf $fh_asm "\t\tMX_NOTE_ECHO \$%02X,\$%02X,\$%02X\n", $e_p, $h_p, $dur;
	} else {
		my ($e_p, $h_p, $d_p, $dur) = ($x_c, @bin[$offs++], @bin[$offs++], @bin[$offs++]);
		printf $fh_asm "\t\tMX_NOTE_NECHO \$%02X,\$%02X,\$%02X,\$%02X\n", $e_p, $h_p, $d_p, $dur;		
	}

}


close $fh_asm;




sub Usage($) {
	my ($msg) = @_;

	print STDERR "ERROR: $msg\n";

	print STDERR "Usage: decode_org_music <z80game.bin> <music_gen.asm>\n";

	exit 10;
}