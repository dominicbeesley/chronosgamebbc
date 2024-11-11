		.include "oslib.inc"
		.include "hardware.inc"
		.include "mosrom.inc"
		.include "debug.inc"
		.include "chronos.inc"


		.export render_enemy
		.export render_player
		.export render_player_exit

; private zero page

		.zeropage
zp_shiftX:	.res	1	; no of ror's to apply
zp_shiftXnxt:	.res	1	; no of rol's to apply

zp_dest_row:	.res	1

zp_mask_cur:	.res	1	; mask for current cell
zp_mask_pre:	.res	1	; mask for prev cell

zp_next_char:	.res	1

zp_cur_x:	.res	1
zp_cur_y:	.res	1


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
;;
;;		LDXY	enemysprites
;;
;;		lda	#0
;;		sta	zp_cur_x
;;
;;		lda	zp_anime_ctr
;;		and	#7
;;
;;		lsr	A
;;		ror	zp_cur_x
;;		lsr	A
;;		ror	zp_cur_x
;;
;;		sta	zp_cur_y
;;		txa
;;		adc	zp_cur_x
;;		tax
;;		tya
;;		adc	zp_cur_y
;;
;;		stx	zp_src_ptr
;;		sta	zp_src_ptr+1
;;
;;		ldx	zp_cur_enemy
;;		lda	enemies+enemy::px,X
;;		ldy	enemies+enemy::py,X
;;		tax
;;
;;
;;		lda	#4				; width of gfx
;;		sta	zp_width
;;		jsr	render_player_int
;;
;;		rts


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

;;		lda	zp_anime_ctr
;;		ror	A		;C
;;		ror	A		;7
;;		ror	A		;6
;;		and	#$40
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
		and	#3			
		sta	zp_shiftX		; store amount to shift by in zp_shiftX

		bne	@shift
		jmp	render_player_int_noshift
@shift:

		tax
		lda	maskx_first,X
		sta	zp_mask_cur
		lda	maskx_second,X
		sta	zp_mask_pre

;;		; calculate entry point to shifter routine
;;		txa
;;		eor	#7
;;		adc	#<rr_shift_r7
;;		sta	rr_shift_r+1
;;		lda	#>rr_shift_r7
;;		adc	#0
;;		sta	rr_shift_r+2


		lda	#4
		sec
		sbc	zp_shiftX
		sta	zp_shiftXnxt

		; in first half render the first character cell starting at cur_y and 7

		; set up dest addresses
		lda	zp_dest_ptr
		and	#$F8					; mask off row
		ldx	zp_dest_ptr+1
		clc
	.repeat 9, I

		sta	.ident(.sprintf("rreor%d", I))+1
		stx	.ident(.sprintf("rreor%d", I))+2
		sta	.ident(.sprintf("rrsta%d", I))+1
		stx	.ident(.sprintf("rrsta%d", I))+2

	.if (I <> 8)
		adc	#8
		bcc	:+
		inx
		clc
		bpl	:+
		ldx	#>PLAYFIELD_TOP
:
	.endif

	.endrepeat


		lda	zp_cur_y
		and	#7
		sta	zp_dest_row
		ldy	#0			; source pointer
@lp:		jsr	render_row_player
		inc	zp_dest_row
		lda	#8
		cmp	zp_dest_row
		bne	@lp


render_player_exit:
		rts					
		
render_player_int_noshift:
		jmp	render_player_exit

;;rr_shift_r:	jmp	$FFFF
;;rr_shift_r7:	lsr	A
;;rr_shift_r6:	lsr	A
;;rr_shift_r5:	lsr	A
;;rr_shift_r4:	lsr	A
;;rr_shift_r3:	lsr	A
;;rr_shift_r2:	lsr	A
;;rr_shift_r1:	lsr	A
;;		rts

render_row_player:

	; the self-modified-code should be setup already to have pre-calculated
	; screen destination addresses
	; zp_dest_row contains the screen row
	; Y contains the src pointer

	; in an effort to minimise maximum times rather than best or average times
	; always render one extra column


	.macro RR_SHIFTR
		.local lp, sk
		lda	(zp_src_ptr), Y				; source data
		ldx	zp_shiftX
lp:		asl	A
		dex
		bne	lp
		and	zp_mask_cur
	.endmacro

	.macro RR_SHIFTL
		.local lp, sk
;		ldx	zp_shiftXnxt
;		lda	(zp_src_ptr), Y				; source data
;lp:		asl	A
;		dex
;		bne	lp
;		and	zp_mask_pre
		lda	#0
		sta	zp_next_char
		iny						; step to next source data
	.endmacro
	

	; middle columns (7 for player sprite)
	.repeat 8, I
		RR_SHIFTR
.if I <> 0
		eor	zp_next_char				; previous data
.endif
		ldx	zp_dest_row
.ident(.sprintf("rreor%d", I)):
		eor	a:$FFFF,X				; this is modified above
.ident(.sprintf("rrsta%d", I)):
		sta	a:$FFFF,X				; this is modified above
		RR_SHIFTL
	.endrepeat

	; always do extra final col - even if we don't need to 
		
		lda	zp_next_char
		ldx	zp_dest_row
rreor8:		eor	a:$FFFF,X
rrsta8:		sta	a:$FFFF,X

		rts


maskx_first:	.byte	%11111111
		.byte	%01110111
		.byte	%00110011
		.byte	%00010001
maskx_second:	.byte	%00000000
		.byte	%10001000		
		.byte	%11001100
		.byte	%11101110


