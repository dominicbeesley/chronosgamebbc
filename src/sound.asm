
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
			pla
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
zp_osc_coarseL_ctdn:	.res	1

zp_beeb256:		.res	1

zp_song_x_ptr:		.res	2
zp_song_x_dur_ctdn:	.res	1
zp_song_x_loop_ptr:	.res	2
zp_song_x_loop_ctr:	.res	1

zp_song_y_ptr:		.res	2
zp_song_y_dur_ctdn:	.res	1
zp_song_y_loop_ptr:	.res	2
zp_song_y_loop_ctr:	.res	1


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

zp_y_env_decay_speed:	.res	1

zp_y_env_decay_ctdn:	.res	1

zp_z_env_phase_def:	.res	1
zp_z_env_attack_speed:	.res	1
zp_z_env_decay_speed:	.res	1

zp_z_env_phase_act:	.res	1
zp_z_env_attack_ctdn:	.res	1
zp_z_env_decay_ctdn:	.res	1

zp_z_glide_flag:		.res	1
zp_z_glide_speed:		.res	1
zp_z_glide_pitch_acc:	.res	1
zp_z_glide_pitch_target:	.res	1

zp_perc_ptr:		.res	2
zp_perc_offs:		.res	1
zp_perc_multiplier:	.res	1
zp_perc_dur_ctdn:		.res	1

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
		stx	zp_z_glide_flag
		;;stx	_oper_echo_handler+1
		stx	zp_perc_dur_ctdn		; when 0 blocks 
		inx
		stx	zp_song_x_loop_ctr
		stx	zp_song_x_dur_ctdn
		stx	zp_song_y_loop_ctr
		stx	zp_song_y_dur_ctdn
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

		lda	#<music_y_stream
		sta	zp_song_y_ptr
		sta	zp_song_y_loop_ptr
		lda	#>music_y_stream
		sta	zp_song_y_ptr+1
		sta	zp_song_y_loop_ptr+1


		lda	#<music_z_stream
		sta	zp_song_z_ptr
		sta	zp_song_z_loop_ptr
		lda	#>music_z_stream
		sta	zp_song_z_ptr+1
		sta	zp_song_z_loop_ptr+1


		jmp	song_x_note_ctdnlp

song_exeunt:	lda	#0
		sta	sheila_SYSVIA_ddra
		cli

		rts


song_x_note_ctdnlp:
		dec	zp_song_x_dur_ctdn
		beq	song_x_parse_againy0
		jmp	song_x_parse_skip

song_x_parse_againy0:
		ldy	#0
		; we assume there's a note before Y runs out!
song_x_parse_again:
		lda	(zp_song_x_ptr),Y
		beq	song_exeunt
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


@not_env:	cmp	#2
		bne	@not_perc_restart

@perc_restart:	ldx	#0
		stx	zp_perc_offs
		inx
		stx	zp_perc_dur_ctdn
		jmp 	song_x_parse_again

@not_perc_restart:
		cmp	#3
		bne	@not_perc_off
		ldx	#0
		stx	zp_perc_offs
		stx	zp_perc_dur_ctdn
		jmp 	song_x_parse_again

@not_perc_off:	cmp	#4
		bne	@not_perc_pat_1

		ldx	#<perc_effect_1_stream
		lda	#>perc_effect_1_stream
		bne	@ss			; always

@not_perc_pat_1:	cmp	#5
		bne	@not_perc_pat_2

		ldx	#<perc_effect_2_stream
		lda	#>perc_effect_2_stream
@ss:		stx	zp_perc_ptr
		sta	zp_perc_ptr+1
		jmp	@perc_restart		; always

@not_perc_pat_2:	cmp	#8
		bne	@not_perc_speed

		lda	(zp_song_x_ptr),Y
		iny
		sta	zp_perc_multiplier

		jmp	@perc_restart

@not_perc_speed:	jmp	song_x_parse_again	; TODO-shorten?

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

;
; #   #                        ###   #####  ####   #####    #    #   #         ####     #    ####    ###   #####  ####
; #   #                       #   #    #    #   #  #       # #   #   #         #   #   # #   #   #  #   #  #      #   #
;  # #                        #        #    #   #  #      #   #  ## ##         #   #  #   #  #   #  #      #      #   #
;   #           #####          ###     #    ####   ####   #   #  # # #         ####   #   #  ####    ###   ####   ####
;   #                             #    #    # #    #      #####  #   #         #      #####  # #        #  #      # #
;   #                         #   #    #    #  #   #      #   #  #   #         #      #   #  #  #   #   #  #      #  #
;   #                          ###     #    #   #  #####  #   #  #   #         #      #   #  #   #   ###   #####  #   #


song_y_note_ctdnlp:
		dec	zp_song_y_dur_ctdn
		beq	song_y_parse_againy0
		jmp	song_y_parse_skip

song_y_parse_againy0:
		ldy	#0
		; we assume there's a note before Y runs out!
song_y_parse_again:
		lda	(zp_song_y_ptr),Y
		iny
		cmp	#1
		bne	@sk_loop_start

		; NOTE: opposite sense of cmd 1/2 cf X stream!
		; end a loop command #1
		dec	zp_song_y_loop_ctr
		beq	song_y_parse_again	; exit loop, do next note
		lda	zp_song_y_loop_ptr
		sta	zp_song_y_ptr		
		lda	zp_song_y_loop_ptr+1
		sta	zp_song_y_ptr+1
		bne	song_y_parse_againy0	; always

	

@sk_loop_start:	cmp	#2
		bne	@sk_loop_end

	; start a loop command #1
		lda	(zp_song_y_ptr),Y
		iny
		tax
		inx
		stx	zp_song_y_loop_ctr
		jsr	update_y_ptr
		ldy	#0
		lda	zp_song_y_ptr
		sta	zp_song_y_loop_ptr
		lda	zp_song_y_ptr+1
		sta	zp_song_y_loop_ptr+1
		bne	song_y_parse_again	; always

@sk_loop_end:	cmp	#3
		bne	@sk_sub_commands

		; ENVELOPE command - decay only
		lda	(zp_song_y_ptr),Y
		iny
		sta	zp_y_env_decay_speed		

		jmp	song_y_parse_again

@sk_sub_commands:

		;load note value

		sta	oper_coarseL
		jsr	calcon_l
		sta	oper_onL

		lda	#1
		sta	oper_offL
		sta	zp_y_env_decay_ctdn

		lda	(zp_song_y_ptr),Y
		iny
		sta	zp_song_y_dur_ctdn


		jsr	update_y_ptr


song_y_parse_skip:


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

		cmp	#1
		bne	@sk_glide_on

		ldx	#$FF
		stx	zp_z_glide_flag

@sk_glide_on:	cmp	#2
		bne	@sk_glide_off

		ldx	#$0
		stx	zp_z_glide_flag

@sk_glide_off:
		cmp	#3
		bne	@sk_glide_speed

		lda	(zp_song_z_ptr),Y
		iny
		sta	zp_z_glide_speed


@sk_glide_speed:
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

		sta 	zp_z_glide_pitch_target
		ldx	zp_z_glide_flag
		bne	@skip_glide_act		; if glide is active don't set the pitch here, do it in glider
		sta	zp_z_glide_pitch_acc	; set current pitch in glider too
		jsr	osc_c_pitch_set

@skip_glide_act:
@note_load_dur:
		lda	(zp_song_z_ptr),Y
		iny
		sta	zp_song_z_dur_ctdn

		lda	#1			; different to X-stream?
		sta	zp_z_env_attack_ctdn
		sta	zp_z_env_decay_ctdn


		jsr	update_z_ptr


song_z_parse_skip:



;
;   #    ####   ####   #      #   #         #####  #   #  #   #  #####  #       ###   ####   #####   ###
;  # #   #   #  #   #  #      #   #         #      #   #  #   #  #      #      #   #  #   #  #      #   #
; #   #  #   #  #   #  #       # #          #      ##  #  #   #  #      #      #   #  #   #  #      #
; #   #  ####   ####   #        #           ####   # # #   # #   ####   #      #   #  ####   ####    ###
; #####  #      #      #        #           #      #  ##   # #   #      #      #   #  #      #          #
; #   #  #      #      #        #           #      #   #   # #   #      #      #   #  #      #      #   #
; #   #  #      #      #####    #           #####  #   #    #    #####  #####   ###   #      #####   ###




		jsr	song_x_envelope		; TODO: move inline
		jsr	song_y_envelope		; TODO: move inline
		jsr	song_z_envelope		; TODO: move inline
		jsr	song_z_portamento		; TODO: move inline
		jsr	song_percussion		; TODO: move inline
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

		lda	zp_perc_dur_ctdn
		pha
		lsr	A
		lsr	A
		lsr	A
		lsr	A
		jsr	hexA
		sta	$7C10
		pla
		jsr	hexA
		sta	$7C11

		lda	zp_perc_multiplier
		pha
		lsr	A
		lsr	A
		lsr	A
		lsr	A
		jsr	hexA
		sta	$7C12
		pla
		jsr	hexA
		sta	$7C13

		lda	zp_perc_offs
		pha
		lsr	A
		lsr	A
		lsr	A
		lsr	A
		jsr	hexA
		sta	$7C14
		pla
		jsr	hexA
		sta	$7C15

		lda	zp_perc_ptr+1
		pha
		lsr	A
		lsr	A
		lsr	A
		lsr	A
		jsr	hexA
		sta	$7C16
		pla
		jsr	hexA
		sta	$7C17

		lda	zp_perc_ptr
		pha
		lsr	A
		lsr	A
		lsr	A
		lsr	A
		jsr	hexA
		sta	$7C18
		pla
		jsr	hexA
		sta	$7C19

		lda	zp_flag_half_speed
		eor	#$FF
		sta	zp_flag_half_speed
		bpl	@skzonly
		jmp	song_y_note_ctdnlp	; this skips to do X as well as Z!
@skzonly:

		jmp	song_x_note_ctdnlp	; only do this every other pass

osc_c_pitch_set:
		ldx	zp_z_env_phase_act
		beq	@load_note_decay_first
		; load a note with attack, start at 0 and work up

		sta	oper_coarseC
		jsr	calcon_l
		sta	oper_offC
		sta	oper_attackC_target		

		lda	#1
		sta	oper_onC
		bne	@sk
@load_note_decay_first:
		sta	oper_coarseC
		jsr	calcon_l
		sta	oper_onC
		sta	oper_attackC_target		

		lda	#1
		sta	oper_offC
@sk:		rts


;
; ####   #####  ####    ###   #   #   ###    ###    ###    ###   #   #
; #   #  #      #   #  #   #  #   #  #   #  #   #    #    #   #  #   #
; #   #  #      #   #  #      #   #  #      #        #    #   #  ##  #
; ####   ####   ####   #      #   #   ###    ###     #    #   #  # # #
; #      #      # #    #      #   #      #      #    #    #   #  #  ##
; #      #      #  #   #   #  #   #  #   #  #   #    #    #   #  #   #
; #      #####  #   #   ###    ###    ###    ###    ###    ###   #   #

song_percussion:	ldx	zp_perc_dur_ctdn
		dex
		cpx	#$FF
		beq	@perc_exit
		stx	zp_perc_dur_ctdn
		cpx	#0
		bne	@perc_exit

		; we now have to make a noise of some sort!
		ldx	zp_perc_offs
		txa
		tay
		inx
		inx
		stx	zp_perc_offs
		lda	(zp_perc_ptr),Y
		iny
		sta	zp_temp1	
		ldx	zp_perc_multiplier
		dex
		beq	@nomul
@mullp:		clc
		adc	zp_temp1
		dex
		bne	@mullp
@nomul:		sta	zp_perc_dur_ctdn

		; dispatch instrument
		lda	(zp_perc_ptr),Y
		iny

		lda	#$90
		POKEA

		ldx	#0
@w:		dex
		bne	@w

		lda	#$9F
		POKEA


		; check if next note is a restart
		lda	(zp_perc_ptr),Y
		cmp	#$FF
		bne	@perc_not_restart
		ldx	#0
		stx	zp_perc_offs
@perc_not_restart:		


@perc_exit:	rts		


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

;
; #   #          ###   #####  ####   #####    #    #   #         #####  #   #  #   #  #####  #       ###   ####   #####
; #   #         #   #    #    #   #  #       # #   #   #         #      #   #  #   #  #      #      #   #  #   #  #
;  # #          #        #    #   #  #      #   #  ## ##         #      ##  #  #   #  #      #      #   #  #   #  #
;   #    #####   ###     #    ####   ####   #   #  # # #         ####   # # #   # #   ####   #      #   #  ####   ####
;   #               #    #    # #    #      #####  #   #         #      #  ##   # #   #      #      #   #  #      #
;   #           #   #    #    #  #   #      #   #  #   #         #      #   #   # #   #      #      #   #  #      #
;   #            ###     #    #   #  #####  #   #  #   #         #####  #   #    #    #####  #####   ###   #      #####
;



song_y_envelope:	; decay
		dec	zp_y_env_decay_ctdn		
		bne	@skip_endphase		; speed gate
		ldx	zp_y_env_decay_speed
		stx	zp_y_env_decay_ctdn	; reload

		ldx	oper_onL
		dex
		beq	@skip_endphase
		stx	oper_onL
		inc	oper_offL		
@skip_endphase:	rts



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



;  #####          ###   #####  ####   #####    #    #   #         ####    ###   ####   #####    #    #   #  #####  #   #  #####   ###
;      #         #   #    #    #   #  #       # #   #   #         #   #  #   #  #   #    #     # #   #   #  #      #   #    #    #   #
;     #          #        #    #   #  #      #   #  ## ##         #   #  #   #  #   #    #    #   #  ## ##  #      ##  #    #    #   #
;    #            ###     #    ####   ####   #   #  # # #         ####   #   #  ####     #    #   #  # # #  ####   # # #    #    #   #
;   #                #    #    # #    #      #####  #   #         #      #   #  # #      #    #####  #   #  #      #  ##    #    #   #
;  #             #   #    #    #  #   #      #   #  #   #         #      #   #  #  #     #    #   #  #   #  #      #   #    #    #   #
;  #####          ###     #    #   #  #####  #   #  #   #         #       ###   #   #    #    #   #  #   #  #####  #   #    #     ###


song_z_portamento:
		ldy	zp_z_glide_flag
		beq	@nog
		ldx	zp_z_glide_pitch_acc
		cpx	zp_z_glide_pitch_target	; add extra compare to allow envelope to complete
		beq	@nog
		ldy	zp_z_glide_speed
@glide_lp:	cpx	zp_z_glide_pitch_target
		beq	@out
		bcs	@over
		inx
		inx
@over:		dex		
		dey
		bne	@glide_lp
		txa
		stx	zp_z_glide_pitch_acc
@out:		txa
		jmp	osc_c_pitch_set
@nog:		rts

	.macro M_OSC name, mute
		.local next, relc, relon, reloff, n, n2, onlp, offlp
		dec	.ident(.sprintf("zp_osc_coarse%s_ctdn", name))
		bne	next
	
	.if mute
		lda	#$9F
	.else
		lda	#$90
	.endif
		sta	sheila_SYSVIA_ora
		sty	sheila_SYSVIA_orb
		; do the period, on loads here to save time - we need a 16 cycle break between orb loads
relc:		lda 	#1			; oscillator period reload
		sta	.ident(.sprintf("zp_osc_coarse%s_ctdn", name))
relon:		ldx	#1
		lda	#8
		bne	n			; timing - need 3 cycles
n:		sta	sheila_SYSVIA_orb
	
onlp:		dex
		bne	onlp

		lda	#$9F
		sta	sheila_SYSVIA_ora
		sty	sheila_SYSVIA_orb
		; do the off loads here to save time - we need a 16 cycle break between orb loads
reloff:		ldx	#1
		lda	#8
		nop
		nop
		bne	n2			; timing - need 3 cycles
n2:		sta	sheila_SYSVIA_orb

offlp:		dex
		bne	offlp
next:

.ident(.sprintf("oper_coarse%s", name)) = relc+1
.ident(.sprintf("oper_on%s", name)) = relon+1
.ident(.sprintf("oper_off%s", name)) = reloff+1

	.endmacro

song_beep:
		jsr	beep_256
		;jsr	beep_256
		jsr	beep_256
beep_256:
; Play a tone using variable width pulses with modulation
beep256_lp:	ldy	#0		; used in sound pokes in macros



		M_OSC "C", 0

		M_OSC "E", 0

		M_OSC "H", 0

		lda	zp_echo
		bne	echo
		M_OSC "D", 0
		jmp	noecho
echo:		nop
		nop
		nop
		nop
		jmp	noecho
noecho:


		lda	zp_beeb256
		ror	A
		bcc	notL

		M_OSC "L", 0
notL:		

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
update_y_ptr:
		tya
		clc
		adc	zp_song_y_ptr
		sta	zp_song_y_ptr
		lda	zp_song_y_ptr+1
		adc	#0
		sta	zp_song_y_ptr+1
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
calcon_l:
		lsr	A
		lsr	A
		sta	zp_temp1
		lsr	A
		clc
		adc	zp_temp1
		rts



HERE:		jmp HERE


anRTS:		rts


hexA:		AND	#$0F
		CMP	#$0A		; set carry for +1 if >9	
		BCC	@noa	; branch if <=9
		ADC	#6		; adjust if A to F
					; (six plus carry = 7!)
@noa:		ADC	#'0'		; add ASCII "0"
		rts

		.data


		.end