
		.include "hardware.inc"
		.include "oslib.inc"
		.include "mosrom.inc"
		.include "debug.inc"

		.export 	init_irq
		.export 	frame_ctr
		.importzp	zp_cycle
		.import 	chronospipe


		; wait this many cycles
	.macro WAIT_N n
		.local wl1
		.local wl
		.local I
		.local N

		I = (n-34) / 5
		N = (n-((5*I)+34)) / 2
		
		;jsr			;6
		pha			;3
		txa			;2
		pha			;3
		; this many ~ 1000 cycle loops ~= 0.5ms ~= character line
@wl1:		ldx	#I		;2
@wl:		dex			;2*X
		bne	@wl		;2+3*X
		pla			;4
		tax			;2
		pla			;4
		.repeat N
		nop
		.endrepeat
		rts			;6

	.endmacro


	
		.zeropage

		.data

;FRAME=20096		; What is needed with GS GM6845S with i-lace (adds extra 1.5 * 64 after field...)
FRAME=19968		; what should be needed for non-interlaced - works on GS GM6845S and b-em
;FRAME=20000		; what is needed for b-em with i-lace

VIA_INT_T1	:= $40

CRTC_R0_H_TOT   := 0
CRTC_R1_H_DISP	:= 1
CRTC_R2_H_SYNC	:= 2
CRTC_R4_V_TOT	:= 4
CRTC_R7_V_SYNC	:= 7
CRTC_R12_ADDR   := 12


; SCREEN LAYOUT

;	       <--- 32 char cells = 64 bytes --->
;                                                         1    1    1
;            1    2    3    4    5    6    7    8    9    0    2    3
;       0    0    0    0    0    0    0    0    0    0    0    0    0
;0	+-------------------------------+            H             T
;1	| Top play field                |            H             T
;2	|                               |            H             T
;3	|                               |            H             T
;4	|                               |            H             T
;...	.................................            H             T
;11	|                               |            H             T
;12	|                               |            H             T
;13	|                               |            H             T
;14	|                               |            H             T
;15	+------------+------------------+            H             T  <-USR T1 fires here
;16	| Logo       |                               H             T
;17	|            |                               H             T
;18	|            |                               H             T
;19	|            |                               H             T
;20	|            |                               H             T  <-SYS T1 fires here
;...    ..............                               H             T
;27	|            |                               H             T
;28	|            |                               H             T
;29	|            |                               H             T
;30	|            |                               H             T
;31	+------------+                               H             T
;32                                                  H             T
;33                                                  H             T
;34     VVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVV
;35                                                  H             T
;36                                                  H             T
;37                                                  H             T
;38	TTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTT


; The re-center line between playfield and logo something like this...
;14	|                               |            H             T
;15	+------------+------------------+            H             T  <-USR T1 fires here
;16	| Logo       |                               H             T
;17	|            |                               H             T



SCREEN_V_TOT		:= 39
SCREEN_V_SYNC		:= 34
SCREEN_H_TOT		:= 128
SCREEN_H_SYNC		:= 90

PLAYFIELD_V_TOT		:= 16
PLAYFIELD_H_DISP	:= 64

LOGO_V_TOT		:= SCREEN_V_TOT-PLAYFIELD_V_TOT		; goes to end of screen
LOGO_V_SYNC		:= SCREEN_V_SYNC-PLAYFIELD_V_TOT
LOGO_H_DISP		:= 36

LOGO_H_ADJ		:= 10					; this is used to center the logo area


USR_T1_V		:= 15					; char row on which USR_T1 fires
SYS_T1_V		:= 20					;

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

		ldy	#SYS_T1_V+(SCREEN_V_TOT-SCREEN_V_SYNC)
		jsr	wait_1024y


		ldx	#<(FRAME-2)
		ldy	#>(FRAME-2)
		stx	sheila_SYSVIA_t1cl
		sty	sheila_SYSVIA_t1ch


		; now USR T1 set up to fire in top half of screen ~ 6 lines after vsync
		jsr	wait_vsync

		ldy	#USR_T1_V+(SCREEN_V_TOT-SCREEN_V_SYNC)
		jsr	wait_1024y

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

	.proc wait_1024y

@lp:
		jsr	@wait_1019
		dey			;2
		bne	@lp		;3
		rts

@wait_1019:	
		WAIT_N 1019

	.endproc


wait_PFS:	WAIT_N 680
wait_SSS:	WAIT_N 130

		;jsr			;6
wait_16:	nop			;2
		nop			;2
		jsr	@w		;6+6+2
@w:		nop			;2
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
		

@notSysT1:	
		lda	sheila_USRVIA_ifr
		and	#VIA_INT_T1
		beq	@notUsrT1

;================================================================================
; USR T1
;================================================================================
		sta	sheila_USRVIA_ifr

		; USR via T1 has fired - we are near end of playfield

		; Set first half of screen to be small and no vsync...we do this whilst scanning the last char row!
		lda	#CRTC_R4_V_TOT
		sta	sheila_CRTC_reg
		lda	#PLAYFIELD_V_TOT-1
		sta	sheila_CRTC_dat		

		; set next field start address to 0...this is latched at start of next "pseudo-field"
		lda	#CRTC_R12_ADDR+1
		sta	sheila_CRTC_reg
		lda	#<(chronospipe/8)
		sta	sheila_CRTC_dat
		lda	#CRTC_R12_ADDR
		sta	sheila_CRTC_reg
		lda	#>(chronospipe/8)
		sta	sheila_CRTC_dat

		; wait a character row...we should be now in blanking area just after last scan line of first part		
		jsr	wait_PFS		; this number arrived at by experimentation....

		DEBUG_STRIPE	$F73
		DEBUG_STRIPE	$000

		; logo areas is narrow

		lda	#CRTC_R1_H_DISP
		sta	sheila_CRTC_reg
		lda	#LOGO_H_DISP
		sta	sheila_CRTC_dat

		; we need to fiddle one scan line to be slightly longer to center the smaller area without upsetting
		; the sync train
		
		lda	#CRTC_R0_H_TOT
		sta	sheila_CRTC_reg
		lda	#SCREEN_H_TOT+LOGO_H_ADJ-1
		sta	sheila_CRTC_dat

		; wait until next scan line and adjust the rest to have H-sync earlier but back to normal line length
		jsr	wait_SSS	; slightly less than a scan line which is 128

		lda	#CRTC_R0_H_TOT
		sta	sheila_CRTC_reg
		lda	#SCREEN_H_TOT-1
		sta	sheila_CRTC_dat

		lda	#CRTC_R2_H_SYNC
		sta	sheila_CRTC_reg
		lda	#SCREEN_H_SYNC-LOGO_H_ADJ
		sta	sheila_CRTC_dat

		; don't blank some pixels at left hand side to hide drawing
		lda	#$30
		sta	SHEILA_NULA_CTLAUX


		lda	#$20
		sta	SHEILA_NULA_CTLAUX


		inc 	frame_ctr

		bne	@out

@notUsrT1:	lda	sheila_SYSVIA_ifr
		and	#$02
		beq	@ukirq
		sta	sheila_SYSVIA_ifr

;================================================================================
; USR T1
;================================================================================


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


		nop
		nop
		nop
		nop
		nop
		nop
		nop
		nop
		nop
		nop
		nop
		nop
		nop
		nop
		nop
		nop


		; we need to fiddle one scan line to be slightly shorter to center the larger playfield
		
		lda	#CRTC_R0_H_TOT
		sta	sheila_CRTC_reg
		lda	#SCREEN_H_TOT-LOGO_H_ADJ-1
		sta	sheila_CRTC_dat

		; wait until next scan line and adjust the rest to have H-sync earlier but back to normal line length
		jsr	wait_SSS	; slightly less than a scan line which is 128

		lda	#CRTC_R0_H_TOT
		sta	sheila_CRTC_reg
		lda	#SCREEN_H_TOT-1
		sta	sheila_CRTC_dat

		lda	#CRTC_R2_H_SYNC
		sta	sheila_CRTC_reg
		lda	#SCREEN_H_SYNC
		sta	sheila_CRTC_dat

		; set H DISP to size of playfield in bytes
		lda	#CRTC_R1_H_DISP
		sta	sheila_CRTC_reg
		lda	#PLAYFIELD_H_DISP
		sta	sheila_CRTC_dat


		; blank some pixels at left hand side to hide drawing
		lda	#$38
		sta	SHEILA_NULA_CTLAUX


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
