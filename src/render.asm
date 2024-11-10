		.include "oslib.inc"
		.include "hardware.inc"
		.include "mosrom.inc"
		.include "debug.inc"
		.include "chronos.inc"


		.export render_enemy
		.export render_player
.ifdef DEBUG
		.export render_exit
.endif

; private zero page

		.zeropage
zp_width:	.res	1
zp_width_ctr:	.res	1
zp_shiftX:	.res	1	; no of ror's to apply
zp_shiftXnxt:	.res	1	; no of rol's to apply to next cell's data
zp_src_ptr_save:.res	2
zp_char_row:	.res	1
		.data

		.code

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
		sta	zp_width
		bne	render_player_int

calc_dest_8:
		clc
		lda	zp_dest_ptr
		adc	#8
		sta	zp_dest_ptr8
		lda	zp_dest_ptr+1
		adc	#0
		bpl	@s3
		sec
		sbc	#>PLAYFIELD_SIZE
@s3:		sta	zp_dest_ptr8+1
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

render_player:	lda	player_x
		tax

		ldy	player_y
		lda	#8
		sta	zp_width
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
		pha
		tax

		jsr	calc_screen_xy

		jsr	calc_dest_8

		pla				; get back X position of ship
		and	#3			
		sta	zp_shiftX		; store amount to shift by in zp_shiftX
		lda	#4
		sec
		sbc	zp_shiftX
		sta	zp_shiftXnxt

		lda	zp_src_ptr
		sta	zp_src_ptr_save
		lda	zp_src_ptr+1
		sta	zp_src_ptr_save+1

		; draw top char row of ship

		lda	player_y
		and	#7
		eor	#7
		tay
		sty	zp_char_row

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
		jsr	calc_dest_8

.ifdef DEBUG
		jsr	@render_row			; instrumentation - fall through normally
@render_exit:	rts					
.endif
		
@render_row:	lda	zp_width				; width
		sta	zp_width_ctr
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

@ror:		ldx	zp_shiftX
		; we need to add an X shift
		lda	(zp_src_ptr),Y	
@shlp:		lsr	A
		dex
		bne	@shlp
		ldx	zp_shiftX
		and	maskx_first,X
		eor	(zp_dest_ptr),Y
		sta	(zp_dest_ptr),Y

@rol:
		lda	(zp_src_ptr),Y
		ldx	zp_shiftXnxt
@shlp2:		asl	A
		dex	
		bne	@shlp2
		ldx	zp_shiftXnxt
		and	maskx_second,X
		eor	(zp_dest_ptr8),Y
		sta	(zp_dest_ptr8),Y


		dey
		bpl	@shifted

		

@sk:		clc
		lda	zp_src_ptr
		adc	#8
		sta	zp_src_ptr
		bcc	@s2
		inc	zp_src_ptr+1		
@s2:

		clc
		lda	zp_dest_ptr8
		sta	zp_dest_ptr
		adc	#8
		sta	zp_dest_ptr8
		lda	zp_dest_ptr8+1
		sta	zp_dest_ptr+1
		adc	#0
		bpl	@s33
		sec
		sbc	#>PLAYFIELD_SIZE
@s33:		sta	zp_dest_ptr8+1


		dec	zp_width_ctr
		bne	@cloop

		rts

.ifdef DEBUG
render_exit = @render_exit
.endif
maskx_first:	.byte	%11111111
		.byte	%01110111
		.byte	%00110011
		.byte	%00010001
maskx_second:	.byte	%00000000
		.byte	%11101110
		.byte	%11001100
		.byte	%10001000		


