	.include "chronos.inc"

	.export tblKeys
	.export	playfield_CRTC_mode
	.export	playpal
	.export	blockx16x16
	.export	playersprites
	.export	enemysprites
	.export	NUMFONT

	.export chronospipe
	.export scoreboard

	.export playfield_top_crtc
	.export playfield_top
	.export new_tiles_top
	.export up_tiles_top
	.export player_x
	.export player_y
	.export next_player_x
	.export next_player_y
	.export player_keys
	.export enemies
	.export have_nula
	.export stars_rendered
	.export stars
	.export stars2
	.export bullets
	.export fire_pend
	.export visible_tiles
	.export firing_tits


		.rodata
tblKeys:		.byte	$68	; down	?
			.byte	$48	; up	*
			.byte   $61	; left	Z
			.byte	$42	; right	X
			.byte	$62	; fire	SPACE

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

blockx16x16:	.incbin "../build/src/blocks16x16.bin"
playersprites:	.incbin "../build/src/player.bin"
enemysprites:	.incbin "../build/src/enemies.bin"
NUMFONT:	.incbin "../build/src/numfont.f2"


		.data
		.align	8		
chronospipe:	.incbin "../build/src/chronospipe.bin"	; not strictly r/w but needs to go next to scoreboard
scoreboard:	.res	8*8*2				; bitmap for score

playfield_top_crtc:	.word	PLAYFIELD_TOP / 8			; start of playfield screen (in crtc address)
playfield_top:		.word	PLAYFIELD_TOP				; start of playfield screen (in RAM address)
new_tiles_top:		.word	PLAYFIELD_TOP + PLAYFIELD_STRIDE	; where new tiles are to be plotted
up_tiles_top:		.word	PLAYFIELD_TOP + 32			; where tiles will be updated relative to

player_x:		.byte	32
player_y:		.byte   80

next_player_x:		.byte	0
next_player_y:		.byte	0

player_keys:		.byte	0		

		; the following data is used for sub-screens


enemies:	.byte	$30, $60, $0, $0
		.byte	$31, $10, $0, $1
		.byte	$32, $20, $0, $2




have_nula:	.byte	1
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
