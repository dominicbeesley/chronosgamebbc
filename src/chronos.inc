.ifndef __CHRONOS_INC__
.define __CHRONOS_INC__

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

.endif

NKEYS = 		5
KEYS_DOWN =		$01
KEYS_UP =		$02
KEYS_LEFT =		$04
KEYS_RIGHT =		$08
KEYS_FIRE =		$10

		.macro LDXY addr
		ldx	#<(addr)
		ldy	#>(addr)
		.endmacro




	.importzp	zp_tmp
	.importzp	zp_tmp2
	.importzp	zp_tmp3
	.importzp	zp_tmp4
	.importzp	zp_tmp5
	.importzp	zp_tmp6
	.importzp	zp_tmp7
	.importzp	zp_dest_ptr
	.importzp	zp_dest_ptr8
	.importzp	zp_tiledst_ptr
	.importzp	zp_src_ptr
	.importzp	zp_map_ptr
	.importzp	zp_map_rle
	.importzp	zp_cycle
	.importzp	zp_next_cycle
	.importzp	zp_scroll_offs
	.importzp	zp_frames_per_move
	.importzp	zp_frames_per_movex3
	.importzp	zp_anime_ctr
	.importzp	zp_anime_ctr6
	.importzp	zp_cur_enemy
	.importzp	score
	.importzp	starflipcur
	.importzp	starflipnxt
	.importzp	bulletflipcur
	.importzp	bulletflipnxt