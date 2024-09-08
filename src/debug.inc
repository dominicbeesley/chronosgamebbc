.ifndef __DEBUG_INC__
.define __DEBUG_INC__

		.include "hardware.inc"

		.macro	DEBUG_STRIPE ccc
		.ifdef DO_DEBUG_STRIPES
			php
			pha
			sei
			lda	#$00 + ((ccc >> 8) & $0F)
			sta	SHEILA_NULA_PALAUX
			lda	#ccc & $FF
			sta	SHEILA_NULA_PALAUX
			pla
			plp
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