
		.include "oslib.inc"
		.include "hardware.inc"
		.include "mosrom.inc"

MO7SCR=$7C00
PROBE=$8009		; location to probe in SWRAM

GAME_EXEC	:= $1800
GAME_LOAD	:= $1800

game_romslot	:= $80			; where the game looks for rom slot

		.zeropage
zp_tmp:		.res	1
zp_tmp2:	.res	1
zp_tmp3:	.res	1
zp_ptr:		.res	2
zp_nula_absent:	.res	1
		.code
		
		; *SHADOW OFF
		lda 	#114
		ldx 	#1
		jsr 	OSBYTE

		; check for TUBE
		lda 	#$EA
		ldx	#$0
		ldy	#$FF
		jsr 	OSBYTE
		cpy	#0	
		beq	@oktube
		jmp	badtube

@oktube:	

		; select mode 7

		lda	#22
		jsr	OSWRCH
		lda	#7
		jsr	OSWRCH

		; detect nula

		sei		; we're going to usurp interrupts for a moment to
				; do this


		; first force a double speed mode 7 by writing &52 to
		; the VIDPROC (and OS copy)

		lda	#$52
		sta	sheila_VIDPROC_ctl
		
		; now store &40 in NULA control register
		; if NULA present NULA resets, VIDPROC unaffected
		; if NULA absent VIDPROC is reset to mode 7 speed (but not ttx, white stripes)
		lda	#$40
		sta	SHEILA_NULA_CTLAUX

		ldx	#0	; count of VSYNCS
		ldy	#0	; count of T1 (100 Hz ticks)

		lda	#$42	; clear T1 and CA1 (VSYNC) interrupt flags
		sta	sheila_SYSVIA_ifr

@lp:		lda	#$40
		bit	sheila_SYSVIA_ifr
		beq	@noT1
		iny		; count T1
		sta	sheila_SYSVIA_ifr	; reset interrupt flag for T1
@noT1:		lda	#$02
		bit	sheila_SYSVIA_ifr
		beq	@noCA1
		inx		; count CA1
		sta	sheila_SYSVIA_ifr	; reset interrupt flag for CA1
@noCA1:		cpx	#25
		bne	@lp

		lda	#0
		cpy	#40
		ror	A
		sta	zp_nula_absent

		lda	#$4b
		sta	sheila_VIDPROC_ctl	; restore VIDPROC

		cli				; re-enable interrupts
		
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

		lda	#31
		jsr	OSWRCH
		lda	#5		
		jsr	OSWRCH
		lda	#18
		jsr	OSWRCH

				


		bit	zp_nula_absent
		bmi	@nonula
		jsr	PrintI
		.byte	129, "VideNuLa detected",145,0

		ldx	#<osfilen_chronon
		stx	osfilechronos+0
		ldx	#>osfilen_chronon
		stx	osfilechronos+1

		jmp	@nn
@nonula:	jsr	PrintI
		.byte	135, "VideNuLa not present",145,0
@nn:




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
		beq	@bad
		jmp	load_rom
@bad:
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
		; *LOAD CHRONOS 1800

		ldx	#<osfilechronos
		ldy	#>osfilechronos
		lda	#$FF
		jsr	OSFILE

		; wait up a second
		ldx	#50
		stx	zp_tmp
@wlp:		lda	#19
		jsr	OSBYTE
		dec	zp_tmp
		bne	@wlp



		; fade out

		ldx	#$7
		stx	zp_tmp2			; number of fades
@flp3:		ldx	#$4			; number of pages
		stx	zp_tmp
		lda	#<MO7SCR
		sta	zp_ptr
		lda	#>MO7SCR
		sta	zp_ptr+1
		jsr	wait10vs
@flp2:		ldy	#0
@flp:		lda	(zp_ptr),Y
		cmp	#129
		bcc	@sk
		cmp	#136
		bcc	@do
		cmp	#145
		bcc	@sk
		cmp	#152
		bcs	@sk
@do:		sec
		sbc	#1
		cmp	#128
		beq	@blk
		cmp	#144
		bne	@nxt
@blk:		lda	#152		; conceal
@nxt:		sta	(zp_ptr),Y		
@sk:		iny
		bne	@flp
		inc	zp_ptr+1
		dec	zp_tmp
		bne	@flp2

		dec	zp_tmp2
		bne	@flp3


		jmp	GAME_EXEC		; enter game


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
		lda	#5
		sta	zp_tmp3
@wlp:		lda	#19
		jsr	OSBYTE
		dec	zp_tmp3
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

PrintHex:	pha
		lsr 	A
		lsr 	A
		lsr 	A
		lsr 	A
		jsr	PrintHexNyb
		pla
PrintHexNyb:	AND	#$0F
		CMP	#$0A		; set carry for +1 if >9	
		BCC	@noa	; branch if <=9
		ADC	#6		; adjust if A to F
					; (six plus carry = 7!)
@noa:		ADC	#'0'		; add ASCII "0"
		jsr	OSWRCH
		rts


badtube:	jsr	PrintI
		.byte	"Sorry, this game doesn't run on the TUBE",13,10,0
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
osfilechronos:	.word	osfilen_chronos
		.dword	GAME_LOAD
		.dword	0
		.dword	0
		.dword	0
osfilen_chronos:.byte   "CHRONOS",13
osfilen_chronon:.byte   "CHRONON",13

		.segment	"SPLASH"
		.incbin 	"splash.mo7"
		.end