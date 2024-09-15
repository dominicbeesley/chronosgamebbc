


	.segment "HEADER"
hlang:		.byte 0,0,0		; not a language
hserv:		jmp	service		; service entry
htype:		.byte 	$82		; rom type
hcopy:		.byte 	<hcopystr	; copyright offset
hver:		.byte	1
htitle:		.byte	"Chronos map data",0
hvers:		.byte	"0.01"
hcopystr:	.byte	0,"(C)2024 Dossysoft",0
	.code
service:	rts

	.data


	.segment "MAPDATA"
		.incbin "../build/src/map.bin"

	.end
