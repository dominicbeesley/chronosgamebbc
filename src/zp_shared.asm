

			.exportzp zp_tmp
			.exportzp zp_tmp2
			.exportzp zp_tmp3
			.exportzp zp_tmp4
			.exportzp zp_tmp5
			.exportzp zp_tmp6
			.exportzp zp_tmp7
			.exportzp zp_dest_ptr
			.exportzp zp_tiledst_ptr
			.exportzp zp_src_ptr
			.exportzp zp_map_ptr
			.exportzp zp_map_rle
			.exportzp zp_cycle
			.exportzp zp_next_cycle
	.ifdef NULA
			.exportzp zp_scroll_offs
	.endif
			.exportzp zp_anime_ctr
			.exportzp zp_anime_ctr6
			.exportzp zp_cur_enemy
			.exportzp zp_cur_enemy_ctr
			.exportzp score
			.exportzp starflipcur
			.exportzp starflipnxt
			.exportzp bulletflipcur
			.exportzp bulletflipnxt
			.exportzp enemiesflipcur
			.exportzp enemiesflipnxt

		.zeropage
zp_tmp:			.res 	1		; temporary
zp_tmp2:		.res 	1		; temporary
zp_tmp3:		.res 	1		; temporary
zp_tmp4:		.res 	1		; temporary
zp_tmp5:		.res 	1		; temporary
zp_tmp6:		.res 	1		; temporary
zp_tmp7:		.res 	1		; temporary
zp_dest_ptr:		.res 	2		; current blit destination
zp_tiledst_ptr:		.res 	2		; current tile destination in the tile column
zp_src_ptr:		.res	2		; current tile source pointer
zp_map_ptr:		.res	2		; pointer into map data
zp_map_rle:		.res	1		; if <>0 then repeat this many tile=7F's
zp_cycle:		.res	1		; modulo 16 cycle counter, scroll 1 byte every 4 display new tiles every 16
zp_next_cycle:		.res	1		; next value of above - for use in irq handler
	.ifdef NULA
zp_scroll_offs: 	.res	1		; the scroll offset to apply when rendering (or un-rendering)
	.endif
zp_anime_ctr:		.res	1		; index for animating enemies etc
zp_anime_ctr6:		.res	1		; index for animating enemies etc (modulo 6)
zp_cur_enemy:		.res	1		; index for currently processing enemy
zp_cur_enemy_ctr:	.res	1		; counts down when processing enemies from 4..1
score:			.res	4		; score in little-endian BCD
starflipcur:		.res	1		; flips between 0 and STARS_COUNT*.sizeof(star)
starflipnxt:		.res	1		; flips between 0 and STARS_COUNT*.sizeof(star) in opposite sense of above
bulletflipcur:		.res	1		; flips between 0 and BULLET_COUNT*.sizeof(bullet)
bulletflipnxt:		.res	1		; flips between 0 and BULLET_COUNT*.sizeof(bullet) in opposite sense of above
enemiesflipcur:		.res	1		; flips between 0 and ENEMY_COUNT*.sizeof(enemy)
enemiesflipnxt:		.res	1		; flips between 0 and ENEMY_COUNT*.sizeof(enemy) in opposite sense of above
