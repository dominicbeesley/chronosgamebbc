#include "myemu.h"
#include <stdlib.h>
#include <string.h>
#include <stdio.h>

Device *machine_find_device(Machine *self, zuint16 port)
{
        zusize index = 0;

        for (; index < self->device_count; index++)
                if (self->devices[index].assigned_port == port)
                        return &self->devices[index];

                return NULL;
}

zusize getcyc(Machine *self) {
        return self->cycles + self->cpu.cycles + z80_in_cycle(&self->cpu);
}

static zuint8 p(const char *lbl, zuint16 addr, zuint8 v, zusize cyc) {
        printf("%12ld:%s%04X:%02X\n", cyc, lbl, addr, v);
        return v;
}


static zuint8 _read_int(Machine *self, zuint16 address)
{
        zuint8 r = address < MEMORY_SIZE ? self->memory[address] : 0xFF;
        return r;
}


static zuint8 machine_cpu_read(Machine *self, zuint16 address) {
        return p("RD: ", address, _read_int(self, address), getcyc(self));
}

static zuint8 machine_cpu_nop(Machine *self, zuint16 address) {
        return p("NOP:", address, _read_int(self, address), getcyc(self));
}

static zuint8 machine_cpu_fetch(Machine *self, zuint16 address) {
        return p("F:  ", address, _read_int(self, address), getcyc(self));
}

static zuint8 machine_cpu_fetch_opcode(Machine *self, zuint16 address) {
        return p("FOP:", address, _read_int(self, address), getcyc(self));
}



static void machine_cpu_write(Machine *self, zuint16 address, zuint8 value)
{
        p("WR :", address, value, getcyc(self));
        if (address >= ROM_SIZE && address < MEMORY_SIZE)
                self->memory[address] = value;
}


static zuint8 machine_cpu_in(Machine *self, zuint16 port)
{
        Device *device = machine_find_device(self, port);

        zuint8 value = device != NULL ? device->read(device->context) : 0xFF;
        p("IN :", port, value, getcyc(self));

        return value;
}


static void machine_cpu_out(Machine *self, zuint16 port, zuint8 value)
{
        Device *device = machine_find_device(self, port);

        p("OUT:", port, value, getcyc(self));

        if (device != NULL) device->write(device->context, value);
}


void machine_initialize(Machine *self)
{
        self->cpu.context      = self;
        self->cpu.fetch_opcode = (Z80Read )machine_cpu_fetch_opcode;
        self->cpu.fetch        = (Z80Read )machine_cpu_fetch;
        self->cpu.nop          = (Z80Read )machine_cpu_nop;
        self->cpu.read         = (Z80Read )machine_cpu_read;
        self->cpu.write        = (Z80Write)machine_cpu_write;
        self->cpu.in           = (Z80Read )machine_cpu_in;
        self->cpu.out          = (Z80Write)machine_cpu_out;
        self->cpu.halt         = NULL;
        self->cpu.nmia         = NULL;
        self->cpu.inta         = NULL;
        self->cpu.int_fetch    = NULL;
        self->cpu.ld_i_a       = NULL;
        self->cpu.ld_r_a       = NULL;
        self->cpu.reti         = NULL;
        self->cpu.retn         = NULL;
        self->cpu.hook         = NULL;
        self->cpu.illegal      = NULL;
        self->cpu.options      = Z80_MODEL_ZILOG_NMOS;
        self->device_count     = 0;
        self->devices          = NULL;

        Z80_PC(self->cpu) = 0;

/* Create and initialize devices... */
}


void machine_power(Machine *self, zboolean state)
{
        if (state)
        {
                self->cycles = 0;
                memset(self->memory, 0, 65536);
        }

        z80_power(&self->cpu, state);
}


void machine_reset(Machine *self)
{
        z80_instant_reset(&self->cpu);
}


void machine_run_frame(Machine *self)
{
        self->cycles += z80_execute(&self->cpu, CYCLES_PER_FRAME);

//        self->cycles -= CYCLES_PER_FRAME;
}