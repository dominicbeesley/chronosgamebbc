
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

		.zeropage

zp_osc_coarseE:	.res	1
zp_osc_coarseH:	.res	1
zp_osc_coarseD:	.res	1

zp_beeb256:	.res	1
zp_song_x_ptr:	.res	2

zp_song_x_dur:	.res	1

zp_song_x_loop_ptr:.res	2
zp_song_x_loop_ctr:.res	1


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

;;;; This example plays ROM contents as "white" noise
;;;;		ldx	#0
;;;;@loop:		lda	$C000,X
;;;;		and	#$0F
;;;;		ora	#$90
;;;;		POKEA
;;;;		jsr	wait
;;;;		inx
;;;;		bne	@loop
;;;;		inc	@loop+2
;;;;		bne	@loop
;;;;		lda	#$C0
;;;;		sta	@loop+2
;;;;		jmp	@loop
;;;;			
;;;;
;;;;wait:		jsr @w2
;;;;@w2:		jsr @w1
;;;;@w1:		jsr @w0
;;;;@w0:		rts
;;;;


song_init:
		ldx	#0
		stx	zp_beeb256
		;;stx	_oper_echo_handler+1
		inx
		stx	zp_song_x_loop_ctr
		stx	zp_song_x_dur

		lda	#<music_x_stream
		sta	zp_song_x_ptr
		sta	zp_song_x_loop_ptr
		lda	#>music_x_stream
		sta	zp_song_x_ptr+1
		sta	zp_song_x_loop_ptr+1




song_x_parse:	dec	zp_song_x_dur
		bne	song_x_parse_skip

song_x_parse_againy0:
		ldy	#0
		; we assume there's a note before Y runs out!
song_x_parse_again:
		lda	(zp_song_x_ptr),Y
		beq	song_init
		iny
		cmp	#1
		bne	@sk_loop_start

		; start a loop command #1
		lda	(zp_song_x_ptr),Y
		iny
		tax
		inx
		stx	zp_song_x_loop_ctr
		jsr	update_x_ptr
		ldy	#0
		lda	zp_song_x_ptr
		sta	zp_song_x_loop_ptr
		lda	zp_song_x_ptr+1
		sta	zp_song_x_loop_ptr+1
		bne	song_x_parse_again	; always

@sk_loop_start:	cmp	#2
		bne	@sk_loop_end

		; end a loop command #2
		dec	zp_song_x_loop_ctr
		beq	song_x_parse_again	; exit loop, do next note
		lda	zp_song_x_loop_ptr
		sta	zp_song_x_ptr		
		lda	zp_song_x_loop_ptr+1
		sta	zp_song_x_ptr+1
		bne	song_x_parse_againy0	; always
@sk_loop_end:

		sta	oper_coarseE
		
		lda	(zp_song_x_ptr),Y
		iny
		sta	oper_coarseH

		lda	(zp_song_x_ptr),Y
		iny
		sta	oper_coarseD

		lda	(zp_song_x_ptr),Y
		iny
		sta	zp_song_x_dur

		jsr	update_x_ptr

song_x_parse_skip:


song_beep:
		jsr	beep_256
		jsr	beep_256
		jsr	beep_256

		jmp	song_x_parse

update_x_ptr:
		tya
		clc
		adc	zp_song_x_ptr
		sta	zp_song_x_ptr
		lda	zp_song_x_ptr+1
		adc	#0
		sta	zp_song_x_ptr+1
		rts


beep_256:
; Play a tone using variable width pulses with modulation
beep256_lp:	dec	zp_osc_coarseE
		bne	skip_osc_H

		; osc D
		lda	#$90
oper_coarseE = *-1
		sta	zp_osc_coarseE
		lda	#$90
		POKEA
		ldx	#10
@onelp:		dex
		bne	@onelp
		lda	#$9F
		POKEA
		ldx	#1
@offelp:		dex
		bne	@offelp

skip_osc_H:

		dec	zp_osc_coarseH
		bne	skip_osc_D

		; osc D
		lda	#$20
oper_coarseH := *-1
		sta	zp_osc_coarseH
		lda	#$90
		POKEA
		ldx	#1
@onhlp:		dex
		bne	@onhlp
		lda	#$9F
		POKEA
		ldx	#1
@offhlp:		dex
		bne	@offhlp

skip_osc_D:

		dec	zp_osc_coarseD
		bne	skip_osc_done

		; osc E
		lda	#$16
oper_coarseD := *-1
		sta	zp_osc_coarseD
		lda	#$90
		POKEA
		ldx	#4
@ondlp:		dex
		bne	@ondlp
		lda	#$9F
		POKEA
		ldx	#1
@offdlp:		dex
		bne	@offdlp

skip_osc_done:

		ldx	#5
@dlp:		jsr	wait
		dex
		bne	@dlp
		dec	zp_beeb256
		beq	beeb256_ex
		jmp	beep256_lp
beeb256_ex:
wait:		rts



HERE:		jmp HERE


anRTS:		rts

		.data


		.end