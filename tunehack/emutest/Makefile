

BUILD=./build

OBJS=main.o myemu.o
OBJS_B=$(addprefix $(BUILD)/, $(OBJS))

X:=$(shell mkdir -p $(BUILD))

all: $(BUILD)/emutest

$(BUILD)/emutest: $(OBJS_B)
	$(CC) $(CFLAGS) -o $@ $(wildcard %.o, $^) -lZ80

$(BUILD)/%.o:%.c
	$(CC) $(CFLAGS) $^ -c -o $@ 