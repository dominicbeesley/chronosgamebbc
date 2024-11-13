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

; private zero page

		.zeropage
zp_width:	.res	1
zp_width_ctr:	.res	1
zp_shiftX:	.res	1	; no of ror's to apply
zp_shiftXnxt:	.res	1	; no of rol's to apply

zp_src_ptr_save:.res	2
zp_char_row:	.res	1

zp_mask_cur:	.res	1	; mask for current cell
zp_mask_pre:	.res	1	; mask for prev cell

zp_next_char:	.res	1

zp_cur_x:	.res	1
zp_cur_y:	.res	1
zp_first_col:	.res	1

zp_dest_ptr_sav:.res	2

		.data

		.code


;------------------------------------------------------------------
;  _ _  _  _| _  _   _  _  _  _ _
; | (/_| |(_|(/_| __(/_| |(/_| | |\/
;                                 /
;------------------------------------------------------------------
; on entry X contains the pixel offset to add (due to sub-byte scrolling for NULA or not)
render_enemy:	; calculate enemy source address
		rts

		LDXY	enemysprites

		lda	#0
		sta	zp_cur_x

		lda	zp_anime_ctr
		and	#7

		lsr	A
		ror	zp_cur_x
		lsr	A
		ror	zp_cur_x

		sta	zp_cur_y
		txa
		adc	zp_cur_x
		tax
		tya
		adc	zp_cur_y

		stx	zp_src_ptr
		sta	zp_src_ptr+1

		ldx	zp_cur_enemy
		lda	enemies+enemy::px,X
		ldy	enemies+enemy::py,X
		tax


		lda	#2				; width of gfx
		sta	zp_width
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
		lda	#4
		sta	zp_width

;;		lda	zp_anime_ctr
;;		ror	A		;C
;;		ror	A		;7
;;		ror	A		;6
;;		ror	A		;5
;;		and	#$20
;;		lda	#0
;;		clc
;;		adc	#<playersprites
;;		sta	zp_src_ptr		
;;		lda	#>playersprites
;;		adc	#0
;;		sta	zp_src_ptr+1

		lda	#<playersprites
		sta	zp_src_ptr
		lda	#>playersprites
		sta	zp_src_ptr+1


render_player_int:

		txa
		clc
		adc	zp_scroll_offs
		sta	zp_cur_x
		tax
		sty	zp_cur_y

		jsr	calc_screen_xy

		lda	zp_cur_x		; get back X position of ship
		and	#7			
		sta	zp_shiftX		; store amount to shift by in zp_shiftX

		tax
		lda	maskx_first,X
		sta	zp_mask_cur
		lda	maskx_second,X
		sta	zp_mask_pre

		lda	#8
		sec
		sbc	zp_shiftX
		sta	zp_shiftXnxt

		lda	zp_src_ptr
		sta	zp_src_ptr_save
		lda	zp_src_ptr+1
		sta	zp_src_ptr_save+1

		; draw top char row of ship

		lda	zp_cur_y
		and	#7
		eor	#7
		tay
		sty	zp_char_row

		lda	zp_dest_ptr
		sta	zp_dest_ptr_sav
		lda	zp_dest_ptr+1
		sta	zp_dest_ptr_sav+1

		jsr	@render_row

		; skip rows in source we've already plotted
		sec
		lda	zp_src_ptr_save
		adc	zp_char_row
		sta	zp_src_ptr
		lda	zp_src_ptr_save+1
		adc	#0
		sta	zp_src_ptr+1


		lda	zp_char_row
		eor	#7
		sta	zp_char_row
		beq	@render_exit
		dec	zp_char_row

		; move to next char row
		lda	zp_dest_ptr_sav
		adc	#<PLAYFIELD_STRIDE
		and	#$F8				; move to first row in cell
		sta	zp_dest_ptr
		lda	zp_dest_ptr_sav+1
		adc	#>PLAYFIELD_STRIDE
		bpl	@sw
		sec
		sbc	#>PLAYFIELD_SIZE
@sw:		sta	zp_dest_ptr+1

.ifdef DEBUG
		jsr	@render_row			; instrumentation - fall through normally
@render_exit:	rts					
.endif
		
@render_row:	lda	zp_width				; width
		sta	zp_width_ctr
		sta	zp_first_col				; mark first column

;;		lda	#0
;;		sta	render_prev
;;		sta	render_prev+1
;;		sta	render_prev+2
;;		sta	render_prev+3
;;		sta	render_prev+4
;;		sta	render_prev+5
;;		sta	render_prev+6
;;		sta	render_prev+7

@cloop:		
		
		ldy	zp_char_row

		ldx	zp_shiftX
		bne	@shifted

@rloop:		lda	(zp_dest_ptr),Y
		eor	(zp_src_ptr),Y
		sta	(zp_dest_ptr),Y
		dey	
		bpl	@rloop
		bmi	@sk


@shifted:	
		lda	zp_first_col
		beq	@rorn
		; if this is first column we don't need to shift in previous col's data

@ror0:		ldx	zp_shiftX			; we need to add an X shift
		lda	(zp_src_ptr),Y	
@shlp0:		lsr	A
		dex
		bne	@shlp0
		and	zp_mask_cur
		eor	(zp_dest_ptr),Y
		sta	(zp_dest_ptr),Y

		; do left shift. This is actually quicker than combining with the ror above
		; for worst case as 7*ror zp is 35 inst instead of 1 rol = 2 + loop overhead

		lda	(zp_src_ptr),Y	
		ldx	zp_shiftXnxt
@shlp20:	asl	A
		dex
		bne	@shlp20

		and	zp_mask_pre
		sta	render_prev,Y
		dey
		bpl	@ror0
		bmi	@sk


@rorn:		ldx	zp_shiftX			; we need to add an X shift
		lda	(zp_src_ptr),Y	
@shlp:		lsr	A
		dex
		bne	@shlp
		and	zp_mask_cur
		ora	render_prev,Y
		eor	(zp_dest_ptr),Y
		sta	(zp_dest_ptr),Y

		; do left shift. This is actually quicker than combining with the ror above
		; for worst case as 7*ror zp is 35 inst instead of 1 rol = 2 + loop overhead

		lda	(zp_src_ptr),Y	
		ldx	zp_shiftXnxt
@shlp2:		asl	A
		dex
		bne	@shlp2

		and	zp_mask_pre
		sta	render_prev,Y
		dey
		bpl	@rorn


@sk:		
		clc
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
		bpl	@s33
		sec
		sbc	#>PLAYFIELD_SIZE
@s33:		sta	zp_dest_ptr+1

		lda	#0
		sta	zp_first_col
		dec	zp_width_ctr
		bne	@cloop

		lda	zp_shiftX
		beq	@r

		; do final column
		ldy	zp_char_row
@ll:		lda	render_prev,Y
		eor	(zp_dest_ptr),Y
		sta	(zp_dest_ptr),Y
		dey
		bpl	@ll

@r:		rts

.ifdef DEBUG
render_player_exit = @render_exit
.endif

		.zeropage
render_prev:	.res	8		; used to save previous char cell for each row

		.rodata

maskx_first:	.byte	%11111111
		.byte	%01111111
		.byte	%00111111
		.byte	%00011111
		.byte	%00001111
		.byte	%00000111
		.byte	%00000011
		.byte	%00000001

maskx_second:	.byte	%00000000
		.byte	%10000000
		.byte	%11000000
		.byte	%11100000
		.byte	%11110000
		.byte	%11111000
		.byte	%11111100
		.byte	%11111110
		.byte	%11111111

