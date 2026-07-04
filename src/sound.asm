
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

zp_temp1:		.res	1

zp_osc_coarseC_ctdn:	.res	1
zp_osc_coarseE_ctdn:	.res	1
zp_osc_coarseH_ctdn:	.res	1
zp_osc_coarseD_ctdn:	.res	1

zp_beeb256:		.res	1

zp_song_x_ptr:		.res	2
zp_song_x_dur_ctdn:	.res	1
zp_song_x_loop_ptr:	.res	2
zp_song_x_loop_ctr:	.res	1

zp_song_z_ptr:		.res	2
zp_song_z_dur_ctdn:	.res	1
zp_song_z_loop_ptr:	.res	2
zp_song_z_loop_ctr:	.res	1


zp_x_env_phase_def:	.res	1
zp_x_env_attack_speed:	.res	1
zp_x_env_decay_speed:	.res	1
zp_x_env_decay_target:	.res	1

zp_x_env_phase_act:	.res	1
zp_x_env_attack_ctdn:	.res	1
zp_x_env_decay_ctdn:	.res	1

zp_z_env_phase_def:	.res	1
zp_z_env_attack_speed:	.res	1
zp_z_env_decay_speed:	.res	1

zp_z_env_phase_act:	.res	1
zp_z_env_attack_ctdn:	.res	1
zp_z_env_decay_ctdn:	.res	1


zp_echo:			.res	1

zp_flag_half_speed:	.res	1


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
		stx	zp_x_env_phase_def		
		stx	zp_z_env_phase_def		
		stx	zp_echo
		stx	zp_flag_half_speed
		;;stx	_oper_echo_handler+1
		inx
		stx	zp_song_x_loop_ctr
		stx	zp_song_x_dur_ctdn
		stx	zp_song_z_loop_ctr
		stx	zp_song_z_dur_ctdn
		inx
		stx	zp_x_env_phase_act
		stx	zp_z_env_phase_act

		lda	#<music_x_stream
		sta	zp_song_x_ptr
		sta	zp_song_x_loop_ptr
		lda	#>music_x_stream
		sta	zp_song_x_ptr+1
		sta	zp_song_x_loop_ptr+1

		lda	#<music_z_stream
		sta	zp_song_z_ptr
		sta	zp_song_z_loop_ptr
		lda	#>music_z_stream
		sta	zp_song_z_ptr+1
		sta	zp_song_z_loop_ptr+1



song_x_note_ctdnlp:
		dec	zp_song_x_dur_ctdn
		beq	song_x_parse_againy0
		jmp	song_x_parse_skip

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
		cmp	#$FF
		bne	@sk_not_ff_cmd

		; get sub-code
		lda	(zp_song_x_ptr),Y
		iny

		cmp	#9
		bne	@not_echo_on
		ldx	#$FF
		stx	zp_echo
		jmp	song_x_parse_again
		bne	@not_echo_on
@not_echo_on:	cmp	#10
		bne	@not_echo_off
		ldx	#0
		stx	zp_echo
		jmp	song_x_parse_again
		bne	@not_echo_off
@not_echo_off:	cmp	#1
		bne	@not_env

		; ENVELOPE command
		lda	(zp_song_x_ptr),Y
		iny
		sta	zp_x_env_phase_def		

		lda	(zp_song_x_ptr),Y
		iny
		sta	zp_x_env_attack_speed

		lda	(zp_song_x_ptr),Y
		iny
		sta	zp_x_env_decay_speed

		lda	(zp_song_x_ptr),Y
		iny
		sta	zp_x_env_decay_target

		jmp	song_x_parse_again


@not_env:	jmp	song_x_parse_again	; TODO-shorten?

@sk_not_ff_cmd:
		;load note value
		ldx	zp_x_env_phase_def
		stx	zp_x_env_phase_act
		beq	@load_note_decay_first
		; load a note with attack, start at 0 and work up

		;TODO: I think all these targets can be ignored, just test if off value is <=1

		sta	oper_coarseE
		jsr	calcon
		sta	oper_offE
		sta	oper_attackE_target

		lda	(zp_song_x_ptr),Y
		iny
		sta	oper_coarseH
		jsr	calcon
		sta	oper_offH
		sta	oper_attackH_target

		lda	zp_echo			; if echo is active - don't load D
		bne	@skip_x_d
		lda	(zp_song_x_ptr),Y
		iny
		sta	oper_coarseD
		jsr	calcon
		sta	oper_offD
		sta	oper_attackD_target		
@skip_x_d:
		lda	#1
		sta	oper_onE
		sta	oper_onH
		sta	oper_onD
		bne	@note_load_dur
@load_note_decay_first:
		sta	oper_coarseE
		jsr	calcon
		sta	oper_onE

		lda	(zp_song_x_ptr),Y
		iny
		sta	oper_coarseH
		jsr	calcon
		sta	oper_onH

		lda	zp_echo			; if echo is active - don't load D
		bne	@skip_x_d2
		lda	(zp_song_x_ptr),Y
		iny
		sta	oper_coarseD
		jsr	calcon
		sta	oper_onD
@skip_x_d2:
		lda	#1
		sta	oper_offE
		sta	oper_offH
		sta	oper_offD


@note_load_dur:	lda	(zp_song_x_ptr),Y
		iny
		sta	zp_song_x_dur_ctdn

		lda	zp_x_env_attack_speed
		sta	zp_x_env_attack_ctdn
		lda	zp_x_env_decay_speed
		sta	zp_x_env_decay_ctdn

		jsr	update_x_ptr

song_x_parse_skip:



; #####          ###   #####  ####   #####    #    #   #         ####     #    ####    ###   #####  ####
;     #         #   #    #    #   #  #       # #   #   #         #   #   # #   #   #  #   #  #      #   #
;    #          #        #    #   #  #      #   #  ## ##         #   #  #   #  #   #  #      #      #   #
;   #            ###     #    ####   ####   #   #  # # #         ####   #   #  ####    ###   ####   ####
;  #                #    #    # #    #      #####  #   #         #      #####  # #        #  #      # #
; #             #   #    #    #  #   #      #   #  #   #         #      #   #  #  #   #   #  #      #  #
; #####          ###     #    #   #  #####  #   #  #   #         #      #   #  #   #   ###   #####  #   #


song_z_note_ctdnlp:
		dec	zp_song_z_dur_ctdn
		beq	song_z_parse_againy0
		jmp	song_z_parse_skip

song_z_parse_againy0:
		ldy	#0
		; we assume there's a note before Y runs out!
song_z_parse_again:
		lda	(zp_song_z_ptr),Y
		iny
		cmp	#1
		bne	@sk_loop_start

		; NOTE: opposite sense of cmd 1/2 cf X stream!
		; end a loop command #1
		dec	zp_song_z_loop_ctr
		beq	song_z_parse_again	; exit loop, do next note
		lda	zp_song_z_loop_ptr
		sta	zp_song_z_ptr		
		lda	zp_song_z_loop_ptr+1
		sta	zp_song_z_ptr+1
		bne	song_z_parse_againy0	; always

	

@sk_loop_start:	cmp	#2
		bne	@sk_loop_end

	; start a loop command #1
		lda	(zp_song_z_ptr),Y
		iny
		tax
		inx
		stx	zp_song_z_loop_ctr
		jsr	update_z_ptr
		ldy	#0
		lda	zp_song_z_ptr
		sta	zp_song_z_loop_ptr
		lda	zp_song_z_ptr+1
		sta	zp_song_z_loop_ptr+1
		bne	song_z_parse_again	; always

@sk_loop_end:	cmp	#3
		bne	@sk_sub_commands

		lda	(zp_song_z_ptr),Y
		iny

		cmp	#4
		bne	@sk_envelope

		; ENVELOPE command
		lda	(zp_song_z_ptr),Y
		iny
		sta	zp_z_env_phase_def		

		lda	(zp_song_z_ptr),Y
		iny
		sta	zp_z_env_attack_speed

		lda	(zp_song_z_ptr),Y
		iny
		sta	zp_z_env_decay_speed

		jmp	song_z_parse_again

@sk_envelope:	jmp	song_z_parse_again


@sk_sub_commands:

		;load note value
		ldx	zp_z_env_phase_def
		stx	zp_z_env_phase_act
		beq	@load_note_decay_first
		; load a note with attack, start at 0 and work up

		sta	oper_coarseC
		jsr	calcon
		sta	oper_offC
		sta	oper_attackC_target		

		lda	#1
		sta	oper_onC
		bne	@note_load_dur
@load_note_decay_first:
		sta	oper_coarseC
		jsr	calcon
		sta	oper_onC
		sta	oper_attackC_target		

		lda	#1
		sta	oper_offC

@note_load_dur:
		lda	(zp_song_z_ptr),Y
		iny
		sta	zp_song_z_dur_ctdn

		lda	zp_z_env_attack_speed
		sta	zp_z_env_attack_ctdn
		lda	zp_z_env_decay_speed
		sta	zp_z_env_decay_ctdn


		jsr	update_z_ptr


song_z_parse_skip:
		jsr	song_x_envelope		; TODO: move inline
		jsr	song_z_envelope		; TODO: move inline
		jsr	song_beep

		clc	
		lda	zp_z_env_phase_def
		adc	#'0'
		sta	$7C00
		lda	zp_z_env_phase_act
		adc	#'0'
		sta	$7C01
		lda	oper_onC
		adc	#'0'
		sta	$7C02


		lda	zp_flag_half_speed
		eor	#$FF
		sta	zp_flag_half_speed
		bpl	@skzonly
		jmp	song_z_note_ctdnlp	; this skips to do X as well as Z!
@skzonly:

		jmp	song_x_note_ctdnlp	; only do this every other pass

;
; #   #          ###   #####  ####   #####    #    #   #         #####  #   #  #   #  #####  #       ###   ####   #####
; #   #         #   #    #    #   #  #       # #   #   #         #      #   #  #   #  #      #      #   #  #   #  #
;  # #          #        #    #   #  #      #   #  ## ##         #      ##  #  #   #  #      #      #   #  #   #  #
;   #    #####   ###     #    ####   ####   #   #  # # #         ####   # # #   # #   ####   #      #   #  ####   ####
;  # #              #    #    # #    #      #####  #   #         #      #  ##   # #   #      #      #   #  #      #
; #   #         #   #    #    #  #   #      #   #  #   #         #      #   #   # #   #      #      #   #  #      #
; #   #          ###     #    #   #  #####  #   #  #   #         #####  #   #    #    #####  #####   ###   #      #####
;

	

song_x_envelope:	lda	zp_x_env_phase_act
		bne	song_x_envelope_attack
		
		; decay
		dec	zp_x_env_decay_ctdn	; speed gate	
		bne	song_x_envelope_exit

		ldx	zp_x_env_decay_speed	; reload
		stx	zp_x_env_decay_ctdn

		ldx	oper_onD
		dex
		beq	@skip_D
		stx	oper_onD
		inc	oper_offD		
@skip_D:		ldx	oper_onE
		dex
		beq	@skip_E
		stx	oper_onE
		inc	oper_offE
@skip_E:		ldx	oper_onH
		dex
		beq	@skip_endphase
		cpx	zp_x_env_decay_target
		beq	@skip_endphase
		stx	oper_onH			; TODO: rearrgange for speed?
		inc	oper_offH
		rts
@skip_endphase:	inc	zp_x_env_phase_act
		rts

song_x_envelope_attack:
		cmp	#2
		beq	song_x_envelope_exit

		dec	zp_x_env_attack_ctdn	; speed gate
		bne	song_x_envelope_exit
		lda	zp_x_env_attack_speed	; reload gate
		sta	zp_x_env_attack_ctdn

		; TODO: this compares to targets but we could just as well count down to off=1

		ldx	oper_onD
		inx
		cpx	#1
oper_attackD_target = *-1
		bcc	@skip_D1
		bne	@skip_D
@skip_D1:	stx	oper_onD
		dec	oper_offD
@skip_D:		ldx	oper_onE
		inx
		cpx	#1
oper_attackE_target = *-1
		bcc	@skip_E1
		bne	@skip_E
@skip_E1:	stx	oper_onE
		dec	oper_offE
@skip_E:		ldx	oper_onH
		inx
		cpx	#1
oper_attackH_target = *-1
		bcc	@skip_H1
		bne	@skip_endphase
@skip_H1:	stx	oper_onH
		dec	oper_offH
		rts
@skip_endphase:	dec	zp_x_env_phase_act
song_x_envelope_exit:
		rts


; #####          ###   #####  ####   #####    #    #   #         #####  #   #  #   #  #####  #       ###   ####   #####
;     #         #   #    #    #   #  #       # #   #   #         #      #   #  #   #  #      #      #   #  #   #  #
;    #          #        #    #   #  #      #   #  ## ##         #      ##  #  #   #  #      #      #   #  #   #  #
;   #    #####   ###     #    ####   ####   #   #  # # #         ####   # # #   # #   ####   #      #   #  ####   ####
;  #                #    #    # #    #      #####  #   #         #      #  ##   # #   #      #      #   #  #      #
; #             #   #    #    #  #   #      #   #  #   #         #      #   #   # #   #      #      #   #  #      #
; #####          ###     #    #   #  #####  #   #  #   #         #####  #   #    #    #####  #####   ###   #      #####



song_z_envelope:	lda	zp_z_env_phase_act
		bne	song_z_envelope_attack
		
		; decay
		dec	zp_z_env_decay_ctdn		
		bne	song_z_envelope_exit	; speed gate
		ldx	zp_z_env_decay_speed
		stx	zp_z_env_decay_ctdn	; reload

		ldx	oper_onC
		dex
		beq	@skip_endphase
		stx	oper_onC
		inc	oper_offC		
		rts
@skip_endphase:	inc	zp_z_env_phase_act
		inc	zp_z_env_phase_act
		rts

song_z_envelope_attack:
		cmp	#2
		beq	song_z_envelope_exit

		dec	zp_z_env_attack_ctdn
		bne	song_z_envelope_exit	; speed gate
		lda	zp_z_env_attack_speed
		sta	zp_z_env_attack_ctdn	; reload

		; TODO: this compares to targets but we could just as well count down to off=1

		ldx	oper_onC
		inx
		cpx	#1
oper_attackC_target = *-1
		bcc	@skip_C1
		bne	@skip_endphase
@skip_C1:	stx	oper_onC
		dec	oper_offC
		rts
@skip_endphase:	dec	zp_z_env_phase_act
song_z_envelope_exit:
		rts



song_beep:
		jsr	beep_256
		jsr	beep_256
		jsr	beep_256
beep_256:
; Play a tone using variable width pulses with modulation
beep256_lp:	

		dec	zp_osc_coarseC_ctdn
		bne	skip_osc_E

		; osc C
		lda	#$90
oper_coarseC = *-1
		sta	zp_osc_coarseC_ctdn
		lda	#$90
		POKEA
		ldx	#10
oper_onC = *-1
@onclp:		dex
		bne	@onclp
		lda	#$9F
		POKEA
		ldx	#1
oper_offC = *-1
@offclp:		dex
		bne	@offclp

skip_osc_E:

		dec	zp_osc_coarseE_ctdn
		bne	skip_osc_H

		; osc E
		lda	#$90
oper_coarseE = *-1
		sta	zp_osc_coarseE_ctdn
		lda	#$90
		POKEA
		ldx	#10
oper_onE = *-1
@onelp:		dex
		bne	@onelp
		lda	#$9F
		POKEA
		ldx	#1
oper_offE = *-1
@offelp:		dex
		bne	@offelp

skip_osc_H:

		dec	zp_osc_coarseH_ctdn
		bne	skip_osc_D

		; osc H
		lda	#$20
oper_coarseH := *-1
		sta	zp_osc_coarseH_ctdn
		lda	#$90
		POKEA
		ldx	#1
oper_onH = *-1
@onhlp:		dex
		bne	@onhlp
		lda	#$9F
		POKEA
		ldx	#1
oper_offH = *-1
@offhlp:		dex
		bne	@offhlp

skip_osc_D:

		dec	zp_osc_coarseD_ctdn
		bne	skip_osc_done

		; osc D
		lda	#$16
oper_coarseD := *-1
		sta	zp_osc_coarseD_ctdn
		lda	zp_echo			;; TODO: remove this and pick up from echo buffer
		bne	@skddd
		lda	#$90
		POKEA
@skddd:		ldx	#4
oper_onD = *-1
@ondlp:		dex
		bne	@ondlp
		lda	#$9F
		POKEA
		ldx	#1
oper_offD = *-1
@offdlp:		dex
		bne	@offdlp

skip_osc_done:

		ldx	#1
@dlp:		jsr	wait
		dex
		bne	@dlp
		dec	zp_beeb256
		beq	beeb256_ex
		jmp	beep256_lp
beeb256_ex:
wait:		rts

update_x_ptr:
		tya
		clc
		adc	zp_song_x_ptr
		sta	zp_song_x_ptr
		lda	zp_song_x_ptr+1
		adc	#0
		sta	zp_song_x_ptr+1
		rts

update_z_ptr:
		tya
		clc
		adc	zp_song_z_ptr
		sta	zp_song_z_ptr
		lda	zp_song_z_ptr+1
		adc	#0
		sta	zp_song_z_ptr+1
		rts

calcon:		; on entry A is osc period
		; on exit A is on/off period value 3/16 of osc period
		lsr	A
		lsr	A
		lsr	A
		sta	zp_temp1
		lsr	A
		clc
		adc	zp_temp1
		rts



HERE:		jmp HERE


anRTS:		rts



		.data


		.end