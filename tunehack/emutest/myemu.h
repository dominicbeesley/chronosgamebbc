#ifndef __MYEMU_H__
#define __MYEMU_H__

#include <Z80.h>

#define MEMORY_SIZE             65536
#define ROM_SIZE                8192
#define CYCLES_PER_FRAME        1000 

typedef struct {
        void* context;
        zuint8 (* read)(void *context);
        void (* write)(void *context, zuint8 value);
        zuint16 assigned_port;
} Device;

typedef struct {
        zusize  cycles;
        zuint8  memory[65536];
        Z80     cpu;
        Device* devices;
        zusize  device_count;
} Machine;

extern void machine_initialize(Machine *self);
extern void machine_run_frame(Machine *self);

#endif