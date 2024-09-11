.ifndef __DEBUG_INC__
.define __DEBUG_INC__

		.include "hardware.inc"

		.macro	DEBUG_STRIPE ccc
		.ifdef DO_DEBUG_STRIPES
			php					;	3	1
			pha					;	3	1
			lda	#$00 + ((ccc >> 8) & $0F)	;	2	2
			sei					;	2	1
			sta	SHEILA_NULA_PALAUX		;	4	3
			lda	#ccc & $FF			;	2	2
			sta	SHEILA_NULA_PALAUX		;	4	3
			pla					;	4	1
			plp					;	4	1
								;	26	14
		.endif
		.endmacro

		.macro	DEBUG_PB7_TGL
		.ifdef DO_DEBUG_USERPORT
			php
			pha
			lda	sheila_USRVIA_orb
			eor	#$80
			sta	sheila_USRVIA_orb
			pla
			plp
		.endif
		.endmacro

.endif __DEBUG_INC__