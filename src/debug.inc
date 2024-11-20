.ifndef __DEBUG_INC__
.define __DEBUG_INC__

		.include "hardware.inc"

		.macro	DEBUG_STRIPE ccc
		.ifdef DO_DEBUG_STRIPES
		.ifdef NULA
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
		.else
			php					;	3	1
			pha					;	3	1
			lda	#$0F - ((((ccc & $F00)<>0)*4) + (((ccc & $0F0)<>0)*2) + (((ccc & $00F)<>0)*1))
								;	2	2
			sta	sheila_VIDPROC_pal
			pla					;	4	1
			plp					;	4	1
		.endif
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