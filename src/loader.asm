
		.include "oslib.inc"


		.code
		
		lda	#22
		jsr	OSWRCH
		lda	#7
		jsr	OSWRCH

		; copy splash screen to mode 7 area
		ldx	#0
		ldy	#4
@lp:		
@ldi:		lda	__SPLASH_LOAD__,X
@sti:		sta	$7C00,X
		inx
		bne	@lp
		inc	@ldi+2
		inc	@sti+2
		dey
		bne	@lp

		rts



		.segment	"SPLASH"
		.incbin 	"splash.mo7"
		.end