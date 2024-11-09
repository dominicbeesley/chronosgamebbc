
		.include "oslib.inc"
		.include "hardware.inc"
		.include "mosrom.inc"
		.include "debug.inc"

ZP_ROM_SLOT=$80


TILE_BLANK=$7F
PLAYFIELD_STRIDE	:= 32*8*2
PLAYFIELD_SIZE  	:= $2000
PLAYFIELD_TOP		:= $8000-16*PLAYFIELD_STRIDE


BLOCK_BUFFER		:= $0400	; off-screen buffer for next column of tiles 

TILE_DOWN_TIT		:= $18
TILE_UP_TIT		:= $19
TILE_UP_TIT2		:= $9
TILE_CUBE		:= $10

VISTILES_SIZE		:= 16*8


STARS_COUNT	:= 16
	.struct star
		addr	.word		; address on screen
		bits	.byte		; bitmap		
		movect	.byte		; when this overflows skip a move
	.endstruct
BULLET_COUNT	:= 16
	.struct bullet
		px	.byte
		py	.byte
		status	.byte
	.endstruct
ENEMIES_COUNT	:= 3
	.struct enemy
		px	.byte
		py	.byte
		status	.byte
		type	.byte
	.endstruct
		
		.export		playfield_top_crtc
		.export 	have_nula
		.exportzp	zp_next_cycle
		.export		chronospipe


		.zeropage
zp_tmp:		.res 	1		; temporary
zp_tmp2:	.res 	1		; temporary
zp_tmp3:	.res 	1		; temporary
zp_tmp4:	.res 	1		; temporary
zp_tmp5:	.res 	1		; temporary
zp_tmp6:	.res 	1		; temporary
zp_tmp7:	.res 	1		; temporary
zp_dest_ptr:	.res 	2		; current blit destination
zp_tiledst_ptr:	.res 	2		; current tile destination in the tile column
zp_src_ptr:	.res	2		; current tile source pointer
zp_map_ptr:	.res	2		; pointer into map data
zp_map_rle:	.res	1		; if <>0 then repeat this many tile=7F's
zp_cycle:	.res	1		; modulo 16 cycle counter, scroll 1 byte every 4 display new tiles every 16
zp_next_cycle:	.res	1		; next value of above - for use in irq handler
zp_scroll_offs: .res	1		; the scroll offset to apply when rendering (or un-rendering)

zp_frames_per_move:
		.res	1		; used to multiply speed of stars/player
zp_frames_per_movex3:
		.res	1		; used for number of pixels to move bullets

zp_anime_ctr:	.res	1		; index for animating enemies etc
zp_anime_ctr6:	.res	1		; index for animating enemies etc (modulo 6)
zp_cur_enemy:	.res	1		; index for currently processing enemy

score:		.res	4		; score in little-endian BCD

starflipcur:	.res	1		; flips between 0 and STARS_COUNT*.sizeof(star)
starflipnxt:	.res	1		; flips between 0 and STARS_COUNT*.sizeof(star) in opposite sense of above
bulletflipcur:	.res	1		; flips between 0 and BULLET_COUNT*.sizeof(bullet)
bulletflipnxt:	.res	1		; flips between 0 and BULLET_COUNT*.sizeof(bullet) in opposite sense of above

		.data
playfield_top_crtc:	.word	PLAYFIELD_TOP / 8			; start of playfield screen (in crtc address)
playfield_top:		.word	PLAYFIELD_TOP				; start of playfield screen (in RAM address)
new_tiles_top:		.word	PLAYFIELD_TOP + PLAYFIELD_STRIDE	; where new tiles are to be plotted
up_tiles_top:		.word	PLAYFIELD_TOP + 32			; where tiles will be updated relative to

player_x:		.byte	32
player_y:		.byte   80

next_player_x:		.byte	0
next_player_y:		.byte	0

KEYS_DOWN =		$01
KEYS_UP =		$02
KEYS_LEFT =		$04
KEYS_RIGHT =		$08
KEYS_FIRE =		$10
player_keys:		.byte	0		
NKEYS = 		5
tblKeys:		.byte	$68	; down	?
			.byte	$48	; up	*
			.byte   $61	; left	Z
			.byte	$42	; right	X
			.byte	$62	; fire	SPACE

		.macro LDXY addr
		ldx	#<(addr)
		ldy	#>(addr)
		.endmacro


		.code

		sei				; disable interrupts for now

		lda 	#4   
		sta 	sheila_SYSVIA_pcr	; vsync \\ CA1 negative-active-edge CA2 input-positive-active-edge CB1 negative-active-edge CB2 input-nagative-active-edge

		lda	#%01000000		; T1 irq continuous no PB7, T2 irq, no SR, no latch
		sta	sheila_SYSVIA_acr
		sta	sheila_USRVIA_acr

.ifdef DO_DEBUG_USERPORT
		lda	#$FF
		sta	sheila_USRVIA_ddrb
		lda	#$0
		sta	sheila_USRVIA_orb
.endif

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


@nonula:
		ldx	#16
@pallp:		lda	playpal-1,X
		sta	sheila_VIDPROC_pal
		dex
		bne	@pallp


		; disable keyboard scan

		ldy	#$0+3				; stop Auto scan
		sty	sheila_SYSVIA_orb		; by writing to system VIA
		ldy	#$7f				; set bits 0 to 6 of port A to input on bit 7
							; output on bits 0 to 6
		sty	sheila_SYSVIA_ddra		; leave it set like this...


		lda	#$10
		sta	SHEILA_NULA_CTLAUX

		jsr	init_irq

		; init data structures

		lda	#0
		sta	zp_cycle
		sta	fire_pend
		sta	zp_anime_ctr6
		sta	zp_anime_ctr
		sta	starflipcur
		sta	bulletflipcur

		lda	#STARS_COUNT*.sizeof(star)
		sta	starflipnxt
		lda	#BULLET_COUNT*.sizeof(bullet)
		sta	bulletflipnxt

		ldx	#1
		lda	have_nula
		bne	@sn
		ldx	#4			; if no nula then scroll is byte-wise, repeat 4 times
@sn:		stx	zp_frames_per_move
		clc
		stx	zp_frames_per_movex3
		txa
		rol	A
		adc	zp_frames_per_movex3
		sta	zp_frames_per_movex3

		lda	#$7F
		ldx	#VISTILES_SIZE
@cv:		sta	visible_tiles-1,X
		dex
		bne	@cv

		lda	#$FF
		sta	firing_tits


		; init screen


		jsr	map_init
		jsr	zeroscore


		jsr	render_stars_and_bullets
		ldx	have_nula
		dex
		txa
		eor	#$FF
		sta	zp_scroll_offs
		jsr	render_player

		lda	have_nula
		bne	@s
		jmp	main_loop
@s:		

;   _ _  _ . _   | _  _  _ 
;  | | |(_||| |__|(_)(_)|_)
;                       |

	DEBUG_STRIPE	$000
main_loop:
		; At this point we should be somewhere at the end of the bottom half of the screen
		; we can do computationally intensive stuff here

		jsr	check_keys			; check keyboard
		jsr	move_player0			; calculate player moves (but don't store yet)
		jsr	move_stars
		jsr	move_bullets

		;;; TODO - there's loads of spare time here for sound effects and other
		;;; stuff!!!

		jsr	wait_midframe			; wait for middle of frame i.e. end of play field

		ldx	zp_cycle
		inx
		stx	zp_next_cycle			; we set this early in case the code below overruns the point
							; where the IRQ handler will pick it up

		lda	#0
		sta	stars_rendered			; indicate stars not rendered
		sta	zp_scroll_offs			; assume no offset
		lda	have_nula
		beq	@nonula				; skip forwards if no nula

		; we are in nula mode set the scroll offset to use when un-rendering
		ldx	zp_cycle
		dex
		txa
		and	#3
		sta	zp_scroll_offs

		jsr	render_stars_and_bullets	; NULA: we always UN-render stars and bullets here
	DEBUG_STRIPE	$333
		jsr	render_player			; NULA: we always UN-render the player with the relevant offset
	DEBUG_STRIPE	$000
@nonula:

		lda	zp_cycle
		and	#$03
		bne	@not_scroll

		; do scroll actions here every 4th frame

		lda	have_nula
		bne	@s
		jsr	render_stars_and_bullets	; NON-NULA UN-render stars and bullets (non-NULA)
	DEBUG_STRIPE	$333
		jsr	render_player			; NON-NULA UN render the player with no offset
	DEBUG_STRIPE	$000
@s:		jsr	scroll				; perform the 1 byte shift hardware scroll

		; update anime counters
		inc	zp_anime_ctr
		ldx	zp_anime_ctr6
		inx
		cpx	#6
		bne	@s2
		ldx	#0
@s2:		stx	zp_anime_ctr6

@not_scroll:
		lda	zp_cycle
		and	#$0F
		bne	@nottiles

		; every 16th frame do the move to the next tiles column

		jsr	next_tiles_column		; move to next tiles column
		jsr	check_and_fire			; check for fire TODO: move to free time slot above - need to mark pending fires to avoid pre-rendering
		jmp	@notmoretiles
@nottiles:	and	#1
		beq	@notmoretiles
		jsr	add_tile_to_column		; get another tile from the map and add to the tiles column
@notmoretiles:

		lda	stars_rendered			; check if we've un-rendered the stars (NULA or scroll)
		beq	@nos

		; stars to be updated
		jsr	move_laser_tits

		; update to use new stars and bullets
		lda	starflipcur
		pha
		lda	starflipnxt
		sta	starflipcur
		pla
		sta	starflipnxt

		lda	bulletflipcur
		pha
		lda	bulletflipnxt
		sta	bulletflipcur
		pla
		sta	bulletflipnxt

		jsr	move_player1			; actually update player position

		ldx	#0
		lda	have_nula
		beq	@sss
		lda	zp_cycle
		and	#3
		sta	zp_scroll_offs


		jsr	render_stars_and_bullets	; render the new stars
		
@sss:		DEBUG_STRIPE	$333
		jsr	render_player			; render the ship (with offset of 0 if non-nula)
		DEBUG_STRIPE	$000
@nos:
		inc	zp_cycle

		jsr	renderscore

		jmp	main_loop

		rts





next_tiles_column:

		; move to next column (expects 4 scrolls to have happened)
		clc
		lda	new_tiles_top
		adc	#32
		sta	new_tiles_top
		sta	zp_tiledst_ptr
		lda	new_tiles_top+1
		adc	#0
		bpl	@s
		sbc	#(>(PLAYFIELD_SIZE))-1
@s:		sta	new_tiles_top+1
		sta	zp_tiledst_ptr+1

		clc
		lda	up_tiles_top
		adc	#32
		sta	up_tiles_top
		lda	up_tiles_top+1
		adc	#0
		bpl	@ss
		sbc	#(>(PLAYFIELD_SIZE))-1
@ss:		sta	up_tiles_top+1

		; scroll the visibile tilemap
		ldx	#0
@lp:		
		lda	visible_tiles+8,X
		sta	visible_tiles,X
		inx
		lda	visible_tiles+8,X
		sta	visible_tiles,X
		inx		
		lda	visible_tiles+8,X
		sta	visible_tiles,X
		inx		
		lda	visible_tiles+8,X
		sta	visible_tiles,X
		inx		

		cpx	#15*8
		bcc	@lp
		rts


		; get tile at pixel position X adjusted for cycle
		; returns A=tile #, X=offset in map
get_visible_tileAY:
		sta	zp_tmp
		lda	zp_cycle
		and	#$0F
		clc
		adc	zp_tmp
		and	#$F0
		lsr	A
		sta	zp_tmp
		tya
		and	#$70
		lsr	A
		lsr	A
		lsr	A
		lsr	A
		ora	zp_tmp
		tax
		lda	visible_tiles,X
		rts

		; on entry X contains the visible tile offset
		; on exit zp_dest_ptr is screen address of tile adjusted for current scroll cycle		
visibleX_to_screen:
		; pY is 16 * (X&7)
		txa
		pha
		and	#7
		tay
		pla
		and	#$78
		lsr	A
		lsr	A
		lsr	A
		tax
		jmp	calc_tile_xy

	
add_tile_to_column:
		jsr	map_get
		; place in visible tile map at right most column
		pha
		lda	zp_cycle
		lsr	A
		and	#7
		tax
		pla
		sta	visible_tiles+15*8,X
		jsr	get_tile_src_ptr
		lda	zp_tiledst_ptr
		sta	zp_dest_ptr
		lda	zp_tiledst_ptr+1
		sta	zp_dest_ptr+1
		jsr	blit_tile
		lda	zp_dest_ptr
		sta	zp_tiledst_ptr
		lda	zp_dest_ptr+1
		sta	zp_tiledst_ptr+1
		rts

map_init:	lda	z:ZP_ROM_SLOT
		sta	zp_mos_curROM
		sta	SHEILA_ROMCTL_SWR
		lda	#0
		sta	zp_map_ptr
		sta	zp_map_rle
		lda	#$81			; map data starts at offset $100 in ROM
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


blit_tile_next_row:
		clc
		lda	zp_dest_ptr
		adc	#<(PLAYFIELD_STRIDE-32)
		sta	zp_dest_ptr

		lda	zp_dest_ptr+1
		adc	#>(PLAYFIELD_STRIDE-32)
		bpl	@s1
		sbc	#(>(PLAYFIELD_SIZE))-1
@s1:		sta	zp_dest_ptr+1

		rts

blit_tile:	jsr	blit_tile_half
		jsr	blit_tile_next_row

		jsr	blit_tile_half
		jmp	blit_tile_next_row
		rts


dest_ptr_next_row:
		clc
		lda	zp_dest_ptr
		adc	#<(PLAYFIELD_STRIDE)
		sta	zp_dest_ptr

		lda	zp_dest_ptr+1
		adc	#>(PLAYFIELD_STRIDE)
		bpl	@s1
		sbc	#(>(PLAYFIELD_SIZE))-1
@s1:		sta	zp_dest_ptr+1

		rts

blit_tile_half:
		ldx	#4
@l2:
		ldy	#7

		lda	(zp_src_ptr),Y
		sta	(zp_dest_ptr),Y
		dey

		lda	(zp_src_ptr),Y
		sta	(zp_dest_ptr),Y
		dey

		lda	(zp_src_ptr),Y
		sta	(zp_dest_ptr),Y
		dey

		lda	(zp_src_ptr),Y
		sta	(zp_dest_ptr),Y
		dey

		lda	(zp_src_ptr),Y
		sta	(zp_dest_ptr),Y
		dey

		lda	(zp_src_ptr),Y
		sta	(zp_dest_ptr),Y
		dey

		lda	(zp_src_ptr),Y
		sta	(zp_dest_ptr),Y
		dey

		lda	(zp_src_ptr),Y
		sta	(zp_dest_ptr),Y


		clc
		lda	zp_src_ptr
		adc	#8
		sta	zp_src_ptr
		bcc	@s1
		inc	zp_src_ptr+1
@s1:		

		clc
		lda	zp_dest_ptr
		adc	#8
		sta	zp_dest_ptr
		bcc	@s2
		inc	zp_dest_ptr+1
		bpl	@s2
		sec
		lda	zp_dest_ptr+1
		sbc	#>PLAYFIELD_SIZE
		sta	zp_dest_ptr+1
@s2:		dex
		bne	@l2
		rts
get_tile_src_ptr:
		sta	zp_src_ptr+1
		lda	#0

		clc
		ror	zp_src_ptr+1
		ror	A
		ror	zp_src_ptr+1
		ror	A
		adc	#<blockx16x16
		sta	zp_src_ptr
		lda	zp_src_ptr+1
		adc	#>blockx16x16
		sta	zp_src_ptr+1
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


scroll:		php
		sei
		inc	playfield_top_crtc
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
		plp
		rts

wait_midframe:	pha
		lda	frame_ctr
@lp:		cmp	frame_ctr
		beq	@lp
		pla
		rts

calc_tile_xy:
	; on Entry X,Y in tiles from current tile pointer
	; On Exit zp_dest_ptr contains pointer to address
		; = X*32

		lda	#0
		sta	zp_dest_ptr

		txa
		lsr	A
		ror	zp_dest_ptr
		lsr	A
		ror	zp_dest_ptr
		lsr	A
		ror	zp_dest_ptr
		sta	zp_dest_ptr+1


		; add tile map start
		clc
		lda	up_tiles_top
		adc	zp_dest_ptr
		sta	zp_dest_ptr
		lda	up_tiles_top+1
		adc	zp_dest_ptr+1
		sta	zp_dest_ptr+1
				

		; += Y * 1024

		tya
		asl	A
		asl	A
		clc
		adc	zp_dest_ptr+1
		bmi	@s
		sta	zp_dest_ptr+1
		rts

@s:		sec
		sbc	#>PLAYFIELD_SIZE
		sta	zp_dest_ptr+1
		rts


	; on Entry X,Y in pixels offset to playfield (scrolled) screen
	; On Exit zp_dest_ptr contains pointer to address
calc_screen_xy:	
		; = (X DIV 4)*8
		lda	#0
		sta	zp_dest_ptr+1
		txa
		asl	A
		rol	zp_dest_ptr+1
		and	#$F8
		sta	zp_dest_ptr

		; += Y MOD 8

		tya
		and	#7
		clc
		adc	zp_dest_ptr
		sta	zp_dest_ptr
		bcc	@s1
		inc	zp_dest_ptr+1
@s1:		

		; add top of screen

		clc	
		lda	zp_dest_ptr
		adc	playfield_top
		sta	zp_dest_ptr

		; save carry
		php


		; += Y DIV 8 * 512

		tya
		lsr	A
		lsr	A
		and	#$FE

		plp		

		adc	zp_dest_ptr+1
		adc	playfield_top+1
		bpl	@s2
		sec
		sbc	#>PLAYFIELD_SIZE
@s2:		sta	zp_dest_ptr+1
		rts


		

;------------------------------------------------------------------
;  _ _  _  _| _  _   _  _  _  _ _
; | (/_| |(_|(/_| __(/_| |(/_| | |\/
;                                 /
;------------------------------------------------------------------
; on entry X contains the pixel offset to add (due to sub-byte scrolling for NULA or not)
render_enemy:
		ldx	zp_cur_enemy
		lda	enemies+enemy::px,X
		tax

		ldy	enemies+enemy::py,X

		lda	#4				; width of gfx
		sta	zp_tmp5
		bne	render_player_int

;------------------------------------------------------------------
;  _ _  _  _| _  _   _ | _    _  _
; | (/_| |(_|(/_| __|_)|(_|\/(/_|
;                   |      /
;------------------------------------------------------------------
;
; on entry X contains the pixel offset to add (due to sub-byte 
; scrolling for NULA or not)
; player_x, player_y are the positions of the player on the playfield
;

render_player:	lda	player_x
		tax

		ldy	player_y
		lda	#8
		sta	zp_tmp5
;;
;;		lda	zp_anime_ctr
;;		ror	A		;C
;;		ror	A		;7
;;		ror	A		;6
;;		and	#$40
		lda	#0
		clc
		adc	#<playersprites
		sta	zp_src_ptr		
		lda	#>playersprites
		adc	#0
		sta	zp_src_ptr+1


render_player_int:

		txa
		clc
		adc	zp_scroll_offs
		sta	zp_tmp2
		tax

		jsr	calc_screen_xy


		lda	zp_tmp2			; get X position of ship
		and	#3			
		sta	zp_tmp6			; store amount to shift by in zp_tmp6
		lda	#4
		sec
		sbc	zp_tmp6
		sta	zp_tmp7

		lda	zp_src_ptr
		sta	zp_tmp3
		lda	zp_src_ptr+1
		sta	zp_tmp4

		; draw top char row of ship

		lda	player_y
		and	#7
		eor	#7
		tay
		sty	zp_tmp2

		lda	zp_tmp5
		jsr	@render_row

		; skip rows in source we've already plotted
		sec
		lda	zp_tmp3
		adc	zp_tmp2
		sta	zp_src_ptr
		lda	zp_tmp4
		adc	#0
		sta	zp_src_ptr+1


		lda	zp_tmp2
		eor	#7
		sta	zp_tmp2
		beq	@nomore
		dec	zp_tmp2

		; move to next char row
		lda	zp_dest_ptr
		adc	#<(PLAYFIELD_STRIDE-64)
		and	#$F8				; move to first row in cell
		sta	zp_dest_ptr
		lda	zp_dest_ptr+1
		adc	#>(PLAYFIELD_STRIDE-64)
		bpl	@sw
		sec
		sbc	#>PLAYFIELD_SIZE
@sw:		sta	zp_dest_ptr+1
		lda	zp_tmp5


@render_row:	sta	zp_tmp
@cloop:		
		ldy	zp_tmp2

		ldx	zp_tmp6
		bne	@ror

@rloop:		lda	(zp_dest_ptr),Y
		eor	(zp_src_ptr),Y
		sta	(zp_dest_ptr),Y
		dey	
		bpl	@rloop
		bmi	@sk

@ror:		ldx	zp_tmp6
		; we need to add an X shift
		lda	(zp_src_ptr),Y	
@shlp:		lsr	A
		dex
		bne	@shlp
		ldx	zp_tmp6
		and	maskx_first,X
		eor	(zp_dest_ptr),Y
		sta	(zp_dest_ptr),Y

		tya
		pha

		lda	(zp_src_ptr),Y
		pha
		tya
		clc
		adc	#8
		tay
		pla

		ldx	zp_tmp7
@shlp2:		asl	A
		dex	
		bne	@shlp2
		ldx	zp_tmp7
		and	maskx_second,X
		eor	(zp_dest_ptr),Y
		sta	(zp_dest_ptr),Y

		pla
		tay

		dey
		bpl	@ror
		

@sk:		clc
		lda	zp_src_ptr
		adc	#8
		sta	zp_src_ptr
		bcc	@s2
		inc	zp_src_ptr+1		
@s2:
		clc
		lda	zp_dest_ptr
		adc	#8
		sta	zp_dest_ptr
		lda	zp_dest_ptr+1
		adc	#0
		bpl	@s3
		sec
		sbc	#>PLAYFIELD_SIZE
@s3:		sta	zp_dest_ptr+1

		dec	zp_tmp
		bne	@cloop

@nomore:	rts

maskx_first:	.byte	%11111111
		.byte	%01110111
		.byte	%00110011
		.byte	%00010001
maskx_second:	.byte	%00000000
		.byte	%11101110
		.byte	%11001100
		.byte	%10001000		
		
;------------------------------------------------------------------
;  _ _  _  _| _  _   __|_ _  _ _   _  _  _|  |_    || _ _|_ _
; | (/_| |(_|(/_| ___\ | (_|| _\__(_|| |(_|__|_)|_|||(/_ | _\
; 		
;------------------------------------------------------------------
;


render_stars_and_bullets:	
		; stars first
		ldx	#STARS_COUNT
		stx	zp_tmp
		ldx	starflipcur
		ldy	#0
@l:		lda	stars+star::addr,X
		sta	zp_dest_ptr
		lda	stars+star::addr+1,X
		sta	zp_dest_ptr+1
		lda	stars+star::bits,X
		inx
		inx
		inx
		inx
		eor	(zp_dest_ptr),Y
		sta	(zp_dest_ptr),Y
		dec	zp_tmp
		bne	@l

		; scroll offset
		lda	#0
		bit	have_nula
		beq	@noff
		lda	zp_cycle
		and	#3
@noff:		sta	zp_tmp5

		ldx	#BULLET_COUNT
		stx	zp_tmp
		ldx	bulletflipcur
@blp:		lda	bullets + bullet::status,X
		bmi	@bnx

		txa
		pha
		lda	bullets + bullet::py,X
		tay
		lda	bullets + bullet::px,X
		clc
		adc	zp_tmp5
		tax
		jsr	calc_screen_xy
		ldy	#0
		lda	(zp_dest_ptr),Y
		eor	#$FF
		sta	(zp_dest_ptr),Y
		ldy	#8
		lda	(zp_dest_ptr),Y
		eor	#$FF
		sta	(zp_dest_ptr),Y
		ldy	#16
		lda	(zp_dest_ptr),Y
		eor	#$FF
		sta	(zp_dest_ptr),Y
		ldy	#24
		lda	(zp_dest_ptr),Y
		eor	#$FF
		sta	(zp_dest_ptr),Y

		pla
		tax

@bnx:		inx
		inx
		inx
		dec	zp_tmp
		bne	@blp

		;render the laser beams between up/down pointing tits
		
		ldx	#0			
@titlp:		lda	firing_tits,X
		stx	zp_tmp2
		tay
		cmp	#$FF
		beq	@skiptits
		
		sec
		sbc	firing_tits+1,X
		eor	#$FF	
		asl	A
		sta	zp_tmp3
		
		tya
		tax
		inx				; move down one

		jsr	visibleX_to_screen
		clc
		lda	zp_dest_ptr
		adc	#8
		sta	zp_dest_ptr
		bcc	@s2
		inc	zp_dest_ptr+1
		bpl	@s2
		sec
		lda	zp_dest_ptr+1
		sbc	#>PLAYFIELD_SIZE
		sta	zp_dest_ptr+1
@s2:

@ll:		ldy	#1

		lda	(zp_dest_ptr),Y
		eor	#$33
		sta	(zp_dest_ptr),Y
		iny
		iny

		lda	(zp_dest_ptr),Y
		eor	#$33
		sta	(zp_dest_ptr),Y
		iny
		iny

		lda	(zp_dest_ptr),Y
		eor	#$33
		sta	(zp_dest_ptr),Y
		iny
		iny

		lda	(zp_dest_ptr),Y
		eor	#$33
		sta	(zp_dest_ptr),Y

		jsr	dest_ptr_next_row

		dec	zp_tmp3
		bne	@ll
		


		
		ldx	zp_tmp2
		inx
		inx
		bne	@titlp



@skiptits:

		; render enemies

		ldx	#0		
@elp:		stx	zp_cur_enemy
		lda	enemies+enemy::status,X		; check status
		bmi	@esk				; if -ve then is inactive

		ldx	zp_tmp5				; get scroll offset calculated above
;;		jsr	render_enemy

@esk:		ldx	zp_cur_enemy
		inx
		inx
		inx
		inx
		cpx	#ENEMIES_COUNT*.sizeof(enemy)
		bcc	@elp


		lda	#$FF
		sta	stars_rendered



		rts

;------------------------------------------------------------------
;   _ _  _    _    __|_ _  _ _
;  | | |(_)\/(/_  _\ | (_|| _\
;------------------------------------------------------------------
;

move_stars:	
		; copy to next area
		lda	#STARS_COUNT*.sizeof(star)
		sta	zp_tmp
		ldx	starflipcur
		ldy	starflipnxt
@clp:		lda	stars,X
		sta	stars,Y
		dec	zp_tmp
		bne	@clp


		ldx	#STARS_COUNT
		stx	zp_tmp
		ldx	starflipnxt
@l:		ldy	zp_frames_per_move
@l2:		txa
		sec
		sbc	starflipcur
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

;------------------------------------------------------------------
;  _ _  _    _   |_    || _ _|_ _
; | | |(_)\/(/_  |_)|_|||(/_ | _\
;------------------------------------------------------------------
;

move_bullets:

		; copy current values to next
		ldx	#.sizeof(bullet)*(BULLET_COUNT)
		stx	zp_tmp
		ldx	bulletflipcur
		ldy	bulletflipnxt
@clp:		lda	bullets,X
		sta	bullets,Y
		dec	zp_tmp
		bne	@clp

		ldx	#BULLET_COUNT
		stx	zp_tmp5

		ldx	bulletflipnxt
@blp:		lda	bullets + bullet::status,X
		bmi	@sb
	
		lda	bullets + bullet::py,X
		tay
		lda	bullets + bullet::px,X
		stx	zp_tmp3
		jsr	get_visible_tileAY
		cmp	#$7F
		beq	@moveit
		; we've hit something...
		; check what we've hit and if it is destructable
		
		cmp	#TILE_UP_TIT
		beq	@score5
		cmp	#TILE_DOWN_TIT
		beq	@score5
		cmp	#TILE_UP_TIT2
		beq	@score10
		cmp	#TILE_CUBE
		beq	@skspecial
		cmp	#$36
		bcc	@nodes			; not destructable
		cmp	#$39
		bcs	@nodes
		bcc	@skspecial
@score5:	lda	#5
		bne	@s5
@score10:	lda	#10
@s5:		jsr	add_A_score
@skspecial:	; blank out block in visible tile map 
		; X should still point at tile map
		lda	#$7F		
		sta	visible_tiles,X

		; blank out on screen
		jsr	visibleX_to_screen
		lda	#$7F
		jsr	get_tile_src_ptr
		jsr	blit_tile

@nodes:		ldx	zp_tmp3		
		jmp	@end



@moveit:	
		ldx	zp_tmp3	
		clc
		lda	bullets + bullet::px,X
		adc	zp_frames_per_movex3
		bcs	@end
		sta	bullets + bullet::px,X
@sb:		inx
		inx
		inx
		dec	zp_tmp5
		bne	@blp
		rts
@end:		lda	#$FF
		sta	bullets + bullet::status,X
		bne	@sb				; always!

;------------------------------------------------------------------
;  _ _  _    _   | _  _ _  _  _|_._|_ _
; | | |(_)\/(/___|(_|_\(/_| __ | | | _\
; 
;------------------------------------------------------------------
; scan through the current map and look for tits that are firing
; and set up in firing_tits memory area ready for display in 
; render_stars_and_bullets

@rts:		rts
move_laser_tits:
		lda	zp_cycle
		and	#$F
		cmp	#0
		bne	@rts

		; cycle through the visible map and look for laser tits with matching pairs
		ldx	#0		; index into map
		stx	zp_tmp		; remember which type of tit we're on
		ldy	#0		; index into tit list
@ltlp:		lda	visible_tiles,X
		cmp	#TILE_DOWN_TIT
		beq	@downtit
		cmp	#TILE_UP_TIT
		beq	@uptit
@nxt:		inx
		cpx	#$38		; if we get to position $38 then skip forward to $50 as these lasers don't fire
		bcc	@ltlp
		bne	@cont
		lda	zp_tmp
		beq	@s50
		dey			; we were tracking a pair, cancel
		dec	zp_tmp
@s50:		ldx	#$50		; skip forward to position 50
@cont:		cpx	#$68
		bne	@ltlp
		lda	zp_tmp
		beq	@nr
		dey			; cancel open tit
@nr:		lda	#$FF
		sta	firing_tits,Y
		rts

@downtit:	lda	zp_tmp
		beq	@sd
		dey			; we got another down, cancel previous
		dec	zp_tmp
@sd:		txa
		sta	firing_tits,Y
		iny
		inc	zp_tmp
		jmp	@nxt
@uptit:		lda	zp_tmp
		beq	@nxt		; nothing was active ignore
		dec	zp_tmp		; cancel marker
		txa
		sta	firing_tits,Y
		iny
		jmp	@nxt
@rts:		rts


;------------------------------------------------------------------
;  _|_  _  _|   |  _    _
; (_| |(/_(_|<__|<(/_\/_\
;                    /
;------------------------------------------------------------------
; scan the keyboard for pressed keys and store in player_keys
;


check_keys:	ldx	#NKEYS-1
@l:		lda	tblKeys,X
		sta	sheila_SYSVIA_ora_nh
		lda	sheila_SYSVIA_ora_nh
		rol	A
		rol	player_keys
		dex
		bpl	@l
		rts

;------------------------------------------------------------------
;  _ _  _    _    _ | _    _  _/X
; | | |(_)\/(/___|_)|(_|\/(/_| X/
;                |      /
;------------------------------------------------------------------
;
; set up new player position in next_* and fire_pend this happens
; during the display period the actual move occurs during rendering

move_player0:	lda	player_x
		sta	next_player_x
		lda	player_y
		sta	next_player_y

		lda	player_keys
		and	#KEYS_UP
		beq	@nup
		lda	next_player_y
		sec
		sbc	zp_frames_per_move
		bpl	@novup
		lda	#0
@novup:		sta	next_player_y
@nup:


		lda	player_keys
		and	#KEYS_DOWN
		beq	@ndn
		lda	next_player_y
		clc
		adc	zp_frames_per_move	
		cmp	#120
		bcc	@novdn
		lda	#120
@novdn:		sta	next_player_y
@ndn:		

		lda	player_keys
		and	#KEYS_LEFT
		beq	@nlt
		lda	next_player_x
		sec
		sbc	zp_frames_per_move
		bpl	@novlt
		lda	#0
@novlt:		sta	next_player_x
@nlt:
		lda	player_keys
		and	#KEYS_RIGHT
		beq	@nrt
		lda	next_player_x
		adc	zp_frames_per_move
		cmp	#120
		bcc	@novrt
		lda	#120
@novrt:		sta	next_player_x
@nrt:		

		

		; only fire once every block move (16 cycles)
		lda	fire_pend
		bne	@nof
		lda	player_keys
		and	#KEYS_FIRE
		beq	@nof
		dec	fire_pend
@nof:

		rts

;------------------------------------------------------------------
; 
;  _ _  _    _    _ | _    _  _'|
; | | |(_)\/(/___|_)|(_|\/(/_| .|.
;                |      /
;------------------------------------------------------------------
; 
; update the player position variables


move_player1:	lda	next_player_x
		sta	player_x
		lda	next_player_y
		sta	player_y
		rts

;------------------------------------------------------------------
;  _|_  _  _|    _  _  _|   |`. _ _
; (_| |(/_(_|<__(_|| |(_|__~|~|| (/_
; 
;------------------------------------------------------------------
;
; check for a pending fire and set up a bullet entry if one is free
;

check_and_fire:
		lda	fire_pend
		beq	@rts
		; look for a firing slot and occupy it
		ldx	#.sizeof(bullet)*(BULLET_COUNT-1)	; point at last slot
@lp:		lda	bullets + bullet::status,X
		bpl	@occ					; skip if occupied

		; we've found a slot, fill it with our data
		lda	player_x
		clc
		adc	#32
		sta	bullets + bullet::px,X
		lda	player_y
		clc
		adc	#4
		sta	bullets + bullet::py,X
		lda	#0
		sta	bullets + bullet::status,X
		beq	@nof

@occ:		dex
		dex
		dex
		bpl	@lp
@nof:		lda	#0
		sta	fire_pend

@rts:		rts


;;;;; scores
add_A_score:	php
		sed					; enable BCD
		clc
		adc	score
		sta	score
		bcc	@nc
		lda	score+1
		adc	#0
		sta	score+1
		lda	score+2
		adc	#0
		sta	score+2
		lda	score+3
		adc	#0
		sta	score+3
@nc:		plp
		rts

renderscore:	ldx	#0				; screen pointer
		ldy	#3				; score  pointer
@lp:		lda	score,Y
		jsr	renderBCD2
		dey
		bpl	@lp
		rts

zeroscore:	ldx	#3
		lda	#0
@l:		sta	score,X
		dex
		bpl	@l
		rts

renderBCD2:	pha
		and	#$F0
		jsr	@r
		pla
		asl	A
		asl	A
		asl	A
		asl	A
@r:		sty	zp_tmp
		ldy	#16
		sty	zp_tmp2
		tay
@r8:		lda	NUMFONT,Y
		iny
		sta	scoreboard,X
		inx
		dec	zp_tmp2
		bne	@r8
		ldy	zp_tmp
		rts



		.data
enemies:	.byte	$10, $20, $0, $0
		.byte	$20, $20, $0, $1
		.byte	$30, $20, $0, $2

blockx16x16:	.incbin "../build/src/blocks16x16.bin"
playersprites:	.incbin "../build/src/player.bin"
		.align	8		
chronospipe:	.incbin "../build/src/chronospipe.bin"
enemysprites:	.incbin "../build/src/enemies.bin"
scoreboard:	.res	8*8*2				; bitmap for score
NUMFONT:	.incbin "../build/src/numfont.f2"

playfield_CRTC_mode:
		.byte	$7f				; 0 Horizontal Total	 =128
		.byte	$40				; 1 Horizontal Displayed =64
		.byte	$5A				; 2 Horizontal Sync	 
		.byte	$28				; 3 HSync Width+VSync	 =&28  VSync=2, HSync Width=8
		.byte	$26				; 4 Vertical Total	 =38
		.byte	$00				; 5 Vertial Adjust	 =0
		.byte	$10				; 6 Vertical Displayed	 =16 - this will get changed in IRQ
		.byte	$22				; 7 VSync Position	 =34
		.byte	$00				; 8 Interlace+Cursor	 =&00  Cursor=0, Display=0, Interlace=None
		.byte	$07				; 9 Scan Lines/Character =8
		.byte	$67				; 10 Cursor Start Line	 =&67	Blink=On, Speed=1/32, Line=7
		.byte	$08				; 11 Cursor End Line	 =8


have_nula:	.byte	1
stars_rendered:	.byte	0				; flag stars have been erased and need rerendering/moving

playpal:

		; make colour 0 black
		.byte	%00001111
		.byte	%00011111
		.byte	%01001111
		.byte	%01011111
		; make colour 1 yellow
		.byte	%00101100
		.byte	%00111100
		.byte	%01101100
		.byte	%01111100
		; make colour 2 yellow
		.byte	%10001100
		.byte	%10011100
		.byte	%11001100
		.byte	%11011100
		; make colour 3 white
		.byte	%10101000
		.byte	%10111000
		.byte	%11101000
		.byte	%11111000


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
stars2:	.res	STARS_COUNT*.sizeof(star)
bullets:
	.repeat BULLET_COUNT, I
	.byte	0
	.byte	I * 8
	.byte	$FF
	.endrepeat
	.res	BULLET_COUNT*.sizeof(bullet)

fire_pend:	.res	1		; player fire is pending

	.align 8
visible_tiles:
		.res	VISTILES_SIZE		; the tiles currently on screen row minor 
firing_tits:

		.res	8*2		; laser beams in use each two bytes for a start/stop offset in tilemap

		.end