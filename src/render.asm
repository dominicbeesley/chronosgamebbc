		.include "oslib.inc"
		.include "hardware.inc"
		.include "mosrom.inc"
		.include "debug.inc"
		.include "chronos.inc"


		.export render_enemy
		.export render_player
.ifdef DEBUG
		.export render_player_exit
.endif

REN_N_SHIFTS	:=	4		; number of shifts (max) 4 for mode 1, 8 for mode 4


; private zero page

		.zeropage
zp_width:	.res	1
zp_width_ctr:	.res	1
zp_height:	.res	1
zp_height_ctr:	.res	1

zp_src_ptr_save:.res	2
zp_char_row:	.res	1

zp_next_char:	.res	1

zp_cur_x:	.res	1
zp_cur_y:	.res	1

zp_dest_ptr_sav:.res	2

render_prev:	.res	REN_N_SHIFTS		; used to save previous char cell for each row


		.data

		.code


;------------------------------------------------------------------
;  _ _  _  _| _  _   _  _  _  _ _
; | (/_| |(_|(/_| __(/_| |(/_| | |\/
;                                 /
;------------------------------------------------------------------
; render an enemy at (X,Y)
; zp_src_ptr contains sprite pointer
render_enemy:	; calculate enemy source address

		lda	#4				; width of gfx (in bytes)
		sta	zp_width
		lda	#2
		sta	zp_height		
		jsr	render_player_int

		rts


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

render_player:	ldx	player_x
		ldy	player_y
		lda	#8
		sta	zp_width
		lda	#1
		sta	zp_height

		lda	zp_anime_ctr
		; get bit 0 into bit 6
		ror	A		;C
		ror	A		;7
		ror	A		;6
		and	#$40
		clc
		adc	#<playersprites
		sta	zp_src_ptr		
		lda	#>playersprites
		adc	#0
		sta	zp_src_ptr+1


render_player_int:

		stx	zp_cur_x
		sty	zp_cur_y

		jsr	calc_screen_xy

		lda	zp_cur_x		; get back X position of ship
		and	#(REN_N_SHIFTS-1)
		tax

		lda	tbl_rr_l,X
		sta	render_row+1
		lda	tbl_rr_h,X
		sta	render_row+2

		lda	zp_src_ptr
		sta	zp_src_ptr_save
		lda	zp_src_ptr+1
		sta	zp_src_ptr_save+1

		lda	zp_height
		sta	zp_height_ctr

		lda	zp_dest_ptr
		sta	zp_dest_ptr_sav
		lda	zp_dest_ptr+1
		sta	zp_dest_ptr_sav+1


		; draw first char row of ship 
@chrowlp:

		lda	zp_src_ptr_save
		sta	zp_src_ptr
		lda	zp_src_ptr_save+1
		sta	zp_src_ptr+1

		lda	zp_dest_ptr_sav
		sta	zp_dest_ptr
		lda	zp_dest_ptr_sav+1
		sta	zp_dest_ptr+1

		lda	zp_cur_y
		and	#7
		eor	#7
		tay
		sty	zp_char_row


		jsr	render_row

		; skip rows in source we've already plotted
		sec
		lda	zp_src_ptr_save
		adc	zp_char_row
		sta	zp_src_ptr
		lda	zp_src_ptr_save+1
		adc	#0
		sta	zp_src_ptr+1



		; move to next char row
		lda	zp_dest_ptr_sav
		and	#$F8				; move to first row in cell
		sta	zp_dest_ptr
		ldx	zp_dest_ptr_sav+1
		inx
		bpl	@sw1
		ldx 	#>PLAYFIELD_TOP
@sw1:		inx
		bpl	@sw
		ldx 	#>PLAYFIELD_TOP
@sw:		stx zp_dest_ptr+1
		stx 	zp_dest_ptr_sav+1

		lda	zp_char_row
		eor	#7
		sta	zp_char_row
		beq	@skr2
		dec	zp_char_row

		jsr 	render_row
@skr2:		lda	zp_width
		asl	A
		asl	A
		asl	A
		adc	zp_src_ptr_save
		sta	zp_src_ptr_save
		lda	zp_src_ptr_save+1
		adc	#0
		sta	zp_src_ptr_save+1
		dec	zp_height_ctr
		bne	@chrowlp

render_player_exit:	
		rts		

		
render_row:	jmp	$FFFF					; indirect self-modify jump

	.macro	NEXT_DEST_CELL
		.local @s33
		clc
		lda	zp_dest_ptr
		adc	#8
		sta	zp_dest_ptr
		bcc	@s33
		inc	zp_dest_ptr+1
		bpl	@s33
		lda	#>PLAYFIELD_TOP
		sta	zp_dest_ptr+1
@s33:		
	.endmacro
	
	.macro NEXT_SRC_CELL
		.local @s2
		clc
		lda	zp_src_ptr
		adc	#8
		sta	zp_src_ptr
		bcc	@s2
		inc	zp_src_ptr+1		
@s2:	.endmacro	
	


	.repeat REN_N_SHIFTS, I
		; for each possible shift generate a render_row routine

.ident(.sprintf("render_row%d", I)):	
		lda	zp_width				; width
		sta	zp_width_ctr

	.if I<>0
		; there will always be a first column for a shifted sprite
		; that is different (no previous data to shift in)
		; do that here as a special case

		ldy	zp_char_row
@ror0:		lda	(zp_src_ptr),Y	
		; shift right
	.repeat	I, J
		lsr	A
	.endrepeat
		and	#($F>>I) * $11
		eor	(zp_dest_ptr),Y
		sta	(zp_dest_ptr),Y

		; do left shift. This is actually quicker than combining with the ror above
		; for worst case as 7*ror zp is 35 inst instead of 1 rol = 2 + loop overhead

		lda	(zp_src_ptr),Y	
	.repeat	REN_N_SHIFTS-I,J
		asl	A
	.endrepeat
		and	#(($F0>>I) & $F)*$11
		sta	render_prev,Y


		dey
		bpl	@ror0

		NEXT_SRC_CELL
		NEXT_DEST_CELL


		dec	zp_width_ctr		;; assumes > 1

	.endif

@cloop:		
		
		ldy	zp_char_row

	.if I=0
		; simple render with no shift
@rloop:		lda	(zp_dest_ptr),Y
		eor	(zp_src_ptr),Y
		sta	(zp_dest_ptr),Y
		dey	
		bpl	@rloop
		bmi	@sk
	.else
		; I contains number of positions to shift to right




@rorn:		lda	(zp_src_ptr),Y	
	.repeat I, J
		lsr	A
	.endrepeat
		and	#($F>>I) * $11
		ora	render_prev,Y
		eor	(zp_dest_ptr),Y
		sta	(zp_dest_ptr),Y


		; do left shift. This is actually quicker than combining with the ror above
		; for worst case as 7*ror zp is 35 inst instead of 1 rol = 2 + loop overhead

		lda	(zp_src_ptr),Y	
	.repeat REN_N_SHIFTS-I,J
		asl	A
	.endrepeat
		and	#(($F0>>I) & $F) * $11
		sta	render_prev,Y

		dey
		bpl	@rorn
	.endif ; shift/no shift
@sk:		
		NEXT_SRC_CELL

		NEXT_DEST_CELL

		dec	zp_width_ctr
		bne	@cloop

	.if I<>0

		; do extra final column containing spilled bits from previous cell
		ldy	zp_char_row
@ll:		lda	render_prev,Y
		eor	(zp_dest_ptr),Y
		sta	(zp_dest_ptr),Y
		dey
		bpl	@ll

	.endif
		rts
	.endrepeat



		.rodata

tbl_rr_l:	
	.repeat	REN_N_SHIFTS, I
		.byte	<.ident(.sprintf("render_row%d", I))
	.endrepeat
tbl_rr_h:	
	.repeat	REN_N_SHIFTS, I
		.byte	>.ident(.sprintf("render_row%d", I))
	.endrepeat






