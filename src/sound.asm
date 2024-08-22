
		.include "oslib.inc"
		.include "hardware.inc"
		.include "mosrom.inc"


		.macro WAIT8
			jsr	anRTS
		.endmacro

		.macro POKEA
			sta	sheila_SYSVIA_ora
			lda	#0
			sta	sheila_SYSVIA_orb
			WAIT8
			lda	#8
			sta	sheila_SYSVIA_orb
			WAIT8
		.endmacro

		.macro POKESI d
			pha
			lda	#d
			POKEA	
			pha
		.endmacro

		.macro POKESN channel, type, data
		.if type
			; type non-zero so it's a volume set so only one byte
			POKESI ($80+((channel & $03) << 5)+$10+(data & $0F))
		.else
			; type is tone/noise
;			.if (channel & 3) = 3
;				; noise 
;				POKESI ($80+((channel & $03) << 5)+$00+(data & $0F))
;			.else
				; tone
				POKESI ($80+((channel & $03) << 5)+$00+(data & $0F))
				POKESI ((data & $3F0) >> 4)
;			.endif

		.endif
		.endmacro

		.code

		sei


		lda	#$FF
		sta	sheila_SYSVIA_ddra

		; setup sn76489 to play a low-period tone which we will modulate

		POKESN 0, 1, 0
;		POKESN 1, 1, 15
;		POKESN 2, 1, 15
;		POKESN 3, 1, 15
;
		POKESN 0, 0, 1
;		POKESN 1, 0, 500
;		POKESN 2, 0, 200
;		POKESN 3, 0, 0

		ldx	#0
@loop:		lda	$C000,X
		and	#$0F
		ora	#$90
		POKEA
		jsr	wait
		inx
		bne	@loop
		inc	@loop+2
		bne	@loop
		lda	#$C0
		sta	@loop+2
		jmp	@loop
			

wait:		jsr @w2
@w2:		jsr @w1
@w1:		jsr @w0
@w0:		rts


HERE:		jmp HERE


anRTS:		rts

		.data


		.end