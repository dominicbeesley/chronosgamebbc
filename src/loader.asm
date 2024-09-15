
		.include "oslib.inc"
		.include "hardware.inc"
		.include "mosrom.inc"

MO7SCR=$7C00
PROBE=$8009		; location to probe in SWRAM

game_romslot	:= $80			; where the game looks for rom slot


		.zeropage
zp_tmp:		.res	1
zp_tmp2:	.res	1
zp_ptr:		.res	2
		.code
		
		lda	#22
		jsr	OSWRCH
		lda	#7
		jsr	OSWRCH

		; detect nula


		; cursor off
		sei
		lda	#10
		sta	sheila_CRTC_reg
		lda	#$20
		sta	sheila_CRTC_dat
		cli

		; copy splash screen to mode 7 area

		ldx	#0
		stx	zp_tmp
clp2:		
		jsr	wait10vs

clp1:		ldx	#40
		ldy	zp_tmp
@l:		
		lda	__SPLASH_LOAD__,Y
		sta	MO7SCR,Y

		lda	__SPLASH_LOAD__+200,Y
		sta	MO7SCR+200,Y

		lda	__SPLASH_LOAD__+400,Y
		sta	MO7SCR+400,Y

		lda	__SPLASH_LOAD__+600,Y
		sta	MO7SCR+600,Y

		lda	__SPLASH_LOAD__+800,Y
		sta	MO7SCR+800,Y
		
		iny
		dex
		bne	@l
		sty	zp_tmp
		cpy	#200
		bne	clp2


		lda	zp_mos_curROM
		pha

		; check for SWRAM banks by probing first character of title
		ldx	#16
		stx	game_romslot
		dex
@ramclp:	
		stx	zp_mos_curROM
		stx	SHEILA_ROMCTL_SWR

		lda	PROBE				; get byte from ROM
		sta	zp_tmp2				; save it
		eor	#$20				; swap a bit (will change capitals on first char in title if we crash)
		sta	PROBE
		lda	PROBE
		eor	zp_tmp2
		eor	#$20
		bne	@ro		
		; if we get here it was read/write
		; put it back
		lda	zp_tmp2
		sta	PROBE
		txa
		pha
		; check for copyright string
		ldy	$8000+7
		ldx	#0
@cpcmlp:	lda	copycmp,X
		cmp	$8000,Y
		bne	@empty_slot_found
		iny
		inx
		cpx	#4
		bne	@cpcmlp
		; we found a copyright string - check title
		ldx	#9
@ticmlp:	lda	titcmp-9,X
		beq	full_slot_found			; got to end it's a match
		inx
		eor	$8000-1,X
		and	#$DF
		beq	@ticmlp				
		; title mismatch so ignore this slot
		pla
		jmp	@sk
@empty_slot_found:
		pla
		sta	game_romslot			; this will be slot to use but keep looking for lower empty
		; continue search
@sk:		tax
@ro:		dex					; next ROM slot
		bpl	@ramclp

		; we've tried all the roms
		lda	game_romslot
		cmp	#16
		bne	load_rom

		; we didn't find a free slot...bark
		jsr	PrintI
		.byte	12,"Sorry, Chronos needs a free sideways",13,10,"RAM slot",13,10,0
		jmp	exiterr

full_slot_found:
		pla
		sta	game_romslot
	.ifdef DEBUG
		lda	#'F'
		jsr	OSWRCH
		lda	game_romslot
		ora	#$30
		jsr	OSWRCH
	.endif


rom_loaded:
		; *RUN CHRONOS

		ldx	#<osclirunchronos
		ldy	#>osclirunchronos
		jsr	OSCLI


exiterr:	
		pla
		sta	zp_mos_curROM
		sta	SHEILA_ROMCTL_SWR

		rts

		

load_rom:	
	.ifdef DEBUG
		lda	#'E'
		jsr	OSWRCH
		lda	game_romslot
		ora	#$30
		jsr	OSWRCH
	.endif

		; use OSFILE to load the map data

		ldx	#<osfileblock
		ldy	#>osfileblock
		lda	#$FF
		jsr	OSFILE

		lda	game_romslot
		sta	zp_mos_curROM
		sta	SHEILA_ROMCTL_SWR

		ldy	#$40
		ldx	#0
@lp:		
@ld:		lda	__ROMIMAGE_START__,X
@st:		sta	$8000,X
		dex
		bne	@lp
		inc	@ld+2
		inc	@st+2
		dey
		bne	@lp

		jmp	rom_loaded



wait10vs:
		ldx	#10
		stx	zp_tmp2
@wlp:		lda	#19
		jsr	OSBYTE
		dec	zp_tmp2
		bne	@wlp
		rts


PrintI:		pla
		sta	zp_ptr
		pla
		sta	zp_ptr+1
		ldy	#0	
@lp:		iny
		lda	(zp_ptr),Y
		beq	@sk
		jsr	OSWRCH
		jmp	@lp
@sk:		clc
		tya
		adc	zp_ptr
		tay
		lda	#0
		adc	zp_ptr+1
		pha
		tya
		pha
		rts	

		.rodata
copycmp:	.byte	0,"(C)"
titcmp:		.byte	"chronos map data",0

		.data
osfileblock:	.word	osfilename
		.dword	__ROMIMAGE_START__
		.dword  0
		.dword  0
		.dword  0
osfilename:	.byte   "S.MAP",13
osclirunchronos:.byte   "/CHRONOS",13

		.segment	"SPLASH"
		.incbin 	"splash.mo7"
		.end