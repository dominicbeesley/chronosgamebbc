		include ../Makefile.defs

AS=ca65 
ASFLAGS=--auto-import -I $(TOP)/includes -I $(BUILD) -DDEBUG -DDO_DEBUG_STRIPES -DDO_DEBUG_USERPORT
LD=ld65
INCS=$(wildcard $(TOP)/includes/*.inc) 
DEPS=$(INCS) 
TARGETS=game.bin sound.bin loader.bin map.rom
OBJS_game.bin=	game irq
OBJS_sound.bin=	sound
OBJS_loader.bin= loader
OBJS_map.rom= mapheader
SPECSRC=./specSrc

TARGETS_B = $(addprefix $(BUILD)/,$(TARGETS))

DEPLOY=$(DEPLOY_TOP)
SSD=$(SSDS)/chronos.ssd
SSD_FILES=game.bin sound.bin loader.bin map.rom

SSD_FILES_B=$(addprefix $(BUILD)/, $(addsuffix .inf, $(SSD_FILES)))
SSD_EXTRAS=boot.txt 

ssd: all $(SSD)

deploy: all ssd
	mkdir -p $(DEPLOY)
	dfs read -i -d $(DEPLOY) $(SSD)

$(SSD):	$(SSD_FILES_B)
	dfs form -80 $(SSD)
	dfs title $(SSD) "chronos"
	dfs opt4 -3 $(SSD)
	dfs add $(SSD) $(SSD_FILES_B) $(SSD_EXTRAS)


all:	$(TARGETS_B)


UC=$(shell echo '$1'|tr '[:lower:]' '[:upper:]')

$(BUILD)/game.bin:$(addprefix $(BUILD)/, $(addsuffix .o, $(OBJS_game.bin))) game.cfg
	$(LD) -vm -Ln $(basename $@).sy2 -m $(basename $@).map --dbgfile $(basename $@).dbg -o $@ -C $(filter %.cfg, $^) $(filter %.o, $^) $(LIBS)
	echo "$$.CHRONOS FFFF1800 FFFF1800" >$@.inf
	$(SCRIPTS)/ca65lstupdate.pl $(basename $@).dbg $(BUILD)
	$(SCRIPTS)/getsymbols.pl <$(basename $@).sy2 >$(basename $@).1.noi
	$(SCRIPTS)/ld65debugsymbols.pl $(basename $@).dbg $(basename $@).2.noi

$(BUILD)/sound.bin:$(addprefix $(BUILD)/, $(addsuffix .o, $(OBJS_sound.bin))) sound.cfg
	$(LD) -vm -Ln $(basename $@).sy2 -m $(basename $@).map --dbgfile $(basename $@).dbg -o $@ -C $(filter %.cfg, $^) $(filter %.o, $^) $(LIBS)
	echo "$$.SOUND FFFF1800 FFFF1800" >$@.inf
	$(SCRIPTS)/ca65lstupdate.pl $(basename $@).dbg $(BUILD)
	$(SCRIPTS)/getsymbols.pl <$(basename $@).sy2 >$(basename $@).1.noi
	$(SCRIPTS)/ld65debugsymbols.pl $(basename $@).dbg $(basename $@).2.noi
	da65 --start-addr 0x1800 $@ -o $@.da.s -v -v -v

$(BUILD)/loader.bin:$(addprefix $(BUILD)/, $(addsuffix .o, $(OBJS_loader.bin))) loader.cfg
	$(LD) -vm -Ln $(basename $@).sy2 -m $(basename $@).map --dbgfile $(basename $@).dbg -o $@ -C $(filter %.cfg, $^) $(filter %.o, $^) $(LIBS)
	echo "$$.LOADER FFFF7000 FFFF7400" >$@.inf
	$(SCRIPTS)/ca65lstupdate.pl $(basename $@).dbg $(BUILD)
	$(SCRIPTS)/getsymbols.pl <$(basename $@).sy2 >$(basename $@).1.noi
	$(SCRIPTS)/ld65debugsymbols.pl $(basename $@).dbg $(basename $@).2.noi

$(BUILD)/map.rom:$(addprefix $(BUILD)/, $(addsuffix .o, $(OBJS_map.rom))) map.cfg
	$(LD) -vm -Ln $(basename $@).sy2 -m $(basename $@).map --dbgfile $(basename $@).dbg -o $@ -C $(filter %.cfg, $^) $(filter %.o, $^) $(LIBS)
	echo "S.MAP FFFF8000 FFFF8000" >$@.inf
	$(SCRIPTS)/ca65lstupdate.pl $(basename $@).dbg $(BUILD)
	$(SCRIPTS)/getsymbols.pl <$(basename $@).sy2 >$(basename $@).1.noi
	$(SCRIPTS)/ld65debugsymbols.pl $(basename $@).dbg $(basename $@).2.noi


$(BUILD)/%.o: 	%.asm $(DEPS) 
	$(AS) $(ASFLAGS) -o $@ -g -l $(basename $@).lst $<

$(BUILD)/%.o: 	$(BUILD)/%.asm $(DEPS) 
	$(AS) $(ASFLAGS) -o $@ -g -l $(basename $@).lst $<


$(BUILD)/blocks16x16_spec.bin: $(SPECSRC)/chronosm.bin
	$dd if=$< of=$@ bs=32 skip=1024 count=128
$(BUILD)/ships_spec.bin: $(SPECSRC)/chronosm.bin
	dd if=$< of=$@ bs=32 skip=1024 count=4

$(BUILD)/blocks16x16.bin: $(SPECSRC)/chronosm.bin
	$(SCRIPTS)/tileconv.py --bpp2 --mask 0xF0 --offset 0x8000 --count 128 $< $@
$(BUILD)/player.bin: $(SPECSRC)/chronosm.bin
	$(SCRIPTS)/tileconv.py --bpp2 --mask 0xF0 --width 4 --height 8 --offset 0xCC6E --count 2 --permute RII $< $@
$(BUILD)/chronospipe.bin: $(SPECSRC)/chronosm.bin
	$(SCRIPTS)/tileconv.py --bpp2 --mask 0xF0 --width 18 --height 32 --offset 0x64A8 --count 1 $< $@

$(BUILD)/numfont.f1: $(SPECSRC)/chronosm.bin
	$(SCRIPTS)/numfont.py $< $@
$(BUILD)/numfont.f2: $(BUILD)/numfont.f1
	$(SCRIPTS)/tileconv.py --bpp2 --width 1 --height 8 --offset 0x0 --count 10 $< $@

$(BUILD)/map.bin: $(SPECSRC)/chronosm.bin
#	dd if=$< of=$@ bs=1 skip=$$(( 0x8000 * 1 )) count=$$(( 0x36e2 * 1 ))
	dd if=$< of=$@ bs=256 skip=$$(( 0x90 )) count=$$(( 0x37 ))

$(BUILD)/game.o:		$(BUILD)/chronospipe.bin
$(BUILD)/game.o:		$(BUILD)/blocks16x16.bin
$(BUILD)/game.o:		$(BUILD)/player.bin
$(BUILD)/game.o:		$(BUILD)/numfont.f2

$(BUILD)/mapheader.o:	$(BUILD)/map.bin


clean:
	-rm $(TARGETS_B) 2>/dev/null
	-rm $(foreach t, $(basename $(TARGETS)), $(foreach e,.map .sy2 .1.noi .2.noi .noi .dbg .mos.inf .da.s .bin.inf, $(addsuffix $(e), $(addprefix $(BUILD)/,$(t))))) 2>/dev/null
	-rm $(foreach t, $(TARGETS), $(foreach o, $(OBJS_$(t)), $(foreach e,.lst .o .lst.rel, $(addsuffix $(e), $(addprefix $(BUILD)/,$(o)))))) 2>/dev/null
	-rm $(BUILD)/blocks16x16.bin
	-rm $(BUILD)/player.bin
	-rm $(BUILD)/chronospipe.bin
	-rm $(BUILD)/numfont.f1
	-rm $(BUILD)/numfont.f2
	-rm $(BUILD)/map.bin
	-rm $(BUILD)/map.bin.inf
	-rm $(SSD)

