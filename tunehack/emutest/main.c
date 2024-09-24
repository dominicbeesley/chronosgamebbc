#include "myemu.h"
#include <stdio.h>
#include <getopt.h>

int main(int argc, const char **argv) {

	Machine m;
	machine_initialize(&m);


	FILE *fin = fopen("../chronosm_playing.bin", "rb");
	fread(&m.memory[0], 1, 65536, fin);
	fclose(fin);

    Z80_PC(m.cpu) = 0xEFC0; // music player start


	for (int i = 0; i < 35000; i++)
	machine_run_frame(&m);
}