
		.include "hardware.inc"
		.include "oslib.inc"
		.include "mosrom.inc"

		.export 	init_irq
		.export 	frame_ctr
		.importzp	zp_cycle
		.import 	chronospipe
	
		.zeropage

		.data

;FRAME=20096		; What is needed with GS GM6845S with i-lace (adds extra 1.5 * 64 after field...)
FRAME=19968		; what should be needed for non-interlaced - works on GS GM6845S and b-em
;FRAME=20000		; what is needed for b-em with i-lace


old_irq1:	.word	0		; old irq1 vector
frame_ctr:	.byte	0		; increments each frame at mid-point

		.code
init_irq:	

		sei

		; stop VIA interrupts
		lda	#$7F
		sta	sheila_SYSVIA_ier
		sta	sheila_USRVIA_ier

		; install ourself on IRQ1V

		lda	IRQ1V
		sta	old_irq1
		lda	IRQ1V+1
		sta	old_irq1+1

		lda	#<my_irq1
		sta	IRQ1V
		lda	#>my_irq1
		sta	IRQ1V+1

		; now SYS T1 set up to fire in bottom half of screen - non scrolling, score/logo area

		; wait for VS and  count for over half a field = frame (not interlaced) = 20000 cycles = 10ms
		jsr	wait_vsync

		ldy	#25
		jsr	wait_512y


		ldx	#<(FRAME-2)
		ldy	#>(FRAME-2)
		stx	sheila_SYSVIA_t1cl
		sty	sheila_SYSVIA_t1ch


		; now USR T1 set up to fire in top half of screen ~ 6 lines after vsync
		jsr	wait_vsync

		ldy	#20
		jsr	wait_512y

		ldx	#<(FRAME-2)
		ldy	#>(FRAME-2)
		stx	sheila_USRVIA_t1cl
		sty	sheila_USRVIA_t1ch


		jsr	wait_vsync
		; enable and reset relevant irq's
		lda	#$C0
		sta	sheila_SYSVIA_ier
		sta	sheila_USRVIA_ier
		lda	#$82
		sta	sheila_SYSVIA_ier
		lda	#$7F
		sta	sheila_SYSVIA_ifr
		sta	sheila_USRVIA_ifr

		cli
		rts

wait_vsync:
		; wait for vsync
		; clear the vsync bit in IFR
		lda	#$02
		sta	sheila_SYSVIA_ifr
@lp:		bit	sheila_SYSVIA_ifr
		beq	@lp
		rts

wait_512y:	jsr	wait_512
		dey			;2
		bne	wait_512y	;3
		rts

		;jsr			;6
wait_512:	pha			;3
		txa			;2
		pha			;3
		; this many ~ 1000 cycle loops ~= 0.5ms ~= character line
@wl1:		ldx	#193		;2
@wl:		dex			;2*X
		bne	@wl		;2+3*X
		pla			;4
		tax			;2
		pla			;4
		nop			;2
		rts			;6

my_irq1:	lda	sheila_SYSVIA_ifr
		and	#$40					
		beq	@notSysT1

		sta	sheila_SYSVIA_ifr

		; SYS via T1 has fired - we are in second half of screen so fiddle registers to:

		; Set second half of screen to be big...
		; Vtotal = 22 (38 - 16)
		lda	#4
		sta	sheila_CRTC_reg
		lda	#22
		sta	sheila_CRTC_dat		

		lda	#7
		sta	sheila_CRTC_reg
		lda	#34-16			; vsync pos
		sta	sheila_CRTC_dat		
		
;		lda	#$07
;		sta	$FE23
;		lda	#$07
;		sta	$FE23


		jmp	@out
		
@notSysT1:	lda	sheila_USRVIA_ifr
		and	#$40
		beq	@notUsrT1

		sta	sheila_USRVIA_ifr

		; USR via T1 has fired - we are in first half of screen so fiddle registers to:

		; Set first half of screen to be small and no vsync...
		; Vtotal = 22 (38 - 16)
		lda	#4
		sta	sheila_CRTC_reg
		lda	#15
		sta	sheila_CRTC_dat		

		; set next field start address to 0
		lda	#13
		sta	sheila_CRTC_reg
		lda	#<(chronospipe/8)
		sta	sheila_CRTC_dat
		lda	#12
		sta	sheila_CRTC_reg
		lda	#>(chronospipe/8)
		sta	sheila_CRTC_dat

;		lda	#$00
;		sta	$FE23
;		lda	#$70
;		sta	$FE23

		
		jsr	wait_512

;		lda	#19
;@www:		sbc	#1
;		bne	@www
;
		lda	#1
		sta	sheila_CRTC_reg
		lda	#36
		sta	sheila_CRTC_dat



		lda	#$20
		sta	SHEILA_NULA_CTLAUX


		inc 	frame_ctr

		bne	@out

@notUsrT1:	lda	sheila_SYSVIA_ifr
		and	#$02
		beq	@ukirq
		sta	sheila_SYSVIA_ifr

		; vsync set playfield top

		; set next field start address to playfield

		lda	#13
		sta	sheila_CRTC_reg
		lda	playfield_top_crtc
		sta	sheila_CRTC_dat
		lda	#12
		sta	sheila_CRTC_reg
		lda	playfield_top_crtc+1
		sta	sheila_CRTC_dat

		lda	#1
		sta	sheila_CRTC_reg
		lda	#$40
		sta	sheila_CRTC_dat


		lda	have_nula
		beq	@nonula
		; apply nula scroll offset
		lda	zp_cycle
		sec
		sbc	#1		
		and	#3
		eor	#3
		clc
		rol	A
		ora	#$20
		sta	SHEILA_NULA_CTLAUX
@nonula:		


@out:		lda	zp_mos_INT_A
		rti



@ukirq:		jmp	(old_irq1)




		.end
