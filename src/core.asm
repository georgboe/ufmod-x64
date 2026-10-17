; CORE.ASM
; --------
; uFMOD public source code release. Provided as-is.

if VIBRATO_OR_TREMOLO
sin127  db 00h,0Ch,19h,25h,31h,3Ch,47h,51h,5Ah,62h,6Ah,70h,75h,7Ah,7Dh,7Eh
        db 7Fh,7Eh,7Dh,7Ah,75h,70h,6Ah,62h,5Ah,51h,47h,3Ch,31h,25h,19h,0Ch
endif
if INSTRUMENTVIBRATO_ON
sin64   db 00h,02h,03h,05h,06h,08h,09h,0Bh,0Ch,0Eh,10h,11h,13h,14h,16h,17h
        db 18h,1Ah,1Bh,1Dh,1Eh,20h,21h,22h,24h,25h,26h,27h,29h,2Ah,2Bh,2Ch
        db 2Dh,2Eh,2Fh,30h,31h,32h,33h,34h,35h,36h,37h,38h,38h,39h,3Ah,3Bh
        db 3Bh,3Ch,3Ch,3Dh,3Dh,3Eh,3Eh,3Eh,3Fh,3Fh,3Fh,40h,40h,40h,40h,40h
endif
if AMIGAPERIODS_ON
f0_0833 dd 8.3333336e-2
f13_375 dd 1.3375e1
endif
f0_0013 dd 1.302083375e-3
f8363_0 dd 8.3630004275e3

; Mixer ramping
Ramp:
; [arg0] - ptr. to end of buffer
; ESI    - _mod+36
; EDI    - length
; EDX    - buffer
	; LOOP THROUGH CHANNELS
	mov PCX,[PSI+uF_MOD_Channels-36]
	push PBX
	push PBP
loop_ch:
	push PSI
	mov PSI,[PCX+FSOUND_CHANNEL_fsptr] ; load the correct SAMPLE pointer for this channel
	test PSI,PSI ; if(!fsptr) skip this channel!
	jz MixExit_1
	push PDX ; mix buffer
	push PDX ; cur. mix buffer pointer
	mov ebx,[PCX+FSOUND_CHANNEL_mixpos]
	; Set up a mix counter. See what will happen first, will the output buffer
	; end be reached first? or will the end of the sample be reached first? whatever
	; is smallest will be the mixcount.
	push PDI
CalculateLoopCount:
	cmp BYTE PTR [PCX+FSOUND_CHANNEL_speeddir],0
	mov edx,[PSI+uF_SAMP_loopstart]
	mov eax,[PCX+FSOUND_CHANNEL_mixposlo]
	jne samplesleftbackwards
	; work out how many samples left from mixpos to loop end
	add edx,[PSI+uF_SAMP_looplen]
	sub edx,ebx
	ja submixpos
	mov edx,[PSI+uF_SAMP__length]
	sub edx,ebx
submixpos:
	; edx : samples left (loopstart+looplen-mixpos)
	neg edx
	neg eax
	adc edx,ebx
samplesleftbackwards:
	; work out how many samples left from mixpos to loop start
	neg edx
	add edx,ebx
	js MixExit
	; edx:eax now contains number of samples left to mix
	mov ebp,[PCX+FSOUND_CHANNEL_speedlo]
	shrd eax,edx,5
	mov ebx,[PCX+FSOUND_CHANNEL_speedhi]
	shr edx,5
	shrd ebp,ebx,5
	jnz speedok ; divide by 0 check
	mov ebp,FREQ_40HZ_p
	mov DWORD PTR [PCX+FSOUND_CHANNEL_speedlo],FREQ_40HZ_f
speedok:
	div ebp
	xor ebp,ebp
	neg edx
	adc eax,ebp
	jz DoOutputbuffEnd
if UF_X64
	lea PBX,[uFMOD_fopen]
else
	mov ebx,OFFSET uFMOD_fopen
endif
	cmp eax,edi
	; set a flag to say mix will end when end of output buffer is reached
	seta [PBX-22]   ; mix_endflag
	jae staywithoutputbuffend
	xchg eax,edi
staywithoutputbuffend:
if RAMP_NONE
else
	movzx eax,WORD PTR [PCX+FSOUND_CHANNEL_ramp_count]
	; VOLUME RAMP SETUP
	; Reasons to ramp
	; 1 volume change
	; 2 sample starts (just treat as volume change - 0 to volume)
	; 3 sample ends (ramp last n number of samples from volume to 0)
	; now if the volume has changed, make end condition equal a volume ramp
endif
	mov edx,[PCX+FSOUND_CHANNEL_leftvolume]
	mov ebp,[PCX+FSOUND_CHANNEL_rightvolume]
if RAMP_NONE
	mov [PCX+FSOUND_CHANNEL_ramp_leftvolume],edx
	mov [PCX+FSOUND_CHANNEL_ramp_rightvolume],ebp
else
	shl ebp,16
	or ebp,edx
	test eax,eax
	mov [PBX-16],edi ; mmf+4 <- remember mix count before modifying it
	jz volumerampstart
	; if it tries to continue an old ramp, but the target has changed,
	; set up a new ramp
	cmp ebp,[PCX+FSOUND_CHANNEL_ramp_LR_target]
	je volumerampclamp ; restore old ramp
volumerampstart:
	; SETUP NEW RAMP
	mov [PCX+FSOUND_CHANNEL_ramp_LR_target],ebp
	shl edx,volumeramps_pow
	xor bp,bp
	sub edx,[PCX+FSOUND_CHANNEL_ramp_leftvolume]
	xor eax,eax
	sar edx,volumeramps_pow
	mov [PCX+FSOUND_CHANNEL_ramp_leftspeed],edx
	jz novolumerampL
	mov al,volumerampsteps
novolumerampL:
	shr ebp,16-volumeramps_pow
	sub ebp,[PCX+FSOUND_CHANNEL_ramp_rightvolume]
	sar ebp,volumeramps_pow
	mov [PCX+FSOUND_CHANNEL_ramp_rightspeed],ebp
	jz novolumerampR
	mov al,volumerampsteps
novolumerampR:
	test eax,eax
	mov [PCX+FSOUND_CHANNEL_ramp_count],ax
	jz volumerampend
volumerampclamp:
	cmp edi,eax
	jbe volumerampend ; dont clamp mixcount
	mov edi,eax
volumerampend:
	mov eax,[PCX+FSOUND_CHANNEL_ramp_leftspeed]
	mov [PBX],eax    ; ramp_leftspeed
	mov eax,[PCX+FSOUND_CHANNEL_ramp_rightspeed]
	mov [PBX+4],eax  ; ramp_rightspeed
endif
	mov [PBX-20],edi ; mmf
	; SET UP ALL OF THE REGISTERS HERE FOR THE INNER LOOP
	; edx : speed
	; ebx : mixpos
	; ebp : speed low
	; esi : destination pointer
	; edi : counter
	mov ebx,[PCX+FSOUND_CHANNEL_mixpos]
	lea PBX,[PBX*2+PSI+uF_SAMP_buff]
	push PSI
	cmp BYTE PTR [PCX+FSOUND_CHANNEL_speeddir],0
	mov PSI,[PSP+2*PSZ] ; <- cur. mix buffer
	mov edx,[PCX+FSOUND_CHANNEL_speedhi]
	mov ebp,[PCX+FSOUND_CHANNEL_speedlo]
	je MixLoop16
	; neg edx:ebp
	neg ebp
	not edx
	sbb edx,-1
	align 4
MixLoop16:
	push PDI
	push PDX
	movsx edi,WORD PTR [PBX]
	movsx eax,WORD PTR [PBX+2]
	mov edx,[PCX+FSOUND_CHANNEL_mixposlo]
	sub eax,edi
	shr edx,1 ; force unsigned
	imul edx
	shl edi,volumeramps_pow-1
	shld edx,eax,volumeramps_pow
	add edx,edi
if RAMP_NONE
	mov eax,edx
	imul edx,[PCX+FSOUND_CHANNEL_ramp_rightvolume]
	add [PSI],edx
	imul DWORD PTR [PCX+FSOUND_CHANNEL_ramp_leftvolume]
	add [PSI+4],eax
else
	xchg eax,edx
	mov edi,eax
	imul DWORD PTR [PCX+FSOUND_CHANNEL_ramp_rightvolume]
	shrd eax,edx,volumeramps_pow-1
	rol edx,1
	and edx,1
	add eax,edx
	sar eax,1
	add [PSI],eax
	xchg eax,edi
	imul DWORD PTR [PCX+FSOUND_CHANNEL_ramp_leftvolume]
	shrd eax,edx,volumeramps_pow-1
	rol edx,1
	and edx,1
	add eax,edx
	mov edi,[uFMOD_fopen+4] ; cur_ramp_rightspeed
	sar eax,1
	add [PSI+4],eax
	mov edx,[uFMOD_fopen]   ; cur_ramp_leftspeed
	add [PCX+FSOUND_CHANNEL_ramp_rightvolume],edi ; + cur_ramp_rightspeed
	add [PCX+FSOUND_CHANNEL_ramp_leftvolume],edx  ; + cur_ramp_leftspeed
endif
	pop PDX
	xor eax,eax
	add [PCX+FSOUND_CHANNEL_mixposlo],ebp
	pop PDI
	adc eax,edx
if UF_X64
	cdqe ; the sample step is negative when mixing backwards
endif
	add PSI,8
	dec edi
	lea PBX,[PBX+PAX*2]
	jnz MixLoop16
	mov edi,[PSP+8*PSZ] ; find out how many OUTPUT samples left to mix
	mov [PSP+2*PSZ],PSI ; update cur. mix buffer
	sub edi,esi
	shr edi,3         ; edi <- # of samples left
	pop PSI           ; esi <- sample pointer
	lea eax,[PSI+uF_SAMP_buff]
	sub ebx,eax
	shr ebx,1
	mov [PCX+FSOUND_CHANNEL_mixpos],ebx
if RAMP_NONE
	xor edx,edx
else
	; DID A VOLUME RAMP JUST HAPPEN?
	movzx edx,WORD PTR [PCX+FSOUND_CHANNEL_ramp_count]
	test edx,edx
	jz DoOutputbuffEnd
	mov eax,[mmf]
	cdq
	sub [PCX+FSOUND_CHANNEL_ramp_count],ax
	; if(!rampcount) a ramp has FINISHED, so finish the rest of the mix
	jnz DoOutputbuffEnd
	sub eax,[mmf+4]
	; clear out the ramp speeds
	mov [PCX+FSOUND_CHANNEL_ramp_leftspeed],edx
	neg eax
	mov [PCX+FSOUND_CHANNEL_ramp_rightspeed],edx
	; is it 0 because ramp ended only? or both ended together?
	; if sample ended together with ramp... problems... loop isn't handled
	sbb edx,edx
	; start again and continue rest of mix
	test edi,edx
	jnz CalculateLoopCount ; dont start again if nothing left
	xor edx,edx
endif
DoOutputbuffEnd:
	cmp [mix_endflag],dl
	jne MixExit
	movzx eax,BYTE PTR [PSI+uF_SAMP_loopmode]
	; SWITCH ON LOOP MODE TYPE
	dec eax ; check for normal loop (FSOUND_LOOP_NORMAL = 1)
	jnz CheckBidiLoop
	mov eax,[PSI+uF_SAMP_loopstart]
	mov ebp,[PSI+uF_SAMP_looplen]
	add eax,ebp
	cmp ebx,eax
	jbe rewind_ok
	sub ebx,eax
	xchg eax,ebx
	div ebp
rewind_ok:
	sub ebp,edx
	sub ebx,ebp
	sbb edx,edx
	not edx
	and ebx,edx
	jmp ChkLoop_OK
CheckBidiLoop:
	dec eax ; FSOUND_LOOP_BIDI = 2
	neg eax
	adc edx,-1
if UF_X64
	movsxd rdx,edx ; 0 or -1, also used as a mask for the 64-bit fsptr
endif
	and [PCX+FSOUND_CHANNEL_mixposlo],edx
	and [PCX+FSOUND_CHANNEL_mixpos],edx
	and [PCX+FSOUND_CHANNEL_fsptr],PDX
	jz MixExit
	cmp [PCX+FSOUND_CHANNEL_speeddir],al ; FSOUND_MIXDIR_FORWARDS
	je BidiForward
BidiBackwards:
	mov eax,[PSI+uF_SAMP_loopstart]
	neg ebp
	dec eax
	sub ebp,1
	dec BYTE PTR [PCX+FSOUND_CHANNEL_speeddir] ; set FSOUND_MIXDIR_FORWARDS
	sbb eax,ebx
	mov ebx,[PSI+uF_SAMP_loopstart]
	add ebx,eax
	cmp eax,[PSI+uF_SAMP_looplen]
	jl BidiFinish
BidiForward:
	mov eax,[PSI+uF_SAMP_loopstart]
	add eax,[PSI+uF_SAMP_looplen]
	lea edx,[PAX-1]
	sbb eax,ebx
	neg ebp
	xchg eax,ebx
	sub ebp,1
	adc ebx,edx
	inc BYTE PTR [PCX+FSOUND_CHANNEL_speeddir] ; go backwards
	cmp ebx,[PSI+uF_SAMP_loopstart]
	jl BidiBackwards
BidiFinish:
	mov [PCX+FSOUND_CHANNEL_mixposlo],ebp
ChkLoop_OK:
	test edi,edi
	mov [PCX+FSOUND_CHANNEL_mixpos],ebx
	jnz CalculateLoopCount
MixExit:
	pop PDI
	pop PAX ; discard cur. mix buffer pointer
	pop PDX
MixExit_1:
	add PCX,FSOUND_CHANNEL_size
	pop PSI
	cmp PCX,[PSI+uF_MOD_uFMOD_Ch-36]
	jl loop_ch
	pop PBP
	pop PBX
	ret

if AMIGAPERIODS_ON
AmigaPeriod:
; [sptr] in ECX
; note   in EAX
; ESI != 0
	mov edx,132
	push PDI
	sub edx,eax
	push PSI
	test eax,eax
	push PDX
	movsx eax,BYTE PTR [PCX+uF_SAMP_finetune]
	mov edi,edx
	jz _do_inc
	cdq
	shl edx,1
_do_inc:
	inc edx
exp2:
	fild DWORD PTR [PSP]
	fmul DWORD PTR [f0_0833] ; /12.0f
	fld st0
	frndint
	fsub st1,st0
	fxch st1
	f2xm1
	fld1
	faddp st1,st0
	fscale
	fstp st1
	fmul DWORD PTR [f13_375] ; *13.375f
	fistp DWORD PTR [PSP]
	test esi,esi
	pop PCX
	jz exp2_end
	sub edi,edx
	push PDI
	xor esi,esi
	mov edi,ecx
	jmp exp2
exp2_end:
	sub ecx,edi
	test edx,edx
	jns _do_imul
	neg ecx
_do_imul:
	imul ecx
	and edx,127 ; +2^7-1
	add eax,edx
	sar eax,7
	pop PSI
	add eax,edi
	pop PDI
	ret
endif ; AMIGAPERIODS_ON

; DESCRIPTION: To carry out a vibrato at a certain depth and speed
if VIBRATO_OR_VOLSLIDE
	if TREMOLO_ON
	VibratoOrTremolo:
	; cptr+2 = ESI
		movzx ecx,BYTE PTR [PSI+uF_CHAN_vibpos-2]
		mov al,[PSI+uF_CHAN_wavecontrol-2]
		mov edx,ecx
		add dl,[PSI+uF_CHAN_vibspeed-2]
		and edx,3Fh
		and eax,3 ; switch(cptr->wavecontrol&3)
		mov [PSI+uF_CHAN_vibpos-2],dl
		jz vibrato_c0
		; C2 : Sqare wave
		rol ecx,27
		sbb edx,edx
		xor edx,7Fh
		or edx,1
		dec eax
		jnz vibrato_default
		; C1 : Triangle wave (ramp down)
		shr edx,24
		ror ecx,23
		add edx,ecx
		neg edx
		jmp vibrato_default
	vibrato_c0:
		; C0 : Sine wave
		; delta = 127 sin(2 Pi x/64)
		mov eax,ecx
		and ecx,1Fh
		shr eax,6
	if UF_X64
	lea r8,[sin127]
	movzx edx,BYTE PTR [r8+PCX]
else
	movzx edx,BYTE PTR [OFFSET sin127+ecx]
endif
		sbb eax,eax
		xor edx,eax
		sub edx,eax
	vibrato_default:
		movsx eax,BYTE PTR [PSI+uF_CHAN_vibdepth-2]
		imul edx  ; delta *= cptr->vibdepth
		sar eax,5
		ret
	endif

Vibrato:
; cptr+2 = ESI
	if TREMOLO_ON
		call VibratoOrTremolo
		sar eax,1
	else
		movzx ecx,BYTE PTR [PSI+uF_CHAN_vibpos-2]
		mov al,[PSI+uF_CHAN_wavecontrol-2]
		mov edx,ecx
		add dl,[PSI+uF_CHAN_vibspeed-2]
		and edx,3Fh
		and eax,3 ; switch(cptr->wavecontrol&3)
		mov [PSI+uF_CHAN_vibpos-2],dl
		jz vibrato_c0
		; C2 : Sqare wave
		rol ecx,27
		sbb edx,edx
		xor edx,7Fh
		or edx,1
		dec eax
		jnz vibrato_default
		; C1 : Triangle wave (ramp down)
		shr edx,24
		ror ecx,23
		add edx,ecx
		neg edx
		jmp vibrato_default
	vibrato_c0:
		; C0 : Sine wave
		; delta = 127 sin(2 Pi x/64)
		mov eax,ecx
		and ecx,1Fh
		shr eax,6
	if UF_X64
	lea r8,[sin127]
	movzx edx,BYTE PTR [r8+PCX]
else
	movzx edx,BYTE PTR [OFFSET sin127+ecx]
endif
		sbb eax,eax
		xor edx,eax
		sub edx,eax
	vibrato_default:
		movsx eax,BYTE PTR [PSI+uF_CHAN_vibdepth-2]
		imul edx  ; delta *= cptr->vibdepth
		sar eax,6
	endif
	mov [PSI+uF_CHAN_freqdelta-2],eax
	or BYTE PTR [PSI+uF_CHAN_notectrl-2],FMUSIC_FREQ
	ret
endif ; VIBRATO_OR_VOLSLIDE

if TREMOLO_ON
Tremolo:
; cptr+2 = ESI
	if VIBRATO_OR_VOLSLIDE
		push PSI
		add PSI,uF_CHAN_tremolopos-uF_CHAN_vibpos
		call VibratoOrTremolo
		pop PSI
	else
		movzx ecx,BYTE PTR [PSI+uF_CHAN_tremolopos-2]
		mov al,[PSI+uF_CHAN_wavecontrol-2]
		mov edx,ecx
		add dl,[PSI+uF_CHAN_tremolospeed-2]
		and edx,3Fh
		and eax,3 ; switch(cptr->wavecontrol&3)
		mov [PSI+uF_CHAN_tremolopos-2],dl
		jz tremolo_c0
		; C2 : Sqare wave
		rol ecx,27
		sbb edx,edx
		xor edx,7Fh
		or edx,1
		dec eax
		jnz tremolo_default
		; C1 : Triangle wave (ramp down)
		shr edx,24
		ror ecx,23
		add edx,ecx
		neg edx
		jmp tremolo_default
	tremolo_c0:
		; C0 : Sine wave
		; delta = 127 sin(2 Pi x/64)
		mov eax,ecx
		and ecx,1Fh
		shr eax,6
	if UF_X64
	lea r8,[sin127]
	movzx edx,BYTE PTR [r8+PCX]
else
	movzx edx,BYTE PTR [OFFSET sin127+ecx]
endif
		sbb eax,eax
		xor edx,eax
		sub edx,eax
	tremolo_default:
		movsx eax,BYTE PTR [PSI+uF_CHAN_tremolodepth-2]
		imul edx
		sar eax,5
	endif
	mov [PSI+uF_CHAN_voldelta-2],eax
	or BYTE PTR [PSI+uF_CHAN_notectrl-2],FMUSIC_VOLUME
	ret
endif ; TREMOLO_ON

if PORTATO_OR_VOLSLIDE
Portamento:
; cptr+2 = ESI
	or BYTE PTR [PSI+uF_CHAN_notectrl-2],FMUSIC_FREQ
	mov eax,[PSI+uF_CHAN_freq-2]
	mov ecx,[PSI+uF_CHAN_portatarget-2]
	movzx edx,BYTE PTR [PSI+uF_CHAN_portaspeed-2]
	shl edx,2
	sub eax,ecx
	jg porta_do_sub
	add eax,edx
	jg _do_trim
	jmp _no_trim
porta_do_sub:
	sub eax,edx
	jl _do_trim
_no_trim:
	add ecx,eax
_do_trim:
	mov [PSI+uF_CHAN_freq-2],ecx
	ret
endif ; PORTATO_OR_VOLSLIDE

if VOLUME_OR_PANENVELOPE
Envelope:
; cptr+2   = ESI
; env_iptr = ECX
; control  = AL
; Win32: the locals below env_tick are kept under ESP
; Win64: 16 bytes are reserved for them on top of the pushed locals
env_type     EQU (-4-UF_X64*20)
envstopped   EQU (-8-UF_X64*24)
envdelta     EQU (-12-UF_X64*28)
env_value    EQU (-16-UF_X64*32)
valfrac      EQU (-20-UF_X64*36)
; env_tick     = -24 (Win64: -64)
sustain_l2   EQU (-26+UF_X64*12)
sustain_l1   EQU (-27+UF_X64*12)
sustain_loop EQU (-28+UF_X64*12)
env_next     EQU (-32+UF_X64*20)
env_pos      EQU (-36+UF_X64*28)
	push PDI
	push PBX
	push PBP
	mov PBP,PSP
if UF_X64
	sub rsp,16
endif
	; Initialize local vars with PAN/VOL data
	lea PDI,[PCX+uF_INST_PANPoints]
	xor ebx,ebx
if PANENVELOPE_ON
	mov edx,[PDI+uF_INST_PANsustain-uF_INST_PANPoints]
	mov [PBP+sustain_loop],edx ; load PANsustain, PANLoopStart and PANLoopEnd
	mov cl,[PDI+uF_INST_PANtype-uF_INST_PANPoints]
	movzx edx,BYTE PTR [PDI+uF_INST_PANnumpoints-uF_INST_PANPoints]
endif
	or [PSI+uF_CHAN_notectrl-2],al ; cptr->notectrl |= control
if PANENVELOPE_ON
	if VOLUMEENVELOPE_ON
		cmp al,FMUSIC_VOLUME ; is it FMUSIC_VOLUME or FMUSIC_PAN?
	endif
	lea PAX,[PSI+uF_CHAN_envpanstopped-2]
endif
if VOLUMEENVELOPE_ON
	if PANENVELOPE_ON
		jnz pan_or_vol_ok
	endif
	; control = FMUSIC_VOLUME
	add PBX,uF_CHAN_envvol-uF_CHAN_envpan
	mov eax,[PDI+uF_INST_VOLsustain-uF_INST_PANPoints]
	mov [PBP+sustain_loop],eax ; load VOLsustain, VOLLoopStart and VOLLoopEnd
	mov cl,[PDI+uF_INST_VOLtype-uF_INST_PANPoints]
	movzx edx,BYTE PTR [PDI+uF_INST_VOLnumpoints-uF_INST_PANPoints]
	lea PAX,[PSI+uF_CHAN_envvolstopped-2]
	add PDI,uF_INST_VOLPoints-uF_INST_PANPoints
pan_or_vol_ok:
endif
	cmp [PAX],dh
	jne goto_envelope_ret
	push PCX      ; -> env_type
	push PAX      ; -> envstopped
	lea PCX,[PSI+PBX+uF_CHAN_envpanpos-2]
	lea PAX,[PSI+PBX+uF_CHAN_envpandelta-2]
	push PAX      ; -> envdelta
	lea PAX,[PSI+PBX+uF_CHAN_envpan-2]
	push PAX      ; -> env_value
	lea PAX,[PSI+PBX+uF_CHAN_envpanfrac-2]
	lea PBX,[PSI+PBX+uF_CHAN_envpantick-2]
	push PAX      ; -> valfrac
	mov eax,[PCX]
	cmp eax,edx   ; if(*pos>=numpoints) envelop out of bound
	push PBX      ; -> env_tick
	jge envelope_done
	movzx eax,WORD PTR [PDI+PAX*4]
	cmp [PBX],eax ; if(*tick == points[(*pos)<<1]) we are at the correct tick for the position
	jnz add_envdelta
	test BYTE PTR [PBP+env_type],FMUSIC_ENVELOPE_LOOP
	jz loop_ok
	movzx eax,BYTE PTR [PBP+sustain_l2]
	cmp [PCX],eax
	jnz loop_ok   ; if((type&FMUSIC_ENVELOPE_LOOP) && *pos == loopend) handle loop
	movzx eax,BYTE PTR [PBP+sustain_l1]
	mov [PCX],eax ; *pos = loopstart
	movzx eax,WORD PTR [PDI+PAX*4]
	mov [PBX],eax ; *tick = points[(*pos)<<1]
loop_ok:
	mov eax,[PCX]
	mov [PBP+env_pos],eax
	lea PAX,[PDI+PAX*4]
	dec edx
	movzx ebx,WORD PTR [PAX] ; get tick at this point
	cmp [PCX],edx
	mov edi,[PAX+4]
	movzx eax,WORD PTR [PAX+2]
	mov [PBP+env_next],edi ; get tick at next point
	mov PDX,[PBP+env_value]
	mov [PDX],eax ; *value = points[(currpos<<1)+1]
	jne env_continue
	; if it is at the last position, abort the envelope and continue last value
	mov PAX,[PBP+envstopped]
	inc BYTE PTR [PAX] ; *envstopped = TRUE
goto_envelope_ret:
	jmp Envelope_Ret
env_continue:
	shl eax,16
	sub edi,eax
	xchg eax,edi
	xor ax,ax
	; sustain
	test BYTE PTR [PBP+env_type],FMUSIC_ENVELOPE_SUSTAIN
	jz not_sustain
	movzx edx,BYTE PTR [PBP+sustain_loop]
	cmp [PBP+env_pos],edx
	jne not_sustain
	cmp [PSI+uF_CHAN_keyoff-2],al
	je Envelope_Ret
not_sustain:
	; interpolate 2 points to find delta step
	inc DWORD PTR [PCX] ; (*pos)++
	mov PCX,[PBP+valfrac]
	mov [PCX],edi ; *valfrac = curr
	mov PDI,[PBP+envdelta]
	movzx ecx,WORD PTR [PBP+env_next]
	and DWORD PTR [PDI],0 ; *envdelta = 0
	sub ecx,ebx
	jz envelope_done
	cdq
	idiv ecx
	mov [PDI],eax ; *envdelta = (next-curr)/(nexttick-currtick)
	jmp envelope_done
add_envdelta:
	; interpolate
	mov PAX,[PBP+envdelta]
	mov ecx,[PAX]
	mov PAX,[PBP+valfrac]
	add [PAX],ecx ; *valfrac += *envdelta
envelope_done:
	pop PDX ; <- env_tick
	pop PAX ; <- valfrac
	pop PCX ; <- env_value
	mov eax,[PAX]
	inc DWORD PTR [PDX] ; (*tick)++
	sar eax,16
	mov [PCX],eax ; *value = *valfrac >> 16
Envelope_Ret:
	leave
	pop PBX
	pop PDI
	ret
endif ; VOLUME_OR_PANENVELOPE

if VOLUMEBYTE_ON
VolByte:
; volume = EDX
; cptr+2 = ESI
	sub edx,16
	jb switch_volume
	cmp edx,40h
	ja switch_volume
	; if(volume >= 0x10 && volume <= 0x50)
	mov [PSI+uF_CHAN_volume-2],edx
switch_volume:
	mov eax,edx
	and edx,0Fh
	shr eax,4 ; switch(volume>>4)
	sub eax,5
	jz case_6
	dec eax
	jz case_7
	dec eax
	jz case_6
	dec eax
	jz case_7
	sub eax,2
	jbe case_AB
	dec eax
	jz case_C
	dec eax
	jz case_D
	dec eax
	jz case_E
	dec eax
	jnz vol_default
	; case 0xF
	shl dl,4
	jz vol_z
	mov [PSI+uF_CHAN_portaspeed-2],dl
vol_z:
	and BYTE PTR [PSI+uF_CHAN_notectrl-2],NOT_FMUSIC_TRIGGER
if PORTATO_OR_VOLSLIDE
	mov eax,[PSI+uF_CHAN_period-2]
	mov [PSI+uF_CHAN_portatarget-2],eax ; cptr->portatarget = cptr->period
endif
vol_default:
	ret
case_6: ; / case 8
	neg edx
case_7: ; / case 9
	add [PSI+uF_CHAN_volume-2],edx
	ret
case_AB:
if UF_X64
	movsxd rax,eax ; -1 or 0
endif
	mov [PSI+PAX+uF_CHAN_vibspeed-1],dl
	ret
case_C:
	shl edx,4
	mov [PSI+uF_CHAN_pan-2],edx
	xchg eax,edx
case_D:
	neg edx
case_E:
	add [PSI+uF_CHAN_pan-2],edx
	or BYTE PTR [PSI+uF_CHAN_notectrl-2],FMUSIC_PAN
	ret
endif ; VOLUMEBYTE_ON

if TREMOR_ON
Tremor:
; cptr+2 = ESI
	or BYTE PTR [PSI+uF_CHAN_notectrl-2],FMUSIC_VOLUME
	mov dx,[PSI+uF_CHAN_tremorpos-2]
	cmp dl,dh
	jbe inc_pos
	mov ecx,[PSI+uF_CHAN_volume-2]
	neg ecx
	mov [PSI+uF_CHAN_voldelta-2],ecx
inc_pos:
	add dh,[PSI+uF_CHAN_tremoroff-2]
	cmp dl,dh
	jbe Tremor_Ret
	mov dl,-1
Tremor_Ret:
	inc edx
	mov [PSI+uF_CHAN_tremorpos-2],dl
	ret
endif ; TREMOR_ON

SetBPM:
; bpm = ECX
	test ecx,ecx
	mov eax,FSOUND_MixRate*5/2
	jz SetBPM_Ret
	cdq
	div ecx
SetBPM_Ret:
	mov DWORD PTR [_mod+uF_MOD_mixer_samplespertick],eax
	ret

; Loads an XM stream into memory. Returns non-zero on success.
LoadXM:
loadxm_count1      EQU -4
loadxm_numpat      EQU -8
loadxm_fnumpat     EQU (-12-UF_X64*68) ; Win64: holds a pointer, moved to a free 8-byte slot
loadxm_count2      EQU -16
loadxm_skip        EQU -20
loadxm_s0loopmode  EQU -38
loadxm_s0bytes     EQU -42
loadxm_s0looplen   EQU -48
loadxm_s0loopstart EQU -52
loadxm_sample_2    EQU -56
loadxm_pat_size    EQU -63
loadxm_pat         EQU -68
loadxm_tmp29       EQU -91
loadxm_tmp27       EQU -93
loadxm_tmp         EQU -120
; *uFMOD_fopen = EBP
if XM_FILE_ON
	call NWORD PTR [PBP] ; uFMOD_fopen
else
	if XM_RC_ON
		call NWORD PTR [PBP] ; uFMOD_fopen
	endif
endif
if UF_X64
	lea rax,[_mod]
else
	mov eax,OFFSET _mod
endif
	push PBP
	mov PSI,PAX
	mov edx,uF_MOD_size
	; buf  : EAX
	; size : EDX
	call NWORD PTR [PBP+PSZ] ; uFMOD_fread
	mov PBP,PSP
	xor ecx,ecx
	mov eax,[PSI+uF_MOD_mixer_samplespertick]
	push PCX ; -> loadxm_count1
	; GOTO PATTERN DATA
	lea eax,[PAX+60]
	; pos  : EAX
	; org  : ECX
	; !org : Z
	call uFMOD_lseek
	add PSP,-116
	push PBX
	; SAVE TRACK TITLE
if INFO_API_ON
	push 20 ; a title has max. 20 chars
	lea PDX,[PSI+17]
if UF_X64
	lea rdi,[szTtl]
else
	mov edi,OFFSET szTtl
endif
if UCODE
	xor eax,eax
endif
	pop PCX
loadxm_ttl:
	mov al,[PDX]
	inc PDX
	cmp al,20h ; copy only printable chars
	jl loadxm_ttl_ok
if UCODE
	stosw
else
	stosb
endif
loadxm_ttl_ok:
	dec ecx
	jnz loadxm_ttl
	xchg eax,ecx
	stosd
else
	xor eax,eax
endif
	; COUNT NUM. OF PATTERNS
	movzx ecx,WORD PTR [PSI+uF_MOD_numorders]
	movzx ebx,WORD PTR [PSI+uF_MOD_numpatternsmem]
	neg ebx
	mov PDI,PSI
	sbb edx,edx
	and ecx,edx
	neg ebx
	dec ecx
	movzx edx,dl
	mov [PBP+loadxm_fnumpat],ebx
if CHK4VALIDITY
	cmp ecx,edx
	ja loadxm_R
endif
loadxm_for_pats:
	mov dl,[PSI+uF_MOD_orderlist]
	cmp edx,eax
	jbe loadxm_for_continue
	xchg eax,edx
loadxm_for_continue:
	inc PSI
	dec ecx
	jns loadxm_for_pats
	mov [PBP+loadxm_numpat],eax
	inc eax
	mov PSI,PDI
	; ALLOCATE THE PATTERN ARRAY (whatever is bigger: fnumpat or numpat) & CHANNEL POOL
	cmp eax,ebx
	jae loadxm_pats_ok2
	xchg eax,ebx
loadxm_pats_ok2:
	movzx ecx,BYTE PTR [PSI+uF_MOD_numinsts]
	imul ecx,uF_INST_size
	mov [PSI+uF_MOD_numpatternsmem],ax
if UF_X64
	mov edi,eax
	shl edi,4 ; x uF_PAT_size
	add edi,ecx
else
	lea edi,[ecx+eax*uF_PAT_size]
endif
	mov eax,edi
	sub edi,ecx
	movzx ecx,BYTE PTR [PSI+uF_MOD_numchannels_xm]
if CHK4VALIDITY
	cmp ecx,64
	jle loadxm_numchan_ok
	xor ecx,ecx
loadxm_numchan_ok:
endif
	mov [PSI+uF_MOD_numchannels],ecx
	mov ebx,ecx
	shl ebx,uF_CHAN_shift ; *FSOUND_CHANNEL_size*2 == *uF_CHAN_size
if CHK4VALIDITY
	jz loadxm_R
endif
	mov [PBP+loadxm_count2],ecx
	lea eax,[PAX+PBX*2]
	; numbytes : EAX
	call alloc
	lea PDX,[PAX+PBX]
	mov [PSI+uF_MOD_Channels],PAX
	mov [PSI+uF_MOD_uFMOD_Ch],PDX
	mov ebx,uF_CHAN_size ; = FSOUND_CHANNEL_size*2
loop_2:
	mov BYTE PTR [PAX+FSOUND_CHANNEL_speedhi],1
	mov [PDX+uF_CHAN_cptr],PAX
	add PAX,PBX
	add PDX,PBX
	dec DWORD PTR [PBP+loadxm_count2]
	jnz loop_2
	mov [PSI+uF_MOD_pattern],PDX
	add PDI,PDX
	movzx ecx,WORD PTR [PSI+uF_MOD_defaultbpm]
	mov [PSI+uF_MOD_instrument],PDI
	mov PDI,PDX
	; bpm : ECX
	call SetBPM
	movzx ecx,WORD PTR [PSI+uF_MOD_defaultspeed]
if GLOBALVOL_ON
if UF_X64
	mov DWORD PTR [PSI+uF_MOD_globalvolume],64
else
	push 64
	pop DWORD PTR [esi+uF_MOD_globalvolume]
endif
endif
	mov [PSI+uF_MOD_speed],ecx
	; ALLOCATE INSTRUMENT ARRAY
	mov eax,[PBP+loadxm_fnumpat]
	; READ & UNPACK PATTERNS
loadxm_load_pats:
	push 9
	lea PAX,[PBP+loadxm_pat]
	pop PDX
	; buf  : EAX
	; size : EDX
	call NWORD PTR [uFMOD_fread]
	; ALLOCATE PATTERN BUFFER
	mov eax,[PBP+loadxm_pat_size] ; length of pattern & packed pattern size
	mov ecx,[PSI+uF_MOD_numchannels]
	cmp eax,10000h
	mov [PDI],eax
	movzx eax,ax
	jb loadxm_ldpats_continue ; skip an empty pattern
if CHK4VALIDITY
	cmp eax,257
	sbb edx,edx
	and eax,edx
	jz loadxm_R
endif
	mul ecx
	mov [PBP+loadxm_count2],eax
	lea eax,[PAX+PAX*4] ; x SIZE FMUSIC_NOTE
	; numbytes : EAX
	call alloc
	mov [PDI+uF_PAT_data],PAX
	xchg PAX,PBX
loadxm_for_rowsxchan:
	push PSI
	mov PSI,[uFMOD_fread]
	xor edx,edx
	lea PAX,[PBP+loadxm_skip]
	inc edx
	; buf  : EAX
	; size : EDX
	call PSI ; uFMOD_fread
	movzx edx,BYTE PTR [PBP+loadxm_skip]
	test dl,80h
	jz loadxm_noskip
	and edx,1
	jz loadxm_nonote
	mov PAX,PBX ; &nptr->note
	; buf  : EAX
	; size : EDX
	call PSI ; uFMOD_fread
loadxm_nonote:
	test BYTE PTR [PBP+loadxm_skip],2
	jz loadxm_nonumber
	xor edx,edx
	lea PAX,[PBX+1] ; &nptr->number
	inc edx
	; buf  : EAX
	; size : EDX
	call PSI ; uFMOD_fread
loadxm_nonumber:
	test BYTE PTR [PBP+loadxm_skip],4
	jz loadxm_novolume
	xor edx,edx
	lea PAX,[PBX+2] ; &nptr->volume
	inc edx
	; buf  : EAX
	; size : EDX
	call PSI ; uFMOD_fread
loadxm_novolume:
	test BYTE PTR [PBP+loadxm_skip],8
	jz loadxm_noeffect
	xor edx,edx
	lea PAX,[PBX+3] ; &nptr->effect
	inc edx
	; buf  : EAX
	; size : EDX
	call PSI ; uFMOD_fread
loadxm_noeffect:
	test BYTE PTR [PBP+loadxm_skip],16
	jz loadxm_isnote97
	xor edx,edx
	lea PAX,[PBX+4] ; &nptr->eparam
	inc edx
	jmp loadxm_skip_read
loadxm_noskip:
	test edx,edx
	jz loadxm_skip_z
	mov [PBX],dl
loadxm_skip_z:
	lea PAX,[PBX+1]
	mov dl,4
loadxm_skip_read:
	; buf  : EAX
	; size : EDX
	call PSI ; uFMOD_fread
loadxm_isnote97:
	pop PSI
	inc PBX
	mov dl,[PSI+uF_MOD_numinsts]
	cmp [PBX],dl
	jbe loadxm_number_ok
	mov BYTE PTR [PBX],0
loadxm_number_ok:
	add PBX,4
	dec DWORD PTR [PBP+loadxm_count2]
	jnz loadxm_for_rowsxchan
loadxm_ldpats_continue:
	inc DWORD PTR [PBP+loadxm_count1]
	mov eax,[PBP+loadxm_fnumpat]
	add PDI,uF_PAT_size
	cmp eax,[PBP+loadxm_count1]
	ja loadxm_load_pats
	; allocate and clean out any extra patterns
	mov ecx,[PBP+loadxm_numpat]
	cmp ecx,eax
	jb loadxm_extrapats_ok
	mov PBX,[PSI+uF_MOD_pattern]
	mov eax,[PSI+uF_MOD_numchannels]
	push PSI
if UF_X64
	mov esi,ecx
	shl rsi,4 ; x uF_PAT_size
	add rsi,rbx
else
	lea esi,[ebx+ecx*uF_PAT_size]
endif
	lea edi,[PAX+PAX*4]
	shl edi,6 ; numchannels*64*SIZE FMUSIC_NOTE
loadxm_for_extrapats:
	dec DWORD PTR [PBP+loadxm_numpat]
	mov eax,edi
	mov BYTE PTR [PSI],64 ; pptr->rows = 64
	; Allocate memory for pattern buffer
	; numbytes : EAX
	call alloc
	mov [PSI+uF_PAT_data],PAX
	sub PSI,uF_PAT_size
	mov eax,[PBP+loadxm_fnumpat]
	cmp [PBP+loadxm_numpat],eax
	jae loadxm_for_extrapats
	pop PSI
loadxm_extrapats_ok:
	xor eax,eax
	mov [PSI+uF_MOD_mixer_samplesleft],eax
	mov [PSI+uF_MOD_tick],eax
if PATTERNDELAY_ON
	lea PDI,[PSI+uF_MOD_patterndelay]
	stosd
else
	lea PDI,[PSI+uF_MOD_nextorder]
endif
	stosd
	stosd
	; Load instrument information
	mov al,[PSI+uF_MOD_numinsts]
	test al,al
	jz loadxm_ret1
	mov [PBP+loadxm_count1],al
	mov PBX,[PSI+uF_MOD_instrument]
loadxm_for_instrs:
	push 33
	lea PAX,[PBP+loadxm_tmp]
	pop PDX
	; buf  : EAX
	; size : EDX
	call NWORD PTR [uFMOD_fread] ; instrument size & name
	mov esi,[PBP+loadxm_tmp] ; firstsampleoffset = tmp[0]
	mov dl,[PBP+loadxm_tmp27]
	sub esi,33
	test dl,dl
	jz loadxm_inst_ok
if CHK4VALIDITY
	xor eax,eax
	cmp DWORD PTR [PBP+loadxm_tmp29],41
	sbb ecx,ecx
	not ecx
	or edx,ecx
	cmp dl,16
	ja loadxm_R ; if(numsamples > 16) goto error
endif
	mov edx,208
	lea PAX,[PBX+uF_INST_keymap]
	sub esi,edx
	; buf  : EAX
	; size : EDX
	call NWORD PTR [uFMOD_fread]
loadxm_inst_ok:
	xor ecx,ecx
	xchg eax,esi
	inc ecx ; SEEK_CUR
	; pos  : EAX
	; org  : ECX
	; !org : Z
	call uFMOD_lseek
	lea PDX,[PBX+uF_INST_VOLfade]
	xor eax,eax
	mov cx,[PDX]
	shl ecx,1
	cmp BYTE PTR [PDX+uF_INST_VOLnumpoints-uF_INST_VOLfade],2
	mov [PDX],cx ; iptr->VOLfade *= 2
	jnb ladxm_voltype_ok
	mov [PDX+uF_INST_VOLtype-uF_INST_VOLfade],al
ladxm_voltype_ok:
	cmp BYTE PTR [PDX+uF_INST_PANnumpoints-uF_INST_VOLfade],2
	jnb loadxm_PANtype_ok
	mov [PDX+uF_INST_PANtype-uF_INST_VOLfade],al
loadxm_PANtype_ok:
	cmp [PBP+loadxm_tmp27],al
	je loadx_for_loadsamp_end
	mov [PBP+loadxm_numpat],eax
	mov [PBP+loadxm_fnumpat],PBX ; uF_INST_sample
loadxm_for_samp:
	lea PAX,[PBP+loadxm_sample_2]
	mov edx,[PBP+loadxm_tmp29]
	; buf  : EAX
	; size : EDX
	call NWORD PTR [uFMOD_fread]
	mov esi,[PBP+loadxm_s0loopstart]
	mov edi,[PBP+loadxm_s0looplen]
	mov al,[PBP+loadxm_s0bytes]
	mov ecx,eax
	shr eax,4 ; sample[0].bytes >>= 4
	and al,1  ; [b 4] : 8/16 bit sample data
	mov [PBP+loadxm_s0bytes],al
	jz loadxm_s0bytes_ok
	shr DWORD PTR [PBP+loadxm_sample_2],1
	shr esi,1
	shr edi,1
loadxm_s0bytes_ok:
	mov eax,[PBP+loadxm_sample_2]
	cmp eax,esi
	jg loadxm_loopstart_ok
	mov esi,eax
loadxm_loopstart_ok:
	lea edx,[PSI+PDI]
	sub edx,eax
	js loadxm_looplen_ok
	sub edi,edx
loadxm_looplen_ok:
	and ecx,3 ; [b 0-1] : loop type
	jz loadxm_reset_sample
	test edi,edi
	jnz loadxm_s0loop_ok
loadxm_reset_sample:
	xor esi,esi
	xor ecx,ecx
	mov edi,eax
loadxm_s0loop_ok:
	mov [PBP+loadxm_s0loopstart],esi
	mov [PBP+loadxm_s0looplen],edi
	mov [PBP+loadxm_s0loopmode],cl
	lea eax,[PAX+PAX+26] ; sample[0].length*2+SIZE FSOUND_SAMPLE+4
	; numbytes : EAX
	call alloc
	mov PCX,[PBP+loadxm_fnumpat]
	mov [PCX],PAX
	; memcpy(iptr->sample[count2],sample,sizeof(FSOUND_SAMPLE))
	inc DWORD PTR [PBP+loadxm_numpat]
	add NWORD PTR [PBP+loadxm_fnumpat],PSZ
	push 5
	xchg PAX,PDI
	mov eax,[PBP+loadxm_numpat]
	pop PCX
	cmp al,[PBP+loadxm_tmp27]
	lea PSI,[PBP+loadxm_sample_2]
	rep movsd
	jb loadxm_for_samp
	; Load sample data
	mov [PBP+loadxm_numpat],ecx
	; ebx <- uF_INST_sample
loadx_for_loadsamp:
	mov PSI,[PBX+PCX*PSZ]
	xor eax,eax
	mov edx,[PSI]
	mov ch,[PSI+uF_SAMP_Resved]
	mov cl,[PSI+uF_SAMP_bytes]
if CHK4VALIDITY
	test edx,0FFC00000h
	jnz loadxm_R
endif
	add PSI,uF_SAMP_buff
if ADPCM_ON
	cmp ch,0ADh ; ModPlug 4-bit ADPCM
	jne loadxm_regular_samp
	inc edx
	mov PDI,PSI
	sar edx,1
	push PBX
	push PDX
	lea edx,[PDX+PDX*2]
	add PDI,PDX ; ptr = buff+compressed_length*3
	; Read in the compression table
	lea edx,[PAX+16] ; edx = 16
	lea PAX,[PBP+loadxm_sample_2]
	mov PBX,PAX
	; buf  : EAX
	; size : EDX
	call NWORD PTR [uFMOD_fread]
	; Read in the sample data
	pop PDX
	mov PAX,PDI
	; buf  : EAX
	; size : EDX
	call NWORD PTR [uFMOD_fread]
	; Decompress sample data
	mov PDX,PSI
	xor ecx,ecx ; delta
loadxm_unpack_loop:
	cmp PDX,PDI
	jge loadxm_unpack_ok
	mov al,[PDI]
	mov ah,al
	and al,0Fh
	xlatb
	shr ah,4
	inc PDI
	add ch,al
	mov al,ah
	xlatb
	add al,ch
	shl eax,24
	or ecx,eax
	mov [PDX],ecx
	shr ecx,16 ; ch <- delta
	add PDX,4
	jmp loadxm_unpack_loop
loadxm_unpack_ok:
	pop PBX
	jmp loadxm_chk_loop_bidi
loadxm_regular_samp:
endif
	shl edx,cl ; sptr->length << sptr->bytes
	mov PAX,PSI
	; buf  : EAX
	; size : EDX
	call NWORD PTR [uFMOD_fread]
	mov ecx,[PSI+uF_SAMP__length-uF_SAMP_buff]
	lea PDI,[PCX+PSI] ; buff = sptr->buff+sptr->length
	lea PAX,[PDI+PCX] ; ptr  = buff+sptr->length
	xor edx,edx
	cmp [PSI+uF_SAMP_bytes-uF_SAMP_buff],dl
	jne loadxm_16bit_ok
	; Promote to 16 bits
loadxm_to16bits:
	dec PAX
	dec PDI
	dec PAX
	mov dh,[PDI]
	cmp PAX,PDI
	mov [PAX],dx
	ja loadxm_to16bits
	xor edx,edx
loadxm_16bit_ok:
	mov PAX,PSI
	; Do delta conversion
loadxm_do_delta_conv:
	add dx,[PAX]
	mov [PAX],dx
	dec ecx
	lea PAX,[PAX+2]
	jg loadxm_do_delta_conv
	js loadxm_loops_ok
loadxm_chk_loop_bidi:
	mov eax,[PSI+uF_SAMP_looplen-uF_SAMP_buff]
	mov ecx,[PSI+uF_SAMP_loopstart-uF_SAMP_buff]
	add eax,ecx
	cmp BYTE PTR [PSI+uF_SAMP_loopmode-uF_SAMP_buff],2 ; LOOP_BIDI
	lea PAX,[PSI+PAX*2]
	jnz loadxm_chk_loop_normal
	mov cx,[PAX-2]
	jmp loadxm_fix_loop
loadxm_chk_loop_normal:
	cmp BYTE PTR [PSI+uF_SAMP_loopmode-uF_SAMP_buff],1 ; LOOP_NORMAL
	jnz loadxm_loops_ok
	mov cx,[PSI+PCX*2]
loadxm_fix_loop:
	mov [PAX],cx
loadxm_loops_ok:
	inc DWORD PTR [PBP+loadxm_numpat]
	mov ecx,[PBP+loadxm_numpat]
	cmp cl,[PBP+loadxm_tmp27]
	jb loadx_for_loadsamp
loadx_for_loadsamp_end:
	add PBX,uF_INST_size
	dec BYTE PTR [PBP+loadxm_count1]
	jnz loadxm_for_instrs
loadxm_ret1:
	inc eax
loadxm_R:
	pop PBX
donote_R:
	leave
	ret

DoNote:
; mod+36 = ESI
var_mod         EQU (-4-UF_X64*4)
donote_sptr     EQU (-8-UF_X64*8)
donote_jumpflag EQU (-10-UF_X64*16)
donote_porta    EQU (-12-UF_X64*16)
donote_oldpan   EQU (-16-UF_X64*16)
donote_currtick EQU (-20-UF_X64*16)
donote_oldfreq  EQU (-24-UF_X64*16)
donote_iptr     EQU (-28+UF_X64*4)
	; Point our note pointer to the correct pattern buffer, and to the
	; correct offset in this buffer indicated by row and number of channels
	mov eax,[PSI+uF_MOD_order-36]
	push PBP
	movzx ebx,BYTE PTR [PAX+PSI+uF_MOD_orderlist-36]
	mov PBP,PSP
	mov eax,[PSI+uF_MOD_row-36]
if UF_X64
	shl ebx,4 ; x uF_PAT_size
	add rbx,rcx
else
	lea ebx,[ecx+ebx*uF_PAT_size]
endif
	mov ecx,[PSI+uF_MOD_numchannels-36]
if PATTERNBREAK_ON
	if PATTERNJUMP_ON
		mov [PBP+donote_jumpflag],ch
	endif
endif
	mul ecx
	lea edi,[PAX+PAX*4] ; x SIZE FMUSIC_NOTE
	mov PDX,[PBX+uF_PAT_data]
	push PSI
	test PDX,PDX
	jz donote_R
	add PDI,PDX ; mod->pattern[mod->orderlist[mod->order]].data+(mod->row*mod->numchannels)
	sub PSP,24+UF_X64*8
	; Loop through each channel in the row
	shl ecx,uF_CHAN_shift ; x uF_CHAN_size
	jz donote_R
	push PSI
	mov PSI,[PSI+uF_MOD_uFMOD_Ch-36]
	push PBX
	inc PSI
	inc PSI
	add PCX,PSI
donote_for_channels:
	push PCX
	mov bl,[PDI+uF_NOTE_eparam]
	mov al,[PDI+uF_NOTE_effect]
	and ebx,0Fh
	cmp al,FMUSIC_XM_PORTATO
	je donote_doporta
	cmp al,FMUSIC_XM_PORTATOVOLSLIDE
donote_doporta:
	setz [PBP+donote_porta]
	; First store note and instrument number if there was one
	mov cl,[PDI+uF_NOTE_number]
	jz donote_rem_note
	dec cl
	js donote_rem_inst
	mov [PSI+uF_CHAN_inst-2],cl ; remember the instrument #
donote_rem_inst:
	mov cl,[PDI] ; get current note
	dec ecx
	cmp cl,96
	jae donote_rem_note
	mov [PSI+uF_CHAN_note-2],cl ; remember the note
donote_rem_note:
	movzx ecx,BYTE PTR [PSI+uF_CHAN_inst-2]
	mov PAX,[PBP+var_mod]
	imul ecx,uF_INST_size
	add PCX,[PAX+uF_MOD_instrument-36]
	movzx eax,BYTE PTR [PSI+uF_CHAN_note-2]
	cdq
	mov al,[PAX+PCX+uF_INST_keymap]
	cmp al,16
	mov [PBP+donote_iptr],PCX
	jae donote_set_sptr
	mov PDX,[PCX+PAX*PSZ+uF_INST_sample]
donote_set_sptr:
	test PDX,PDX
	jnz donote_valid_sptr
if UF_X64
	lea rdx,[DummySamp]
else
	mov edx,OFFSET DummySamp
endif
donote_valid_sptr:
	mov [PBP+donote_sptr],PDX
if NOTEDELAY_ON
	mov ecx,[PSI+uF_CHAN_freq-2]
	mov eax,[PSI+uF_CHAN_volume-2]
	mov [PBP+donote_oldfreq],ecx
	mov ecx,[PSI+uF_CHAN_pan-2]
	mov [PBP+donote_currtick],eax
	mov [PBP+donote_oldpan],ecx
endif
if TREMOLO_ON
	; if there is no more tremolo, set volume to volume + last tremolo delta
	mov al,[PDI+uF_NOTE_effect]
	cmp al,FMUSIC_XM_TREMOLO
	je donote_tremolo_vol
	cmp BYTE PTR [PSI+uF_CHAN_recenteffect-2],FMUSIC_XM_TREMOLO
	jne donote_tremolo_vol
	mov ecx,[PSI+uF_CHAN_voldelta-2]
	add [PSI+uF_CHAN_volume-2],ecx
donote_tremolo_vol:
	mov [PSI+uF_CHAN_recenteffect-2],al
endif
	xor ecx,ecx
	mov [PSI+uF_CHAN_voldelta-2],ecx
	mov [PSI+uF_CHAN_freqdelta-2],ecx
	mov BYTE PTR [PSI+uF_CHAN_notectrl-2],FMUSIC_VOLUME_OR_FREQ
	; PROCESS NOTE
	mov cl,[PDI] ; note
	dec ecx
	cmp cl,96
	jae donote_note_ok
	; get note according to relative note
	movsx eax,BYTE PTR [PDX+uF_SAMP_relative]
	add ecx,eax
	mov PAX,[PBP+var_mod]
	mov [PSI+uF_CHAN_realnote-2],cl
	; Get period according to realnote and finetune
	test BYTE PTR [PAX+uF_MOD_flags-36],1
	je donote_flagsn1
	mov PAX,[PBP+donote_sptr]
	movsx eax,BYTE PTR [PAX+uF_SAMP_finetune]
	cdq
	shl ecx,6
	sub eax,edx
	sar eax,1
	lea eax,[PCX+PAX-7680]
	neg eax
if AMIGAPERIODS_ON
	jmp donote_chk_porta
donote_flagsn1:
	xchg eax,ecx              ; note   : EAX
	mov PCX,[PBP+donote_sptr] ; [sptr] : ECX
	; ESI != 0
	call AmigaPeriod
donote_chk_porta:
	mov [PSI+uF_CHAN_period-2],eax
else
	mov [PSI+uF_CHAN_period-2],eax
donote_flagsn1:
	mov eax,[PSI+uF_CHAN_period-2]
endif
	; Frequency only changes if there are no portamento effects
	cmp BYTE PTR [PBP+donote_porta],0
	jne donote_freq_ok
	mov [PSI+uF_CHAN_freq-2],eax
donote_freq_ok:
	or BYTE PTR [PSI+uF_CHAN_notectrl-2],FMUSIC_TRIGGER
donote_note_ok:
	; PROCESS INSTRUMENT NUMBER
	cmp BYTE PTR [PDI+uF_NOTE_number],0
	je donote_zcptr_ok
	mov PAX,[PBP+donote_sptr]
	; DESCRIPTION: Reset current channel
	push PDI
	push 9
	movzx ecx,BYTE PTR [PAX+uF_SAMP_defvol]
	mov [PSI+uF_CHAN_volume-2],ecx
	pop PCX
	movzx eax,BYTE PTR [PAX+uF_SAMP_defpan]
	mov [PSI+uF_CHAN_pan-2],eax
if UF_X64
	xor eax,eax
	mov DWORD PTR [PSI+uF_CHAN_envvol-2],64
	lea PDI,[PSI+uF_CHAN_envvoltick-2]
	mov DWORD PTR [PSI+uF_CHAN_envpan-2],32
else
	push 64
	xor eax,eax
	pop DWORD PTR [esi+uF_CHAN_envvol-2]
	push 32
	lea edi,[esi+uF_CHAN_envvoltick-2]
	pop DWORD PTR [esi+uF_CHAN_envpan-2]
endif
	mov DWORD PTR [PSI+uF_CHAN_fadeoutvol-2],65536
	; memset(&cptr->envvoltick,0,36)
	rep stosd
	; Retrigger tremolo and vibrato waveforms
	mov cl,[PSI+uF_CHAN_wavecontrol-2]
	pop PDI
	cmp cl,4Fh
	jge z_tremolopos_ok
	mov [PSI+uF_CHAN_tremolopos-2],al ; = 0
z_tremolopos_ok:
	test cl,0Ch
	jnz z_vibpos_ok
	mov [PSI+uF_CHAN_vibpos-2],al ; = 0
z_vibpos_ok:
	or BYTE PTR [PSI+uF_CHAN_notectrl-2],FMUSIC_VOLUME_OR_PAN
donote_zcptr_ok:
if VOLUMEBYTE_ON
	; PROCESS VOLUME BYTE
	movzx edx,BYTE PTR [PDI+uF_NOTE_uvolume]
	; volume : EDX
	; cptr+2 : ESI
	call VolByte
endif
	; PROCESS KEY OFF
	cmp BYTE PTR [PDI],97 ; note
	jae donote_set_keyoff
	cmp BYTE PTR [PDI+uF_NOTE_effect],FMUSIC_XM_KEYOFF
	jne donote_keyoff_ok
donote_set_keyoff:
	inc BYTE PTR [PSI+uF_CHAN_keyoff-2]
donote_keyoff_ok:
	; PROCESS ENVELOPES
if VOLUMEENVELOPE_ON
	mov PCX,[PBP+donote_iptr]
	test BYTE PTR [PCX+uF_INST_VOLtype],1
	jz donote_no_voltype
	mov al,FMUSIC_VOLUME
	; cptr+2   : ESI
	; env_iptr : ECX
	; control  : AL
	call Envelope
	jmp donote_volenv_ok
donote_no_voltype:
endif
	cmp BYTE PTR [PSI+uF_CHAN_keyoff-2],0
	je donote_volenv_ok
	and DWORD PTR [PSI+uF_CHAN_envvol-2],0
donote_volenv_ok:
if PANENVELOPE_ON
	mov PCX,[PBP+donote_iptr]
	test BYTE PTR [PCX+uF_INST_PANtype],1
	je donote_no_pantype
	mov al,FMUSIC_PAN
	; cptr+2   : ESI
	; env_iptr : ECX
	; control  : AL
	call Envelope
donote_no_pantype:
endif
	; PROCESS VOLUME FADEOUT
	cmp BYTE PTR [PSI+uF_CHAN_keyoff-2],0
	mov PCX,[PBP+donote_iptr]
	je donote_fadevol_ok
	movzx eax,WORD PTR [PCX+uF_INST_VOLfade]
	sub [PSI+uF_CHAN_fadeoutvol-2],eax
	jns donote_fadevol_ok
	and DWORD PTR [PSI+uF_CHAN_fadeoutvol-2],0
donote_fadevol_ok:
	; PROCESS TICK 0 EFFECTS
	movzx eax,BYTE PTR [PDI+uF_NOTE_effect]
	dec eax ; skip FMUSIC_XM_ARPEGGIO
	movzx edx,BYTE PTR [PDI+uF_NOTE_eparam]
if EXTRAFINEPORTA_ON
	cmp al,32
else
	if TREMOR_ON
		cmp al,28
	else
		if MULTIRETRIG_ON
			cmp al,26
		else
			if PANSLIDE_ON
				cmp al,24
			else
				if SETENVELOPEPOS_ON
					cmp al,20
				else
					if GLOBALVOLSLIDE_ON
						cmp al,16
					else
						if SETGLOBALVOLUME_ON
							cmp al,15
						else
							if SETSPEED_ON
								cmp al,14
							else
								cmp al,13
							endif
						endif
					endif
				endif
			endif
		endif
	endif
endif
	ja donote_s1_brk
	test edx,edx
if UF_X64
	lea r8,[S1_TBL]
	call QWORD PTR [r8+rax*8]
else
	call DWORD PTR [eax*4+S1_TBL]
endif
donote_s1_brk:
if INSTRUMENTVIBRATO_ON
	push NWORD PTR [PBP+donote_iptr]
endif
	push NWORD PTR [PBP+donote_sptr]
	; cptr+2 : ESI
	call DoFlags
	sub PSI,-(uF_CHAN_size)
	pop PCX
	add PDI,uF_NOTE_size
	cmp PSI,PCX
	jl donote_for_channels
	pop PBX
	pop PSI
	leave
S1_r:
	ret
S1_TBL:
if PORTAUP_OR_DOWN_ON
	dnw S1_C1
	dnw S1_C1
else
	dnw S1_r
	dnw S1_r
endif
if PORTATO_ON
	dnw S1_C3
else
	dnw S1_r
endif
if VIBRATO_ON
	dnw S1_C4
else
	dnw S1_r
endif
if PORTATOVOLSLIDE_ON
	dnw S1_C5
else
	dnw S1_r
endif
if VIBRATOVOLSLIDE_ON
	dnw S1_C6
else
	dnw S1_r
endif
if TREMOLO_ON
	dnw S1_C7
else
	dnw S1_r
endif
if SETPANPOSITION_ON
	dnw S1_C8
else
	dnw S1_r
endif
if SETSAMPLEOFFSET_ON
	dnw S1_C9
else
	dnw S1_r
endif
if VOLUMESLIDE_ON
	dnw S1_C10
else
	dnw S1_r
endif
if PATTERNJUMP_ON
	dnw S1_C11
else
	dnw S1_r
endif
if SETVOLUME_ON
	dnw S1_C12
else
	dnw S1_r
endif
if PATTERNBREAK_ON
	dnw S1_C13
else
	dnw S1_r
endif
	dnw S1_C14
if EXTRAFINEPORTA_ON
	if SETSPEED_ON
		dnw S1_C15
	else
		dnw S1_r
	endif
	if SETGLOBALVOLUME_ON
		dnw S1_C16
	else
		dnw S1_r
	endif
	if GLOBALVOLSLIDE_ON
		dnw S1_C17
	else
		dnw S1_r
	endif
	dnw S1_r ; unassigned effect ordinal [18]
	dnw S1_r ; unassigned effect ordinal [19]
	dnw S1_r ; skip FMUSIC_XM_KEYOFF
	if SETENVELOPEPOS_ON
		dnw S1_C21
	else
		dnw S1_r
	endif
	dnw S1_r ; unassigned effect ordinal [22]
	dnw S1_r ; unassigned effect ordinal [23]
	dnw S1_r ; unassigned effect ordinal [24]
	if PANSLIDE_ON
		dnw S1_C25
	else
		dnw S1_r
	endif
	dnw S1_r ; unassigned effect ordinal [26]
	if MULTIRETRIG_ON
		dnw S1_C27
	else
		dnw S1_r
	endif
	dnw S1_r ; unassigned effect ordinal [28]
	if TREMOR_ON
		dnw S1_C29
	else
		dnw S1_r
	endif
	dnw S1_r ; unassigned effect ordinal [30]
	dnw S1_r ; unassigned effect ordinal [31]
	dnw S1_r ; unassigned effect ordinal [32]
	dnw S1_C33
else
	if TREMOR_ON
		if SETSPEED_ON
			dnw S1_C15
		else
			dnw S1_r
		endif
		if SETGLOBALVOLUME_ON
			dnw S1_C16
		else
			dnw S1_r
		endif
		if GLOBALVOLSLIDE_ON
			dnw S1_C17
		else
			dnw S1_r
		endif
		dnw S1_r
		dnw S1_r
		dnw S1_r
		if SETENVELOPEPOS_ON
			dnw S1_C21
		else
			dnw S1_r
		endif
		dnw S1_r
		dnw S1_r
		dnw S1_r
		if PANSLIDE_ON
			dnw S1_C25
		else
			dnw S1_r
		endif
		dnw S1_r
		if MULTIRETRIG_ON
			dnw S1_C27
		else
			dnw S1_r
		endif
		dnw S1_r
		dnw S1_C29
	else
		if MULTIRETRIG_ON
			if SETSPEED_ON
				dnw S1_C15
			else
				dnw S1_r
			endif
			if SETGLOBALVOLUME_ON
				dnw S1_C16
			else
				dnw S1_r
			endif
			if GLOBALVOLSLIDE_ON
				dnw S1_C17
			else
				dnw S1_r
			endif
			dnw S1_r
			dnw S1_r
			dnw S1_r
			if SETENVELOPEPOS_ON
				dnw S1_C21
			else
				dnw S1_r
			endif
			dnw S1_r
			dnw S1_r
			dnw S1_r
			if PANSLIDE_ON
				dnw S1_C25
			else
				dnw S1_r
			endif
			dnw S1_r
			dnw S1_C27
		else
			if PANSLIDE_ON
				if SETSPEED_ON
					dnw S1_C15
				else
					dnw S1_r
				endif
				if SETGLOBALVOLUME_ON
					dnw S1_C16
				else
					dnw S1_r
				endif
				if GLOBALVOLSLIDE_ON
					dnw S1_C17
				else
					dnw S1_r
				endif
				dnw S1_r
				dnw S1_r
				dnw S1_r
				if SETENVELOPEPOS_ON
					dnw S1_C21
				else
					dnw S1_r
				endif
				dnw S1_r
				dnw S1_r
				dnw S1_r
				dnw S1_C25
			else
				if SETENVELOPEPOS_ON
					if SETSPEED_ON
						dnw S1_C15
					else
						dnw S1_r
					endif
					if SETGLOBALVOLUME_ON
						dnw S1_C16
					else
						dnw S1_r
					endif
					if GLOBALVOLSLIDE_ON
						dnw S1_C17
					else
						dnw S1_r
					endif
					dnw S1_r
					dnw S1_r
					dnw S1_r
					dnw S1_C21
				else
					if GLOBALVOLSLIDE_ON
						if SETSPEED_ON
							dnw S1_C15
						else
							dnw S1_r
						endif
						if SETGLOBALVOLUME_ON
							dnw S1_C16
						else
							dnw S1_r
						endif
						dnw S1_C17
					else
						if SETGLOBALVOLUME_ON
							if SETSPEED_ON
								dnw S1_C15
							else
								dnw S1_r
							endif
							dnw S1_C16
						else
							if SETSPEED_ON
								dnw S1_C15
							endif
						endif
					endif
				endif
			endif
		endif
	endif
endif
if PORTAUP_OR_DOWN_ON
S1_C1:
	jz donote_xm_porta_end
	mov [PSI+uF_CHAN_portaupdown-2],dl
donote_xm_porta_end:
	ret
endif
if PORTATO_ON
S1_C3:
	jz donote_xm_portato_end
	mov [PSI+uF_CHAN_portaspeed-2],dl
donote_xm_portato_end:
if PORTATOVOLSLIDE_ON
	jmp donote_xm_portavolsl_end
else
	mov eax,[PSI+uF_CHAN_period-2]
	and BYTE PTR [PSI+uF_CHAN_notectrl-2],NOT_FMUSIC_TRIGGER_OR_FRQ
	mov [PSI+uF_CHAN_portatarget-2],eax
	ret
endif
endif
if PORTATOVOLSLIDE_ON
S1_C5:
	jz donote_xm_portavolsl_end
	mov [PSI+uF_CHAN_volslide-2],dl
donote_xm_portavolsl_end:
	mov eax,[PSI+uF_CHAN_period-2]
	and BYTE PTR [PSI+uF_CHAN_notectrl-2],NOT_FMUSIC_TRIGGER_OR_FRQ
	mov [PSI+uF_CHAN_portatarget-2],eax
	ret
endif
if VIBRATO_ON
S1_C4:
	shr edx,4
	jz donote_vib_x_ok
	mov [PSI+uF_CHAN_vibspeed-2],dl
donote_vib_x_ok:
	test ebx,ebx
	jz donote_vib_y_ok
	mov [PSI+uF_CHAN_vibdepth-2],bl
donote_vib_y_ok:
if VIBRATOVOLSLIDE_ON
	xor eax,eax
else
	; cptr+2 : ESI
	jmp Vibrato
endif
endif
if VIBRATOVOLSLIDE_ON
S1_C6:
	jz donote_xm_vibvolsl_end
	mov [PSI+uF_CHAN_volslide-2],dl
donote_xm_vibvolsl_end:
	; cptr+2 : ESI
	jmp Vibrato
endif
if TREMOLO_ON
S1_C7:
	shr edx,4
	jz donote_trem_x_ok
	mov [PSI+uF_CHAN_tremolospeed-2],dl
donote_trem_x_ok:
	test ebx,ebx
	jz donote_trem_y_ok
	mov [PSI+uF_CHAN_tremolodepth-2],bl
donote_trem_y_ok:
	ret
endif
if SETPANPOSITION_ON
if PANSLIDE_ON
else
	S1_C8:
		mov [PSI+uF_CHAN_pan-2],edx
		or BYTE PTR [PSI+uF_CHAN_notectrl-2],FMUSIC_PAN
		ret
	endif
endif
if SETSAMPLEOFFSET_ON
S1_C9:
	shl edx,8
	jz donote_soffset_ok
	mov [PSI+uF_CHAN_sampleoffset-2],edx
donote_soffset_ok:
	mov PCX,[PBP+donote_sptr]
	mov edx,[PCX+uF_SAMP_loopstart]
	add edx,[PCX+uF_SAMP_looplen]
	mov eax,[PSI+uF_CHAN_sampleoffset-2]
	cmp eax,edx
	mov PCX,[PSI+uF_CHAN_cptr-2]
	jb donote_set_offset
	xor eax,eax
	and BYTE PTR [PSI+uF_CHAN_notectrl-2],NOT_FMUSIC_TRIGGER
	mov [PCX+FSOUND_CHANNEL_mixpos],eax
	mov [PCX+FSOUND_CHANNEL_mixposlo],eax
donote_set_offset:
	mov [PCX+FSOUND_CHANNEL_fsampleoffset],eax
	ret
endif
if VOLUMESLIDE_ON
S1_C10:
	jz donote_volslide_ok
	mov [PSI+uF_CHAN_volslide-2],dl
donote_volslide_ok:
	ret
endif
if PATTERNJUMP_ON
S1_C11:
	mov PAX,[PBP+var_mod]
	and DWORD PTR [PAX+uF_MOD_nextrow-36],0
	mov [PAX+uF_MOD_nextorder-36],edx
if PATTERNBREAK_ON
	inc BYTE PTR [PBP+donote_jumpflag]
donote_set_nextord:
endif
	movzx ecx,WORD PTR [PAX+uF_MOD_numorders-36]
	cmp [PAX+uF_MOD_nextorder-36],ecx
	jl donote_nextorder_ok
	and DWORD PTR [PAX+uF_MOD_nextorder-36],0
donote_nextorder_ok:
	ret
endif
if PATTERNBREAK_ON
S1_C13:
	shr edx,4
	lea edx,[PDX+PDX*4]
	lea ecx,[PBX+PDX*2] ; paramx*10+paramy
	mov PAX,[PBP+var_mod]
	mov [PAX+uF_MOD_nextrow-36],ecx
if PATTERNJUMP_ON
	cmp BYTE PTR [PBP+donote_jumpflag],0
	jne donote_nextorder_ok
endif
	mov ecx,[PAX+uF_MOD_order-36]
	inc ecx
	mov [PAX+uF_MOD_nextorder-36],ecx
if PATTERNJUMP_ON
	jmp donote_set_nextord
else
	movzx ecx,WORD PTR [PAX+uF_MOD_numorders-36]
	cmp [PAX+uF_MOD_nextorder-36],ecx
	jl donote_jump_pat
	and DWORD PTR [PAX+uF_MOD_nextorder-36],0
donote_jump_pat:
	ret
endif
endif
if SETSPEED_ON
S1_C15:
	cmp dl,20h
	mov ecx,edx
	jae donote_setbpm
	mov PAX,[PBP+var_mod]
	mov [PAX+uF_MOD_speed-36],ecx
	ret
donote_setbpm:
	; bpm : ECX
	jmp SetBPM
endif
if GLOBALVOLSLIDE_ON
S1_C17:
	jz donote_globalvsl_ok
	mov PCX,[PBP+var_mod]
	mov [PCX+uF_MOD_globalvsl-36],dl
donote_globalvsl_ok:
	ret
endif
if SETENVELOPEPOS_ON
S1_C21:
	test BYTE PTR [PCX+uF_INST_VOLtype],1
	je donote_envelope_r
	lea PBX,[PCX+uF_INST_VOLPoints+4]
	; Search and reinterpolate new envelope position
	movzx ecx,BYTE PTR [PCX+uF_INST_VOLnumpoints]
	xor eax,eax
	cmp dx,[PBX]
	jbe donote_env_endwhile
donote_envwhile:
	cmp eax,ecx ; if(currpos == iptr->VOLnumpoints) break
	je donote_env_endwhile
	inc eax
	cmp dx,[PBX+PAX*4] ; if(current->eparam > iptr->VOLPoints[(currpos+1)<<1]) break
	ja donote_envwhile
donote_env_endwhile:
	mov [PSI+uF_CHAN_envvolpos-2],eax
	; if it is at the last position, abort the envelope and continue last volume
	dec ecx
	cmp eax,ecx
	setnl [PSI+uF_CHAN_envvolstopped-2]
	jl donote_env_continue
	movzx eax,WORD PTR [PBX+PCX*4-2]
	mov [PSI+uF_CHAN_envvol-2],eax ; cptr->envvol = iptr->VOLPoints[((iptr->VOLnumpoints-1)<<1)+1]
donote_envelope_r:
	ret
donote_env_continue:
	mov [PSI+uF_CHAN_envvoltick-2],edx
	mov ecx,[PBX+PAX*4-4] ; get tick at this point + VOL at this point
	mov edx,ecx
	movzx ecx,cx
	mov [PBP+donote_currtick],ecx
	mov ecx,[PBX+PAX*4] ; get tick at next point + VOL at next point
	mov eax,ecx
	movzx ecx,cx
	xor dx,dx
	; interpolate 2 points to find delta step
	sub ecx,[PBP+donote_currtick]
	push PDX
	jz donote_no_tickdiff
	xor ax,ax
	sub eax,edx
	cdq
	idiv ecx
	xchg eax,ecx
donote_no_tickdiff:
	mov [PSI+uF_CHAN_envvoldelta-2],ecx
	mov eax,[PSI+uF_CHAN_envvoltick-2]
	sub eax,[PBP+donote_currtick]
	imul ecx
	pop PDX
	add eax,edx
	mov [PSI+uF_CHAN_envvolfrac-2],eax
	shr eax,16
	mov [PSI+uF_CHAN_envvol-2],eax
	inc DWORD PTR [PSI+uF_CHAN_envvolpos-2]
	ret
endif
if PANSLIDE_ON
S1_C25:
	jz donote_panslide_ok
	mov [PSI+uF_CHAN_panslide-2],dl
	or BYTE PTR [PSI+uF_CHAN_notectrl-2],FMUSIC_PAN
donote_panslide_ok:
	ret
endif
if MULTIRETRIG_ON
S1_C27:
	jz donote_multiretrig_ok
	shr edx,4
	mov dh,bl
	mov [PSI+uF_CHAN_retrigx-2],dx
donote_multiretrig_ok:
	ret
endif
if TREMOR_ON
S1_C29:
	jz donote_do_tremor
	shr edx,4
	mov dh,bl
	mov [PSI+uF_CHAN_tremoron-2],dx
donote_do_tremor:
	; cptr : ESI
	jmp Tremor
endif
if EXTRAFINEPORTA_ON
S1_C33:
	shr edx,4
	dec edx
	jnz donote_paramx_n1
	test ebx,ebx
	jz donote_paramy_z1
	mov [PSI+uF_CHAN_xtraportaup-2],bl
donote_paramy_z1:
	movzx eax,BYTE PTR [PSI+uF_CHAN_xtraportaup-2]
	sub [PSI+uF_CHAN_freq-2],eax
donote_paramx_n1:
	dec edx
	jnz donote_paramx_n2
	test ebx,ebx
	jz donote_paramy_z2
	mov [PSI+uF_CHAN_xtraportadown-2],bl
donote_paramy_z2:
	movzx eax,BYTE PTR [PSI+uF_CHAN_xtraportadown-2]
	add [PSI+uF_CHAN_freq-2],eax
donote_paramx_n2:
endif
S2_r:
	ret
S1_C14:
	shr edx,4
	dec edx ; skip FMUSIC_XM_SETFILTER
if FINEPORTAUP_ON
else
	dec edx
endif
if PATTERNDELAY_ON
	cmp dl,13
else
	if NOTEDELAY_ON
		cmp dl,12
	else
		if FINEVOLUMESLIDE_ON
			cmp dl,10
		else
			if SETPANPOSITION16_ON
				cmp dl,7
			else
				if SETTREMOLOWAVE_ON
					cmp dl,6
				else
					if PATTERNLOOP_ON
						cmp dl,5
					else
						cmp dl,4
					endif
				endif
			endif
		endif
	endif
endif
if FINEPORTAUP_ON
	ja S2_r
else
	jae S2_r
endif
donote_do_special:
	test ebx,ebx
if UF_X64
	lea r8,[S2_TBL]
	jmp QWORD PTR [r8+rdx*8]
else
	jmp DWORD PTR [edx*4+S2_TBL]
endif
S2_TBL:
if FINEPORTAUP_ON
	dnw S2_C1
endif
if FINEPORTADOWN_ON
	dnw S2_C2
else
	dnw S2_r
endif
	dnw S2_r ; skip FMUSIC_XM_SETGLISSANDO
if SETVIBRATOWAVE_ON
	dnw S2_C4
else
	dnw S2_r
endif
if SETFINETUNE_ON
	dnw S2_C5
else
	dnw S2_r
endif
if PATTERNDELAY_ON
	if PATTERNLOOP_ON
		dnw S2_C6
	else
		dnw S2_r
	endif
	if SETTREMOLOWAVE_ON
		dnw S2_C7
	else
		dnw S2_r
	endif
	if SETPANPOSITION16_ON
		dnw S2_C8
	else
		dnw S2_r
	endif
	dnw S2_r ; skip FMUSIC_XM_RETRIG
	if FINEVOLUMESLIDE_ON
		dnw S2_C10
		dnw S2_C11
	else
		dnw S2_r
		dnw S2_r
	endif
	dnw S2_r ; skip FMUSIC_XM_NOTECUT
	if NOTEDELAY_ON
		dnw S2_C13
	else
		dnw S2_r
	endif
	dnw S2_C14
else
	if NOTEDELAY_ON
		if PATTERNLOOP_ON
			dnw S2_C6
		else
			dnw S2_r
		endif
		if SETTREMOLOWAVE_ON
			dnw S2_C7
		else
			dnw S2_r
		endif
		if SETPANPOSITION16_ON
			dnw S2_C8
		else
			dnw S2_r
		endif
		dnw S2_r ; skip FMUSIC_XM_RETRIG
		if FINEVOLUMESLIDE_ON
			dnw S2_C10
			dnw S2_C11
		else
			dnw S2_r
			dnw S2_r
		endif
		dnw S2_r
		dnw S2_C13
	else
		if FINEVOLUMESLIDE_ON
			if PATTERNLOOP_ON
				dnw S2_C6
			else
				dnw S2_r
			endif
			if SETTREMOLOWAVE_ON
				dnw S2_C7
			else
				dnw S2_r
			endif
			if SETPANPOSITION16_ON
				dnw S2_C8
			else
				dnw S2_r
			endif
			dnw S2_r
			dnw S2_C10
			dnw S2_C11
		else
			if SETPANPOSITION16_ON
				if PATTERNLOOP_ON
					dnw S2_C6
				else
					dnw S2_r
				endif
				if SETTREMOLOWAVE_ON
					dnw S2_C7
				else
					dnw S2_r
				endif
				dnw S2_C8
			else
				if SETTREMOLOWAVE_ON
					if PATTERNLOOP_ON
						dnw S2_C6
					else
						dnw S2_r
					endif
					dnw S2_C7
				else
					if PATTERNLOOP_ON
						dnw S2_C6
					endif
				endif
			endif
		endif
	endif
endif
if FINEPORTAUP_ON
S2_C1:
	jz donote_finepup_ok
	mov [PSI+uF_CHAN_fineportaup-2],bl
donote_finepup_ok:
	movzx eax,BYTE PTR [PSI+uF_CHAN_fineportaup-2]
	shl eax,2
	sub [PSI+uF_CHAN_freq-2],eax
	ret
endif
if FINEPORTADOWN_ON
S2_C2:
	jz donote_finepdown_ok
	mov [PSI+uF_CHAN_fineportadown-2],bl
donote_finepdown_ok:
	movzx eax,BYTE PTR [PSI+uF_CHAN_fineportadown-2]
	shl eax,2
	add [PSI+uF_CHAN_freq-2],eax
	ret
endif
if SETVIBRATOWAVE_ON
S2_C4:
	and BYTE PTR [PSI+uF_CHAN_wavecontrol-2],0F0h
	or [PSI+uF_CHAN_wavecontrol-2],bl
	ret
endif
if SETFINETUNE_ON
S2_C5:
	mov PAX,[PBP+donote_sptr]
	mov [PAX+uF_SAMP_finetune],bl
	ret
endif
if PATTERNLOOP_ON
S2_C6:
	jnz donote_not_paramy
	mov PAX,[PBP+var_mod]
	mov eax,[PAX+uF_MOD_row-36]
	mov [PSI+uF_CHAN_patlooprow-2],eax
	ret
donote_not_paramy:
	mov cl,[PSI+uF_CHAN_patloopno-2]
	dec cl
	jns donote_patloopno_ok
	mov ecx,ebx
donote_patloopno_ok:
	mov [PSI+uF_CHAN_patloopno-2],cl
	jz donote_patloopno_end
	mov eax,[PSI+uF_CHAN_patlooprow-2]
	mov PCX,[PBP+var_mod]
	mov [PCX+uF_MOD_nextrow-36],eax
donote_patloopno_end:
	ret
endif
if SETTREMOLOWAVE_ON
S2_C7:
	and BYTE PTR [PSI+uF_CHAN_wavecontrol-2],0Fh
	shl ebx,4
	or [PSI+uF_CHAN_wavecontrol-2],bl
	ret
endif
if SETPANPOSITION16_ON
S2_C8:
	shl ebx,4
	mov [PSI+uF_CHAN_pan-2],ebx
	or BYTE PTR [PSI+uF_CHAN_notectrl-2],FMUSIC_PAN
	ret
endif
if FINEVOLUMESLIDE_ON
S2_C10:
	neg ebx
S2_C11:
	jz donote_finevols_ok
	mov [PSI+uF_CHAN_finevslup-2],bl
donote_finevols_ok:
	movsx eax,BYTE PTR [PSI+uF_CHAN_finevslup-2]
	sub [PSI+uF_CHAN_volume-2],eax
	ret
endif
if NOTEDELAY_ON
S2_C13:
	mov eax,[PBP+donote_oldfreq]
	mov edx,[PBP+donote_currtick]
	mov [PSI+uF_CHAN_freq-2],eax
	mov eax,[PBP+donote_oldpan]
	mov [PSI+uF_CHAN_pan-2],eax
	mov BYTE PTR [PSI+uF_CHAN_notectrl-2],0
if SETVOLUME_ON
else
	mov [PSI+uF_CHAN_volume-2],edx
	ret
endif
endif
if SETVOLUME_ON
S1_C12:
	mov [PSI+uF_CHAN_volume-2],edx
	ret
endif
if PATTERNDELAY_ON
S2_C14:
	mov PCX,[PBP+var_mod]
	imul ebx,[PCX+uF_MOD_speed-36]
	mov [PCX+uF_MOD_patterndelay-36],ebx
	ret
endif

DoEffs:
; mod+36 = ESI
; var_mod     EQU -4
doeff_current EQU (-8-UF_X64*8)
	; Point our note pointer to the correct pattern buffer, and to the
	; correct offset in this buffer indicated by row and number of channels
	mov eax,[PSI+uF_MOD_order-36]
	push PBP
	mov bl,[PAX+PSI+uF_MOD_orderlist-36]
	mov eax,[PSI+uF_MOD_row-36]
	mul DWORD PTR [PSI+uF_MOD_numchannels-36]
if UF_X64
	shl ebx,4 ; x uF_PAT_size
	mov rdx,[rcx+rbx+uF_PAT_data]
else
	mov edx,[ecx+ebx*uF_PAT_size+uF_PAT_data]
endif
	lea eax,[PAX+PAX*4] ; x SIZE FMUSIC_NOTE
	test PDX,PDX
	mov PBP,PSP
	jz doeff_R
	; mod->pattern[mod->orderlist[mod->order]].data+(mod->row*mod->numchannels)
	add PAX,PDX
	push PSI ; -> var_mod
	push PAX ; -> doeff_current
	mov eax,[PSI+uF_MOD_numchannels-36]
	shl eax,uF_CHAN_shift ; x uF_CHAN_size
	push PSI
	mov PSI,[PSI+uF_MOD_uFMOD_Ch-36]
	inc PSI
	inc PSI
	add PAX,PSI
doeff_for_channels:
	push PAX
	movzx edi,BYTE PTR [PSI+uF_CHAN_inst-2]
	mov PDX,[PBP+var_mod]
	imul edi,uF_INST_size
	movzx eax,BYTE PTR [PSI+uF_CHAN_note-2]
	add PDI,[PDX+uF_MOD_instrument-36]
	cdq
	mov al,[PAX+PDI+uF_INST_keymap]
	cmp al,16
	jae doeff_set_sptr
	mov PDX,[PDI+PAX*PSZ+uF_INST_sample]
doeff_set_sptr:
	test PDX,PDX
	jnz doeff_valid_sptr
if UF_X64
	lea rdx,[DummySamp]
else
	mov edx,OFFSET DummySamp
endif
doeff_valid_sptr:
	xor ebx,ebx
if INSTRUMENTVIBRATO_ON
	push PDI ; iptr
endif
	push PDX ; sptr
	mov [PSI+uF_CHAN_voldelta-2],ebx
	mov [PSI+uF_CHAN_freqdelta-2],ebx
	mov [PSI+uF_CHAN_notectrl-2],bl
	; PROCESS ENVELOPES
if VOLUMEENVELOPE_ON
	test BYTE PTR [PDI+uF_INST_VOLtype],1
	je doeff_no_voltype
	mov al,FMUSIC_VOLUME
	mov PCX,PDI
	; cptr+2   : ESI
	; env_iptr : ECX
	; control  : AL
	call Envelope
doeff_no_voltype:
endif
if PANENVELOPE_ON
	test BYTE PTR [PDI+uF_INST_PANtype],1
	je doeff_no_pantype
	mov al,FMUSIC_PAN
	mov PCX,PDI
	; cptr+2   : ESI
	; env_iptr : ECX
	; control  : AL
	call Envelope
doeff_no_pantype:
endif
	; PROCESS VOLUME FADEOUT
	cmp [PSI+uF_CHAN_keyoff-2],bl
	je doeff_fadevol_ok
	movzx eax,WORD PTR [PDI+uF_INST_VOLfade]
	sub [PSI+uF_CHAN_fadeoutvol-2],eax
	jns doeff_fadevol_ns
	mov [PSI+uF_CHAN_fadeoutvol-2],ebx
doeff_fadevol_ns:
	or BYTE PTR [PSI+uF_CHAN_notectrl-2],FMUSIC_VOLUME
doeff_fadevol_ok:
if VOLUMEBYTE_ON
	mov PAX,[PBP+doeff_current]
	movzx eax,BYTE PTR [PAX+uF_NOTE_uvolume]
	mov ecx,eax
	shr eax,4
	and cl,0Fh
	sub al,6
	jz doeff_case_vol6
	dec eax
	jz doeff_case_vol7
if VIBRATO_ON
	sub al,4
	jz doeff_case_volB
	dec eax
	dec eax
else
	sub al,6
endif
	jz doeff_case_volD
	dec eax
if PORTATO_ON
	jz doeff_case_volE
	dec eax
	jnz doeff_volbyte_end
	; cptr+2 : ESI
	call Portamento
	jmp doeff_volbyte_end
else
	jnz doeff_volbyte_end
endif
doeff_case_volE:
	neg ecx
doeff_case_volD:
	sub [PSI+uF_CHAN_pan-2],ecx
	or BYTE PTR [PSI+uF_CHAN_notectrl-2],FMUSIC_PAN
	jmp doeff_volbyte_end
if VIBRATO_ON
doeff_case_volB:
	mov [PSI+uF_CHAN_vibdepth-2],cl
	; cptr+2 : ESI
	call Vibrato
	jmp doeff_volbyte_end
endif
doeff_case_vol6:
	neg ecx
doeff_case_vol7:
	add [PSI+uF_CHAN_volume-2],ecx
	or BYTE PTR [PSI+uF_CHAN_notectrl-2],FMUSIC_VOLUME
doeff_volbyte_end:
endif ; VOLUMEBYTE_ON
	mov PDX,[PBP+doeff_current]
	movzx ebx,BYTE PTR [PDX+uF_NOTE_eparam]
	mov ecx,ebx
	and ebx,0Fh ; grab the effect parameter y
	movzx eax,BYTE PTR [PDX+uF_NOTE_effect]
	shr cl,4    ; grab the effect parameter x
if ARPEGGIO_ON
else
	dec eax
endif
if TREMOR_ON
	cmp al,29
else
	if MULTIRETRIG_ON
		cmp al,27
	else
		if PANSLIDE_ON
			cmp al,25
		else
			if GLOBALVOLSLIDE_ON
				cmp al,17
			else
				if RETRIG_ON
					cmp al,14
				else
					if NOTECUT_ON
						cmp al,14
					else
						if NOTEDELAY_ON
							cmp al,14
						else
							cmp al,10
						endif
					endif
				endif
			endif
		endif
	endif
endif
if ARPEGGIO_ON
	ja doeff_s3_brk
else
	jae doeff_s3_brk
endif
if UF_X64
	lea r8,[S3_TBL]
	call QWORD PTR [r8+rax*8]
else
	call DWORD PTR [eax*4+S3_TBL]
endif
doeff_s3_brk:
	; cptr+2 : ESI
	call DoFlags
	sub PSI,-(uF_CHAN_size)
	pop PAX
	add NWORD PTR [PBP+doeff_current],uF_NOTE_size
	cmp PSI,PAX
	jl doeff_for_channels
	pop PSI
doeff_R:
	leave
S3_r:
	ret
S3_TBL:
if ARPEGGIO_ON
	dnw S3_C0
endif
if PORTAUP_ON
	dnw S3_C1
else
	dnw S3_r
endif
if PORTADOWN_ON
	dnw S3_C2
else
	dnw S3_r
endif
if PORTATO_ON
	; cptr+2 : ESI
	dnw Portamento
else
	dnw S3_r
endif
if VIBRATO_ON
	; cptr+2 : ESI
	dnw Vibrato
else
	dnw S3_r
endif
if PORTATOVOLSLIDE_ON
	dnw S3_C5
else
	dnw S3_r
endif
if VIBRATOVOLSLIDE_ON
	dnw S3_C6
else
	dnw S3_r
endif
if TREMOLO_ON
	; cptr+2 : ESI
	dnw Tremolo
else
	dnw S3_r
endif
	dnw S3_r ; skip FMUSIC_XM_SETPANPOSITION
	dnw S3_r ; skip FMUSIC_XM_SETSAMPLEOFFSET
if VOLUMESLIDE_ON
	dnw S3_C10
else
	dnw S3_r
endif
if TREMOR_ON
	dnw S3_r ; skip FMUSIC_XM_PATTERNJUMP
	dnw S3_r ; slip FMUSIC_XM_SETVOLUME
	dnw S3_r ; skip FMUSIC_XM_PATTERNBREAK
	dnw S3_C14
	dnw S3_r ; skip FMUSIC_XM_SETSPEED
	dnw S3_r ; skip FMUSIC_XM_SETGLOBALVOLUME
	if GLOBALVOLSLIDE_ON
		dnw S3_C17
	else
		dnw S3_r
	endif
	dnw S3_r ; unassigned effect ordinal [18]
	dnw S3_r ; unassigned effect ordinal [19]
	dnw S3_r ; skip FMUSIC_XM_KEYOFF
	dnw S3_r ; skip FMUSIC_XM_SETENVELOPEPOS
	dnw S3_r ; unassigned effect ordinal [22]
	dnw S3_r ; unassigned effect ordinal [23]
	dnw S3_r ; unassigned effect ordinal [24]
	if PANSLIDE_ON
		dnw S3_C25
	else
		dnw S3_r
	endif
	dnw S3_r ; unassigned effect ordinal [26]
	if MULTIRETRIG_ON
		dnw S3_C27
	else
		dnw S3_r
	endif
	dnw S3_r ; unassigned effect ordinal [28]
	; case FMUSIC_XM_TREMOR
	; cptr : ESI
	dnw Tremor
else
	if MULTIRETRIG_ON
		dnw S3_r
		dnw S3_r
		dnw S3_r
		dnw S3_C14
		dnw S3_r
		dnw S3_r
		if GLOBALVOLSLIDE_ON
			dnw S3_C17
		else
			dnw S3_r
		endif
		dnw S3_r
		dnw S3_r
		dnw S3_r
		dnw S3_r
		dnw S3_r
		dnw S3_r
		dnw S3_r
		if PANSLIDE_ON
			dnw S3_C25
		else
			dnw S3_r
		endif
		dnw S3_r
		dnw S3_C27
	else
		if PANSLIDE_ON
			dnw S3_r
			dnw S3_r
			dnw S3_r
			dnw S3_C14
			dnw S3_r
			dnw S3_r
			if GLOBALVOLSLIDE_ON
				dnw S3_C17
			else
				dnw S3_r
			endif
			dnw S3_r
			dnw S3_r
			dnw S3_r
			dnw S3_r
			dnw S3_r
			dnw S3_r
			dnw S3_r
			dnw S3_C25
		else
			if GLOBALVOLSLIDE_ON
				dnw S3_r
				dnw S3_r
				dnw S3_r
				dnw S3_C14
				dnw S3_r
				dnw S3_r
				dnw S3_C17
			else
				if RETRIG_ON
					dnw S3_r
					dnw S3_r
					dnw S3_r
					dnw S3_C14
				else
					if NOTECUT_ON
						dnw S3_r
						dnw S3_r
						dnw S3_r
						dnw S3_C14
					else
						if NOTEDELAY_ON
							dnw S3_r
							dnw S3_r
							dnw S3_r
							dnw S3_C14
						endif
					endif
				endif
			endif
		endif

	endif
endif
if VIBRATOVOLSLIDE_ON
S3_C6:
	; cptr+2 : ESI
	call Vibrato
if VOLUMESLIDE_ON
	if PORTATOVOLSLIDE_ON
		jmp S3_C10
	endif
else
	mov cl,[PSI+uF_CHAN_volslide-2]
	mov eax,ecx
	and eax,0Fh
	shr ecx,4
	jz doeff_volslide_ok
	; Slide up takes precedence over down
	xchg eax,ecx
	neg eax
doeff_volslide_ok:
	sub [PSI+uF_CHAN_volume-2],eax
	or BYTE PTR [PSI+uF_CHAN_notectrl-2],FMUSIC_VOLUME
	ret
endif
endif
if PORTATOVOLSLIDE_ON
S3_C5:
	; cptr+2 : ESI
	call Portamento
if VOLUMESLIDE_ON
	xor ecx,ecx
else
	movzx ecx,BYTE PTR [PSI+uF_CHAN_volslide-2]
	mov eax,ecx
	and eax,0Fh
	shr ecx,4
	jz doeff_volslide_ok
	; Slide up takes precedence over down
	xchg eax,ecx
	neg eax
doeff_volslide_ok:
	sub [PSI+uF_CHAN_volume-2],eax
	or BYTE PTR [PSI+uF_CHAN_notectrl-2],FMUSIC_VOLUME
	ret
endif
endif
if VOLUMESLIDE_ON
S3_C10:
	mov cl,[PSI+uF_CHAN_volslide-2]
	mov eax,ecx
	and eax,0Fh
	shr ecx,4
	jz doeff_volslide_ok
	; Slide up takes precedence over down
	xchg eax,ecx
	neg eax
doeff_volslide_ok:
	sub [PSI+uF_CHAN_volume-2],eax
	or BYTE PTR [PSI+uF_CHAN_notectrl-2],FMUSIC_VOLUME
	ret
endif
if PORTADOWN_ON
S3_C2:
	mov al,[PSI+uF_CHAN_portaupdown-2]
DoFreqSlide:
	mov ecx,[PSI+uF_CHAN_freq-2]
	lea ecx,[PCX+PAX*4]
	cmp ecx,1
	jge DoFreqSlide_ok
	push 1
	pop PCX
DoFreqSlide_ok:
	mov [PSI+uF_CHAN_freq-2],ecx
	and DWORD PTR [PSI+uF_CHAN_freqdelta-2],0
	or BYTE PTR [PSI+uF_CHAN_notectrl-2],FMUSIC_FREQ
	ret
endif
if PORTAUP_ON
S3_C1:
	mov al,[PSI+uF_CHAN_portaupdown-2]
if PORTADOWN_ON
	neg eax
	jmp DoFreqSlide
else
	shl eax,2
	mov ecx,[PSI+uF_CHAN_freq-2]
	sub ecx,eax
	cmp ecx,1
	jge DoFreqSlide_ok
	push 1
	pop PCX
DoFreqSlide_ok:
	mov [PSI+uF_CHAN_freq-2],ecx
	and DWORD PTR [PSI+uF_CHAN_freqdelta-2],0
	or BYTE PTR [PSI+uF_CHAN_notectrl-2],FMUSIC_FREQ
	ret
endif
endif
if ARPEGGIO_ON
S3_C0:
	cmp [PDX+uF_NOTE_eparam],ch
	jbe doeff_arpeggio_ok
	mov PAX,[PBP+var_mod]
	mov eax,[PAX+uF_MOD_tick-36]
	push 3
	cdq
	pop PDI
	idiv edi
	dec edx
	jz doeff_arpeg_c1
	dec edx
	jne doeffs_enable_freq
	mov ecx,ebx
doeff_arpeg_c1:
	mov PAX,[PBP+var_mod]
	test BYTE PTR [PAX+uF_MOD_flags-36],1
	je doeffs_flagsn1
doeffs_arpeggio_freqd:
	shl ecx,6
	mov [PSI+uF_CHAN_freqdelta-2],ecx
if AMIGAPERIODS_ON
	jmp doeffs_enable_freq
endif
doeffs_flagsn1:
if AMIGAPERIODS_ON
	movzx eax,BYTE PTR [PSI+uF_CHAN_realnote-2]
	mov edi,eax
	add eax,ecx     ; note   : EAX
	mov PCX,[PSP+PSZ] ; [sptr] : ECX
	; ESI != 0
	call AmigaPeriod
	xchg eax,edi    ; note   : EAX
	mov PCX,[PSP+PSZ] ; [sptr] : ECX
	; ESI != 0
	call AmigaPeriod
	sub edi,eax
	mov [PSI+uF_CHAN_freqdelta-2],edi
endif
doeffs_enable_freq:
	or BYTE PTR [PSI+uF_CHAN_notectrl-2],FMUSIC_FREQ
doeff_arpeggio_ok:
	ret
endif
if MULTIRETRIG_ON
S3_C27:
	mov cl,[PSI+uF_CHAN_retrigy-2]
	test ecx,ecx
	jz doeff_multiretrig_ok
	mov PAX,[PBP+var_mod]
	mov eax,[PAX+uF_MOD_tick-36]
	cdq
	idiv ecx
	test edx,edx
	jnz doeff_multiretrig_ok
	mov cl,[PSI+uF_CHAN_retrigx-2]
	and ecx,0Fh
	or BYTE PTR [PSI+uF_CHAN_notectrl-2],FMUSIC_TRIGGER
	dec ecx
	mov eax,[PSI+uF_CHAN_volume-2]
	js doeff_multiretrig_ok
	or BYTE PTR [PSI+uF_CHAN_notectrl-2],FMUSIC_VOLUME
if UF_X64
	lea r8,[S4_TBL]
	call QWORD PTR [r8+rcx*8]
else
	call DWORD PTR [ecx*4+S4_TBL]
endif
	mov [PSI+uF_CHAN_volume-2],eax
S4_C2:
	dec eax
S4_C1:
	dec eax
doeff_multiretrig_ok:
	ret
S4_C5:
	sub eax,8
S4_C4:
	sub eax,4
S4_C3:
	sub eax,4
	ret
S4_C6:
	shl eax,1
	push 3
	cdq
	pop PCX
	idiv ecx
	ret
S4_C14:
	lea eax,[PAX+PAX*2]
S4_C7:
	sar eax,1
	ret
S4_C10:
	inc eax
S4_C9:
	inc eax
	ret
S4_C13:
	add eax,8
S4_C12:
	add eax,4
S4_C11:
	add eax,4
	ret
S4_C15:
	shl eax,1
S4_r:
	ret
S4_TBL:
	dnw S4_C1
	dnw S4_C2
	dnw S4_C3
	dnw S4_C4
	dnw S4_C5
	dnw S4_C6
	dnw S4_C7
	dnw S4_r
	dnw S4_C9
	dnw S4_C10
	dnw S4_C11
	dnw S4_C12
	dnw S4_C13
	dnw S4_C14
	dnw S4_C15
endif
if PANSLIDE_ON
S3_C25:
	mov cl,[PSI+uF_CHAN_panslide-2]
	mov eax,ecx
	and eax,0Fh
	mov edx,[PSI+uF_CHAN_pan-2]
	shr ecx,4
	; Slide right takes precedence over left
	jnz doeff_pan_slide_right
	sub edx,eax
	jns doeff_panslide_ok
	mov edx,ecx
	jmp doeff_panslide_ok
doeff_pan_slide_right:
	add ecx,edx
	cdq
	dec dl ; edx = 255
	cmp ecx,edx
	jg doeff_panslide_ok
	mov edx,ecx
doeff_panslide_ok:
if SETPANPOSITION_ON
S1_C8:
endif
	mov [PSI+uF_CHAN_pan-2],edx
	or BYTE PTR [PSI+uF_CHAN_notectrl-2],FMUSIC_PAN
	ret
endif
if GLOBALVOLSLIDE_ON
S3_C17:
	mov PCX,[PBP+var_mod]
	mov edx,[PCX+uF_MOD_globalvolume-36]
	mov al,[PCX+uF_MOD_globalvsl-36]
	test al,0F0h
	; Slide up takes precedence over down
	jnz doeff_gvsl_slide_up
	and eax,0Fh
	neg eax
	jmp set_global_vol
doeff_gvsl_slide_up:
	shr eax,4
set_global_vol:
	add edx,eax
	if SETGLOBALVOLUME_ON
	else
		mov [PCX+uF_MOD_globalvolume-36],edx
		ret
	endif
endif
if SETGLOBALVOLUME_ON
S1_C16:
	mov PCX,[PBP+var_mod]
	mov [PCX+uF_MOD_globalvolume-36],edx
	ret
endif
S3_C14:
if RETRIG_ON
	cmp cl,FMUSIC_XM_RETRIG
	je doeff_do_retrig
endif
if NOTECUT_ON
	sub cl,FMUSIC_XM_NOTECUT
	jz doeff_do_notecut
endif
if NOTEDELAY_ON
	if NOTECUT_ON
		dec cl
	else
		cmp cl,FMUSIC_XM_NOTEDELAY
	endif
	jne doeff_special_r
	mov PCX,[PBP+var_mod]
	xor eax,eax
	cmp [PCX+uF_MOD_tick-36],ebx
	jne doeff_notectrl_z
	mov PDX,[PSP+PSZ]
	mov DWORD PTR [PSI+uF_CHAN_fadeoutvol-2],65536
	movzx edx,BYTE PTR [PDX+uF_SAMP_defvol]
	lea ecx,[PAX+9]
	mov [PSI+uF_CHAN_volume-2],edx
	mov edx,[PSI+uF_CHAN_envvol-2]
	lea PDI,[PSI+uF_CHAN_envvoltick-2]
	cmp ecx,edx
	sbb edx,edx
	and edx,64
	mov [PSI+uF_CHAN_envvol-2],edx
	; memset(&cptr->envvoltick,0,36)
	rep stosd
	; Retrigger tremolo and vibrato waveforms
	mov cl,[PSI+uF_CHAN_wavecontrol-2]
	cmp cl,4Fh
	jge z2_tremolopos_ok
	mov [PSI+uF_CHAN_tremolopos-2],al ; = 0
z2_tremolopos_ok:
	test cl,0Ch
	jnz z2_vibpos_ok
	mov [PSI+uF_CHAN_vibpos-2],al ; = 0
z2_vibpos_ok:
	mov eax,[PSI+uF_CHAN_period-2]
	or BYTE PTR [PSI+uF_CHAN_notectrl-2],FMUSIC_VOL_OR_FREQ_OR_TR
	mov [PSI+uF_CHAN_freq-2],eax
if VOLUMEBYTE_ON
	mov PAX,[PBP+doeff_current]
	movzx edx,BYTE PTR [PAX+uF_NOTE_uvolume]
	; volume : EDX
	; cptr   : ESI
	jmp VolByte
else
	ret
endif
doeff_notectrl_z:
	mov [PSI+uF_CHAN_notectrl-2],al
doeff_special_r:
endif
	ret
if NOTECUT_ON
doeff_do_notecut:
	mov PCX,[PBP+var_mod]
	cmp [PCX+uF_MOD_tick-36],ebx
	jne doeff_notecut_ok
	and DWORD PTR [PSI+uF_CHAN_volume-2],0
	or BYTE PTR [PSI+uF_CHAN_notectrl-2],FMUSIC_VOLUME
doeff_notecut_ok:
	ret
endif
if RETRIG_ON
doeff_do_retrig:
	test ebx,ebx
	jz doeff_retrig_ok
	mov PAX,[PBP+var_mod]
	mov eax,[PAX+uF_MOD_tick-36]
	cdq
	idiv ebx
	test edx,edx
	jne doeff_retrig_ok
	or BYTE PTR [PSI+uF_CHAN_notectrl-2],FMUSIC_VOL_OR_FREQ_OR_TR
doeff_retrig_ok:
	ret
endif

; DESCRIPTION: Process sample flags
DoFlags:
; cptr+2 - ESI
flags_iptr EQU 4*PSZ
flags_sptr EQU 3*PSZ
	mov PBX,PSI
	push PSI
	push PDI
if INSTRUMENTVIBRATO_ON
	; THIS GETS ADDED TO PREVIOUS FREQDELTAS
	mov PSI,[PSP+flags_iptr]
	xor eax,eax
	movzx edx,BYTE PTR [PSI+uF_INST_VIBtype]
	lea PDI,[PBX+uF_CHAN_ivibpos-2]
	dec edx ; switch(iptr->VIBtype)
	js ivib_case_0
	mov al,128
	jz ivib_case_1
	dec edx
	jz ivib_case_2
	; case 3 / default
	mov dl,-128 ; -128 = 384 on a 1byte scope
	sub edx,[PDI]
trim:
	movzx edx,dl
	sub eax,edx
	sar eax,1 ; delta = (128-((384-cptr->ivibpos)&0xFF))>>1 (case 3)
	          ; delta = (128-((cptr->ivibpos+128)&0xFF))>>1 (case 2)
	jmp ivib_end_switch
ivib_case_2:
	mov edx,[PDI]
	sub edx,eax
	jmp trim
ivib_case_1:
	cmp [PDI],eax
	sbb edx,edx
	and edx,eax
	lea eax,[PDX-64] ; delta = +/- 64
	jmp ivib_end_switch
ivib_case_0:
	; delta = 64 sin(2 Pi x/256)
	mov ecx,[PDI]
	mov edx,ecx
	and ecx,7Fh
	cmp ecx,65
	adc eax,-1
	xor ecx,eax
	and eax,129
	add ecx,eax
	shr edx,8
if UF_X64
	lea r8,[sin64]
	movzx eax,BYTE PTR [r8+rcx]
else
	movzx eax,BYTE PTR [OFFSET sin64+ecx]
endif
	sbb edx,edx
	xor eax,edx
	sub eax,edx
ivib_end_switch:
	movzx edx,BYTE PTR [PSI+uF_INST_iVIBdepth]
	imul edx,eax ; delta *= iptr->iVIBdepth
	movzx eax,BYTE PTR [PSI+uF_INST_VIBsweep]
	test eax,eax
	jz sweep_ok
	push PDI
	xchg eax,edi
	mov eax,[PBX+uF_CHAN_ivibsweeppos-2]
	imul edx
	idiv edi
	xchg eax,edx ; delta *= cptr->ivibsweeppos/iptr->VIBsweep
	xchg eax,edi ; iptr->VIBsweep
	pop PDI
sweep_ok:
	sar edx,6
	add [PBX+uF_CHAN_freqdelta-2],edx ; cptr->freqdelta += delta>>6
	mov edx,[PBX+uF_CHAN_ivibsweeppos-2]
	inc edx
	cmp edx,eax
	jle sweeppos_ok
	xchg eax,edx
sweeppos_ok:
	movzx eax,BYTE PTR [PSI+uF_INST_VIBrate]
	add eax,[PDI] ; cptr->ivibpos += iptr->VIBrate
	mov [PBX+uF_CHAN_ivibsweeppos-2],edx
	neg ah
	or BYTE PTR [PBX+uF_CHAN_notectrl-2],FMUSIC_FREQ
	neg ah
	sbb ah,0 ; ivibpos - 256
	mov [PDI],eax
endif ; INSTRUMENTVIBRATO_ON
	mov PSI,[PBX+uF_CHAN_cptr-2]
	test BYTE PTR [PBX+uF_CHAN_notectrl-2],FMUSIC_TRIGGER
	jz no_trig
	; TRIGGER: allocate a channel
	cmp NWORD PTR [PSI+FSOUND_CHANNEL_fsptr],0
	jz no_swap
	; Swap between channels to avoid sounds cutting each other off and causing a click
	mov ecx,esi
	sub ecx,[OFFSET _mod+uF_MOD_Channels]
	shr ecx,uF_CHAN_shift ; /FSOUND_CHANNEL_size + 1
	sbb PDI,PDI
	and PDI,-FSOUND_CHANNEL_size*2
	lea PDI,[PSI+PDI+FSOUND_CHANNEL_size]
	push PDI
	; Copy the whole channel except it's trailing data
	push FSOUND_CHANNEL_fsptr/4
	mov [PBX+uF_CHAN_cptr-2],PDI
	pop PCX
	rep movsd
	; This should cause the old channel to ramp out nicely
	mov [PSI+FSOUND_CHANNEL_actualvolume-FSOUND_CHANNEL_fsptr],ecx
	mov [PSI+FSOUND_CHANNEL_leftvolume-FSOUND_CHANNEL_fsptr],ecx
	mov [PSI+FSOUND_CHANNEL_rightvolume-FSOUND_CHANNEL_fsptr],ecx
	pop PSI
no_swap:
if UF_X64
	mov rax,[rsp+flags_sptr]
	mov [rsi+FSOUND_CHANNEL_fsptr],rax
	lea rdi,[rsi+FSOUND_CHANNEL_mixposlo]
else
	lea edi,[esi+FSOUND_CHANNEL_fsptr]
	mov eax,[esp+flags_sptr]
	stosd ; fsptr
endif
	; START THE SOUND!
	xor eax,eax
	mov edx,[PSI+FSOUND_CHANNEL_fsampleoffset]
	stosd ; mixposlo
	stosd ; ramp_leftvolume
	stosd ; ramp_rightvolume
	stosd ; ramp_count, speeddir
	mov [PSI+FSOUND_CHANNEL_fsampleoffset],eax
	mov [PSI+FSOUND_CHANNEL_mixpos],edx
no_trig:
	xor ecx,ecx
	dec cl ; ecx <- 255
	test BYTE PTR [PBX+uF_CHAN_notectrl-2],FMUSIC_VOLUME
	jz no_volume
	mov eax,[PBX+uF_CHAN_volume-2]
	add eax,[PBX+uF_CHAN_voldelta-2]
	mov edx,eax
	shl eax,8
	sub eax,edx ; eax *= 255
if GLOBALVOL_ON
	imul DWORD PTR [_mod+uF_MOD_globalvolume] ; 6 bit  (64)
else
	shl eax,6
	cdq
endif
	not edx
	and eax,edx
	cmp eax,0FF000h ; 64*255*64
	jle vol_upper_bound_ok
	mov eax,0FF000h
vol_upper_bound_ok:
	mul DWORD PTR [PBX+uF_CHAN_envvol-2]      ; 6 bit  (64)
	mul DWORD PTR [PBX+uF_CHAN_fadeoutvol-2]  ; 16 bit (65536)
	; eax:edx /= (2 * 64 * 64 * 64 * 65536)
	shr edx,3
	mov eax,[PSI+FSOUND_CHANNEL_actualpan]
	mov [PSI+FSOUND_CHANNEL_actualvolume],edx
	mov edi,edx
	imul edx
	idiv ecx
	mov [PSI+FSOUND_CHANNEL_leftvolume],eax ; leftvolume <- volume*actualpan/255
	mov eax,ecx
	sub eax,[PSI+FSOUND_CHANNEL_actualpan]
	imul edi
	idiv ecx
	mov [PSI+FSOUND_CHANNEL_rightvolume],eax
no_volume:
	test BYTE PTR [PBX+uF_CHAN_notectrl-2],FMUSIC_PAN
	jz no_pan
	mov edi,128
	mov eax,[PBX+uF_CHAN_pan-2]
	sub eax,edi
	cdq
	xor eax,edx
	sub eax,edx
	sub edi,eax
	mov eax,[PBX+uF_CHAN_envpan-2]
	sar edi,5
	sub eax,32
	imul edi
	add eax,[PBX+uF_CHAN_pan-2]
	cdq
	not edx
	and eax,edx   ; if(pan < 0) pan = 0
	mov edi,[PSI] ; actualvolume
	cmp eax,ecx
	mov edx,ecx
	xchg eax,edi
	jae pan_ae255
	imul edi
	idiv ecx
	mov edx,edi
pan_ae255:
	xchg eax,edx
	mov [PSI+FSOUND_CHANNEL_actualpan],eax
	mov [PSI+FSOUND_CHANNEL_leftvolume],edx
	not al ; 255 - pan
	imul DWORD PTR [PSI] ; actualvolume
	idiv ecx
	mov [PSI+FSOUND_CHANNEL_rightvolume],eax
no_pan:
	test BYTE PTR [PBX+uF_CHAN_notectrl-2],FMUSIC_FREQ
	jz no_freq
	mov ecx,[PBX+uF_CHAN_freq-2]
	xor edx,edx
	add ecx,[PBX+uF_CHAN_freqdelta-2]
	lea eax,[PDX+40] ; f = 40 Hz
	jle freq_bounds_ok
	test BYTE PTR [_mod+uF_MOD_flags],1
	jnz modflags_n1
	mov eax,0DA7790h
	div ecx
	xor edx,edx
	jmp freq_bounds_ok
modflags_n1:
	mov eax,4608
	sub eax,[PBX+uF_CHAN_freq-2]
	add eax,[PBX+uF_CHAN_freqdelta-2]
	push PAX
	fild DWORD PTR [PSP]
	fmul DWORD PTR [f0_0013]
	fld st0
	frndint
	fsub st1,st0
	fxch st1
	f2xm1
	fld1
	faddp st1,st0
	fscale
	fstp st1
	fmul DWORD PTR [f8363_0]
	fistp DWORD PTR [PSP]
	pop PAX ; freq = 625.271028*exp2((4608-period)/64)
freq_bounds_ok:
	mov ebx,FSOUND_MixRate
	div ebx
	mov [PSI+FSOUND_CHANNEL_speedhi],eax
	div ebx
	mov [PSI+FSOUND_CHANNEL_speedlo],eax
no_freq:
	pop PDI
	pop PSI
if INSTRUMENTVIBRATO_ON
	ret 2*PSZ
else
	ret PSZ
endif