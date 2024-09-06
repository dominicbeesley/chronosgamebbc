
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

VIA_INT_T1	:= $40

CRTC_R1_H_DISP	:= 1
CRTC_R4_V_TOT	:= 4
CRTC_R7_V_SYNC	:= 7
CRTC_R12_ADDR   := 12


; SCREEN LAYOUT

;	       <--- 32 char cells = 64 bytes --->
;0	+--------------------------------------------+
;1	| Top play field                             |
;2	|                                            |
;3	|                                            |
;4	|                                            |
;...	..............................................
;11	|                                            |
;12	|                                            |
;13	|                                            |
;14	|                                            |
;15	+------------+-------------------------------+
;16	| Logo       |             
;17	|            |             
;18	|            |             
;19	|            |             
;...    ..............
;27	|            |             
;28	|            |             
;29	|            |             
;30	|            |             
;31	+------------+
;32
;33
;34     VSYNC on this line
;35
;36
;37
;38

SCREEN_V_TOT		:= 39
SCREEN_V_SYNC		:= 34

PLAYFIELD_V_TOT		:= 16
PLAYFIELD_H_DISP	:= 64

LOGO_V_TOT		:= SCREEN_V_TOT-PLAYFIELD_V_TOT		; goes to end of screen
LOGO_V_SYNC		:= SCREEN_V_SYNC-PLAYFIELD_V_TOT
LOGO_H_DISP		:= 36

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
		and	#VIA_INT_T1			
		beq	@notSysT1

		sta	sheila_SYSVIA_ifr

		; SYS via T1 has fired - we are in second half of screen so fiddle registers to:

		; Set second half of screen to be big...
		; Vtotal = 22 (38 - 16)
		lda	#CRTC_R4_V_TOT
		sta	sheila_CRTC_reg
		lda	#LOGO_V_TOT-1
		sta	sheila_CRTC_dat		

		; TODO move out of IRQ handler - can be set and forget as we wont reach this point in playfield
		lda	#CRTC_R7_V_SYNC
		sta	sheila_CRTC_reg
		lda	#LOGO_V_SYNC
		sta	sheila_CRTC_dat		
		
		jmp	@out
		
@notSysT1:	lda	sheila_USRVIA_ifr
		and	#VIA_INT_T1
		beq	@notUsrT1

		sta	sheila_USRVIA_ifr

		; USR via T1 has fired - we are in first half of screen so fiddle registers to:

		; Set first half of screen to be small and no vsync...
		lda	#CRTC_R4_V_TOT
		sta	sheila_CRTC_reg
		lda	#PLAYFIELD_V_TOT-1
		sta	sheila_CRTC_dat		

		; set next field start address to 0
		lda	#CRTC_R12_ADDR+1
		sta	sheila_CRTC_reg
		lda	#<(chronospipe/8)
		sta	sheila_CRTC_dat
		lda	#CRTC_R12_ADDR
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
		lda	#CRTC_R1_H_DISP
		sta	sheila_CRTC_reg
		lda	#LOGO_H_DISP
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

		lda	#CRTC_R12_ADDR+1
		sta	sheila_CRTC_reg
		lda	playfield_top_crtc
		sta	sheila_CRTC_dat
		lda	#CRTC_R12_ADDR
		sta	sheila_CRTC_reg
		lda	playfield_top_crtc+1
		sta	sheila_CRTC_dat

		; set H total to size of playfield in bytes
		lda	#CRTC_R1_H_DISP
		sta	sheila_CRTC_reg
		lda	#PLAYFIELD_H_DISP
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
