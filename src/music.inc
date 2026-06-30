
	.macro MX_LOOP_END
		.byte	2
	.endmacro

	.macro MX_LOOP_START n
		.byte	1, (n - 1) & $FF
	.endmacro

	.macro MX_END
		.byte	0,0,0,0,0,0
	.endmacro

	.macro MX_CMD_PORTA p0, p1, p2, p3
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
	.endmacro

	.macro MX_ECHO_OFF
	.endmacro


	.macro MX_NOTE_ECHO p_e, p_h, dur
		;;;;;;;;;;;;;;; !!!!!!!!!!!!!!!!!!!!!!!!! THIS IS A FRIG should be 2 notes and 1 dur, implement echo
		.byte	p_e, p_h, p_h, dur
	.endmacro

	.macro MX_NOTE_NECHO p_e, p_h, p_d, dur
		.byte	p_e, p_h, p_d, dur
	.endmacro