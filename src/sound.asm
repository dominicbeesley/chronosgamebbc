
	.importzp 	zp_z_env_phase_def
	.importzp 	zp_z_env_phase_act
	.importzp 	zp_perc_multiplier
	.importzp 	zp_perc_dur_ctdn
	.importzp 	zp_perc_offs
	.importzp 	zp_perc_ptr
	.autoimport

		.code


		jsr	song_init


m_loop:		jsr	song_play
		bcs	m_done

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

		jmp	m_loop

m_done:		jsr	song_finit
		rts
		



hexA:		AND	#$0F
		CMP	#$0A		; set carry for +1 if >9	
		BCC	@noa	; branch if <=9
		ADC	#6		; adjust if A to F
					; (six plus carry = 7!)
@noa:		ADC	#'0'		; add ASCII "0"
		rts
