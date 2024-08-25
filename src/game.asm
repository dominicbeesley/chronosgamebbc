
		.include "oslib.inc"
		.include "hardware.inc"
		.include "mosrom.inc"

TILE_BLANK=$7F
PLAYFIELD_STRIDE	:= 32*8*2
PLAYFIELD_SIZE  	:= $2000
PLAYFIELD_TOP		:= $8000-16*PLAYFIELD_STRIDE

STARS_COUNT	:= 16
	.struct star
		addr	.word		; address on screen
		bits	.byte		; bitmap		
		movect	.byte		; when this overflows skip a move
	.endstruct


		.zeropage
zp_tmp:		.res 	1		; temporary
zp_tmp2:	.res 	1		; temporary
zp_tiledst_ptr:	.res 	2		; current tile destination in the tile column
zp_tilesrc_ptr:	.res	2		; current tile source pointer
zp_map_ptr:	.res	2		; pointer into map data
zp_map_rle:	.res	1		; if <>0 then repeat this many tile=7F's
zp_cycle:	.res	1		; modulo 16 cycle counter, scroll 1 byte every 4 display new tiles every 16

		.data
playfield_top_crtc:	.word	PLAYFIELD_TOP / 8			; start of playfield screen (in crtc address)
playfield_top:		.word	PLAYFIELD_TOP				; start of playfield screen (in RAM address)
tiles_top:		.word	PLAYFIELD_TOP + PLAYFIELD_STRIDE+32


		.macro LDXY addr
		ldx	#<(addr)
		ldy	#>(addr)
		.endmacro


		.code

		sei

		; stop VIA interrupts
		lda	#$7F
		sta	sheila_SYSVIA_ier
		sta	sheila_USRVIA_ier

		; TODO: other VIA setup - for now assume its ready from MOS
		lda 	#4   
		sta 	sheila_SYSVIA_pcr	; vsync \\ CA1 negative-active-edge CA2 input-positive-active-edge CB1 negative-active-edge CB2 input-nagative-active-edge

		; setup CRTC / ULA for our special small mode for playfield
		lda	#$D8			; mode 1 : 7=%10= mo.1 cursor, 4:1=20k, 3:2 = 40 chars, 1=0 no ttx, 0=0 no flash
		sta	sheila_VIDPROC_ctl

		ldx	#11
@clp:		txa
		sta	sheila_CRTC_reg
		lda	playfield_CRTC_mode,X
		sta	sheila_CRTC_dat
		dex
		bpl	@clp

		; set lat c0,c1 for 8k mode
		lda	#8+4
		sta	sheila_SYSVIA_orb
		lda	#0+5
		sta	sheila_SYSVIA_orb

		lda	have_nula
		beq	@nonula

		; blank some bits at left hand side
		lda	#$38
		sta	SHEILA_NULA_CTLAUX

@nonula:

		; make colour 1 yellow
		lda	#%00101100
		sta	sheila_VIDPROC_pal
		lda	#%00111100
		sta	sheila_VIDPROC_pal
		lda	#%01101100
		sta	sheila_VIDPROC_pal
		lda	#%01111100
		sta	sheila_VIDPROC_pal


		jsr	setscrtop

		jsr	map_init
		jsr	render_stars
		jsr	render_player

main_loop:
		jsr	wait_vsync

		lda	have_nula
		sta	stars_rendered
		beq	@nonula
		; apply nula scroll offset
		lda	zp_cycle
		and	#3
		eor	#3
		clc
		rol	A
		ora	#$20
		sta	SHEILA_NULA_CTLAUX
		jsr	render_stars
		jsr	render_player
@nonula:

		lda	zp_cycle
		and	#$03
		bne	@not_scroll
		lda	have_nula
		bne	@s
		jsr	render_stars
@s:		jsr	scroll
@not_scroll:
		lda	zp_cycle
		and	#$0F
		bne	@nottiles
		jsr	render_tiles_column
@nottiles:

@not_hwscroll:
		lda	stars_rendered
		beq	@nos
		jsr	move_stars
		jsr	render_stars
		jsr	render_player
@nos:
		inc	zp_cycle

		jmp	main_loop

		rts

render_tiles_column:
		; set starting address for tiles
		ldx	tiles_top
		stx	zp_tiledst_ptr
		ldy	tiles_top+1
		sty	zp_tiledst_ptr+1
		lda	#8
		sta	zp_tmp

@rowloop:	jsr	map_get
		jsr	get_tile_src_ptr
		jsr	blit_tile
		dec	zp_tmp
		bne	@rowloop

		; move to next column (expects 4 scrolls to have happened)
		clc
		lda	tiles_top
		adc	#32
		sta	tiles_top
		lda	tiles_top+1
		adc	#0
		bpl	@s
		sbc	#(>(PLAYFIELD_SIZE))-1
@s:		sta	tiles_top+1
		rts



map_init:	lda	#0
		sta	zp_mos_curROM
		sta	SHEILA_ROMCTL_SWR
		sta	zp_map_ptr
		sta	zp_map_rle
		lda	#$80
		sta	zp_map_ptr+1
		rts

map_get:	ldy	zp_map_rle		; are we doing a run of blanks
		beq	@g
		dey
		sty	zp_map_rle		; decrement run count
		lda	#TILE_BLANK		; return blank tile index
		rts
@g:		lda	(zp_map_ptr),Y		; Y=0 above
		inc	zp_map_ptr		; increment pointer
		bne	@s
		inc	zp_map_ptr+1		
@s:		ora	#0			; check for -ve 
		bmi	@r
		rts				; if not return in A
@r:		and	#$7F			; clear top bit
		cmp	#$7F
		bne	@s2
		lda	#$80			; bump to $80 
@s2:		sta	zp_map_rle		; set rle
		lda	#TILE_BLANK
		rts


blit_tile_next_line:
		clc
		lda	zp_tiledst_ptr
		adc	#<(PLAYFIELD_STRIDE)
		sta	zp_tiledst_ptr

		lda	zp_tiledst_ptr+1
		adc	#>(PLAYFIELD_STRIDE)
		bpl	@s1
		sbc	#(>(PLAYFIELD_SIZE))-1
@s1:		sta	zp_tiledst_ptr+1

		clc
		lda	zp_tilesrc_ptr
		adc	#32
		sta	zp_tilesrc_ptr
		bcs	@s
		rts
@s:		inc	zp_tilesrc_ptr+1
		rts

blit_tile:	jsr	blit_tile_half
		jsr	blit_tile_next_line

		jsr	blit_tile_half
		jmp	blit_tile_next_line
		rts

blit_tile_half:
		ldy	#31
@l1:		lda	(zp_tilesrc_ptr),Y
		sta	(zp_tiledst_ptr),Y
		dey
		lda	(zp_tilesrc_ptr),Y
		sta	(zp_tiledst_ptr),Y
		dey
		lda	(zp_tilesrc_ptr),Y
		sta	(zp_tiledst_ptr),Y
		dey
		lda	(zp_tilesrc_ptr),Y
		sta	(zp_tiledst_ptr),Y
		dey
		bpl	@l1
		
		rts
get_tile_src_ptr:
		sta	zp_tilesrc_ptr+1
		lda	#0

		clc
		ror	zp_tilesrc_ptr+1
		ror	A
		ror	zp_tilesrc_ptr+1
		ror	A
		adc	#<blockx16x16
		sta	zp_tilesrc_ptr
		lda	zp_tilesrc_ptr+1
		adc	#>blockx16x16
		sta	zp_tilesrc_ptr+1
		rts

;scroll:		lda	#>PLAYFIELD_TOP
;		sta	@src+2
;		sta	@dest+2
;
;
;		ldx	#0
;		ldy	#$28
;@l:			
;@src:		lda	a:$0008,X
;@dest:		sta	a:$0000,X
;		inx
;		bne	@l
;
;		inc	@src+2
;		inc	@dest+2
;		dey
;		bne	@l
;		rts


scroll:		inc	playfield_top_crtc
		bne	@s1
		inc	playfield_top_crtc+1
		lda	playfield_top_crtc+1
		cmp	#$10
		bcc	@s1
		sbc	#((>PLAYFIELD_SIZE)/8)
		sta	playfield_top_crtc+1
@s1:		
		clc
		lda	playfield_top
		adc	#8
		sta	playfield_top
		bcc	@s2
		inc	playfield_top+1
		bpl	@s2
		lda	playfield_top+1
		sbc	#>PLAYFIELD_SIZE
		sta	playfield_top+1
@s2:		
setscrtop:
		lda	#13
		sta	sheila_CRTC_reg
		lda	playfield_top_crtc
		sta	sheila_CRTC_dat
		lda	#12
		sta	sheila_CRTC_reg
		lda	playfield_top_crtc+1
		sta	sheila_CRTC_dat

		rts

wait_vsync:	pha
		; clear the vsync bit in IFR
		lda	#$02
		sta	sheila_SYSVIA_ifr
@lp:		bit	sheila_SYSVIA_ifr
		beq	@lp
		pla
		rts

	; on Entry X,Y in pixels
	; On Exit tiledst_ptr contains pointer to address
calc_screen_xy:	
		; = (X DIV 4)*8
		lda	#0
		sta	zp_tiledst_ptr+1
		txa
		asl	A
		ror	zp_tiledst_ptr+1
		and	#$F8
		sta	zp_tiledst_ptr

		; += Y MOD 8

		tya
		and	#7
		clc
		adc	zp_tiledst_ptr
		sta	zp_tiledst_ptr
		bcc	@s1
		inc	zp_tiledst_ptr+1
@s1:		

		; add top of screen

		clc	
		lda	zp_tiledst_ptr
		adc	playfield_top
		sta	zp_tiledst_ptr

		; save carry
		php


		; += Y DIV 8 * 256

		tya
		lsr	A
		lsr	A
		lsr	A

		plp		

		adc	zp_tiledst_ptr+1
		adc	playfield_top+1
		bpl	@s2
		sec
		sbc	#>PLAYFIELD_SIZE
@s2:		sta	zp_tiledst_ptr+1
		rts
		



render_player:	ldx	#32
		ldy	#80
		jsr	calc_screen_xy

		; 

		lda	#<playersprites
		sta	zp_tilesrc_ptr
		lda	#>playersprites
		sta	zp_tilesrc_ptr+1

		lda	#8
		sta	zp_tmp

@cloop:		ldy	#7
@rloop:		lda	(zp_tiledst_ptr),Y
		eor	(zp_tilesrc_ptr),Y
		sta	(zp_tiledst_ptr),Y
		dey	
		bpl	@rloop

		clc
		lda	zp_tilesrc_ptr
		adc	#8
		sta	zp_tilesrc_ptr
		bcc	@s2
		inc	zp_tilesrc_ptr+1		; TODO place player sprite to avoid this?
@s2:
		clc
		lda	zp_tiledst_ptr
		adc	#8
		sta	zp_tiledst_ptr
		lda	zp_tiledst_ptr+1
		adc	#0
		bpl	@s3
		sec
		sbc	#>PLAYFIELD_SIZE
@s3:		sta	zp_tiledst_ptr+1

		dec	zp_tmp
		bne	@cloop


		rts

		


render_stars:	ldx	#STARS_COUNT
		stx	zp_tmp
		ldx	#0
		ldy	#0
@l:		lda	stars,X
		sta	zp_tiledst_ptr
		inx
		lda	stars,X
		sta	zp_tiledst_ptr+1
		inx
		lda	stars,X
		inx
		inx
		eor	(zp_tiledst_ptr),Y
		sta	(zp_tiledst_ptr),Y
		dec	zp_tmp
		bne	@l
		lda	#$FF
		sta	stars_rendered
		rts


move_stars:	ldx	#1
		lda	have_nula
		bne	@sn
		ldx	#4			; if no nula then scroll is byte-wise, repeat 4 times
@sn:		stx	zp_tmp2

		ldx	#STARS_COUNT
		stx	zp_tmp
		ldx	#0		
@l:		ldy	zp_tmp2
@l2:		txa
		ror	A
		ror	A
		ror	A
		ror	A
		ror	A
		and	#$C0
		ora	#$40		
		adc	stars + star::movect,X
		sta	stars + star::movect,X
		bcs	@s			; on overflow don't move
		ror	stars + star::bits,X
		bcc	@s
		lda	stars + star::bits,X
		ora	#$80
		sta	stars + star::bits,X
		lda	stars + star::addr,X
		adc	#8-1
		sta	stars + star::addr,X
		bcc	@s
		inc	stars + star::addr+1,X
		bpl	@s
		lda	stars + star::addr+1,X
		sec
		sbc	#(>PLAYFIELD_SIZE)
		sta	stars + star::addr+1,X

@s:		dey
		bne	@l2
		inx
		inx
		inx
		inx
		dec	zp_tmp
		bne	@l
		rts

		.data

blockx16x16:	.incbin "../build/src/blocks16x16.bin"
playersprites:	.incbin "../build/src/player.bin"

playfield_CRTC_mode:
		.byte	$7f				; 0 Horizontal Total	 =128
		.byte	$40				; 1 Horizontal Displayed =64
		.byte	$5A				; 2 Horizontal Sync	 
		.byte	$28				; 3 HSync Width+VSync	 =&28  VSync=2, HSync Width=8
		.byte	$26				; 4 Vertical Total	 =38
		.byte	$00				; 5 Vertial Adjust	 =0
		.byte	$10				; 6 Vertical Displayed	 =16
		.byte	$22				; 7 VSync Position	 =&22
		.byte	$01				; 8 Interlace+Cursor	 =&01  Cursor=0, Display=0, Interlace=Sync
		.byte	$07				; 9 Scan Lines/Character =8
		.byte	$67				; 10 Cursor Start Line	 =&67	Blink=On, Speed=1/32, Line=7
		.byte	$08				; 11 Cursor End Line	 =8


have_nula:	.byte	$1
stars_rendered:	.byte	0				; flag stars have been erased and need rerendering/moving

stars:		
.word   $78C0
        .byte   $11
        .byte   $00
        .word   $6172
        .byte   $44
        .byte   $00
        .word   $7CA7
        .byte   $22
        .byte   $00
        .word   $7A39
        .byte   $22
        .byte   $00
        .word   $64D7
        .byte   $44
        .byte   $00
        .word   $7419
        .byte   $22
        .byte   $00
        .word   $7419
        .byte   $22
        .byte   $00
        .word   $7245
        .byte   $11
        .byte   $00
        .word   $7D9B
        .byte   $44
        .byte   $00
        .word   $600B
        .byte   $22
        .byte   $00
        .word   $6700
        .byte   $44
        .byte   $00
        .word   $7D63
        .byte   $11
        .byte   $00
        .word   $630C
        .byte   $22
        .byte   $00
        .word   $7B24
        .byte   $44
        .byte   $00
        .word   $61AA
        .byte   $22
        .byte   $00
        .word   $62AD
        .byte   $11
        .byte   $00


		.end