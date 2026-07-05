
ENV_PHASE_ATTACK = 1
ENV_PHASE_DECAY = 0
ENV_PHASE_SUSTAIN = 2


	.macro MX_LOOP_END
		.byte	2
	.endmacro

	.macro MX_LOOP_START n
		.byte	1, (n - 1) & $FF
	.endmacro

	.macro MX_END
		.byte	0,0,0,0,0,0
	.endmacro

	.macro MX_CMD_ENVELOPE phase, attack_speed, decay_speed, decay_target
		.byte	$FF, 1, phase, attack_speed, decay_speed, decay_target
	.endmacro

	.macro MX_ARP_RESTART
	.endmacro

	.macro MX_ARP_OFF
	.endmacro

	.macro MX_ARP_ON_1
	.endmacro

	.macro MX_ARP_ON_2
	.endmacro

	.macro MX_AY_MUL n
	.endmacro

	.macro MX_ECHO_ON
		.byte	$FF, $09
	.endmacro

	.macro MX_ECHO_OFF
		.byte	$FF, $0A
	.endmacro

;;;;;;;;;;;;;;; !!!!!!!!!!!!!!!!!!!!!!!!! THIS IS A FRIG should be 2 notes and 1 dur, implement echo
	.macro MX_NOTE_ECHO p_e, p_h, dur
		
		.byte	p_e, p_h, dur
	.endmacro

	.macro MX_NOTE_NECHO p_e, p_h, p_d, dur
		.byte	p_e, p_h, p_d, dur
	.endmacro



	.macro MZ_LOOP_END
		.byte	$01
	.endmacro

	.macro MZ_LOOP_START n
		.byte	$02, (n - 1) & $FF
	.endmacro

	.macro MZ_GLIDE_ON
		.byte	3,1
	.endmacro

	.macro MZ_GLIDE_OFF
		.byte	3,2
	.endmacro

	.macro MZ_GLIDE_SPEED n
		.byte	3,3,n	
	.endmacro

	.macro MZ_ENVELOPE phase, attack_speed, decay_speed
		.byte 3, 4, phase, attack_speed, decay_speed
	.endmacro

	.macro MZ_ECHO_VOLUME n
	.endmacro

	.macro MZ_ECHO_ON
	.endmacro

	.macro MZ_ECHO_OFF
	.endmacro

	.macro MZ_NOTE p, dur
		.byte p, dur
	.endmacro

