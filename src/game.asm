
		.include "oslib.inc"
		.include "hardware.inc"
		.include "mosrom.inc"

TILE_BLANK=$7F
SCREEN_STRIDE := 40*8

		.zeropage
zp_tmp:		.res 	1
zp_tiledst_ptr:	.res 	2
zp_tilesrc_ptr:	.res	2
zp_map_ptr:	.res	2
zp_map_rle:	.res	1

		.macro LDXY addr
		ldx	#<(addr)
		ldy	#>(addr)
		.endmacro


		.code


		; mode 4
		lda	#22
		jsr	OSWRCH
		lda	#4
		jsr	OSWRCH


		jsr	map_init

@main_loop:	LDXY	$5800+38*8
		stx	zp_tiledst_ptr
		sty	zp_tiledst_ptr+1
		lda	#8
		sta	zp_tmp

@rowloop:	jsr	map_get
		jsr	get_tile_src_ptr
		jsr	blit_tile
		dec	zp_tmp
		bne	@rowloop
		
		lda	#19
		jsr	OSBYTE		
		jsr	scroll
		lda	#19
		jsr	OSBYTE		
		jsr	scroll

		jmp	@main_loop

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



blit_tile:	ldy	#0
		jsr	blit_tile_half

		lda	zp_tiledst_ptr
		adc	#<(SCREEN_STRIDE-16)
		sta	zp_tiledst_ptr

		lda	zp_tiledst_ptr+1
		adc	#>(SCREEN_STRIDE-16)
		sta	zp_tiledst_ptr+1

		jsr	blit_tile_half

		lda	zp_tiledst_ptr
		adc	#<(SCREEN_STRIDE+16)
		sta	zp_tiledst_ptr

		lda	zp_tiledst_ptr+1
		adc	#>(SCREEN_STRIDE+16)
		sta	zp_tiledst_ptr+1
		
		rts

blit_tile_half:
		ldx	#8
@l1:		lda	(zp_tilesrc_ptr),Y
		sta	(zp_tiledst_ptr),Y
		iny
		lda	(zp_tilesrc_ptr),Y
		sta	(zp_tiledst_ptr),Y
		iny
		dex
		bne	@l1
		
		rts
get_tile_src_ptr:
		sta	zp_tilesrc_ptr+1
		lda	#0

		clc
		ror	zp_tilesrc_ptr+1
		ror	A
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

scroll:		lda	#$58
		sta	@src+2
		sta	@dest+2


		ldx	#0
		ldy	#$14
@l:		
@src:		lda	a:$0008,X
@dest:		sta	a:$0000,X
		inx
		bne	@l

		inc	@src+2
		inc	@dest+2
		dey
		bne	@l
		rts



		.data

blockx16x16:	.incbin "../build/src/blocks16x16.bin"

		.end