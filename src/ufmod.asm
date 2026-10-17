; UFMOD.ASM
; ---------
; uFMOD public source code release.

; Win64 builds: functions follow the Microsoft x64 calling convention.
; Every Windows API call is made with RSP aligned to 16 and 32 bytes of shadow
; space. PlaySong, FreeSong and SW_Fill share one stack frame layout (4 pushes
; and X64_FRAME bytes), so that error paths and the XM_NOLOOP stop can jump
; into the body of FreeSong, just like the Win32 code jumps to uFMOD_FreeSong+4.
X64_FRAME EQU 72 ; shadow space + up to 5 stack args, keeps RSP aligned

if DRIVER_WINMM
	; WAVEHDR (lpData, dwUser, lpNext and reserved are pointer-sized)
	uF_WMMBlock_lpData          EQU 0
	uF_WMMBlock_dwBufferLength  EQU (4+UF_X64*4)
	uF_WMMBlock_dwBytesRecorded EQU (8+UF_X64*4)
	uF_WMMBlock_dwUser          EQU (12+UF_X64*4)
	uF_WMMBlock_dwFlags         EQU (16+UF_X64*8)
	uF_WMMBlock_dwLoops         EQU (20+UF_X64*8)
	uF_WMMBlock_lpNext          EQU (24+UF_X64*8)
	uF_WMMBlock_Reserved        EQU (28+UF_X64*12)
	uF_WMMBlock_size            EQU (32+UF_X64*16)
	pcm dd 20001h, FSOUND_MixRate, FSOUND_MixRate*4, 100004h
endif

if XM_RC_ON
	uFMOD_rc  dnw res_open, mem_read
endif
	uFMOD_mem dnw mem_open, mem_read
if XM_FILE_ON
	          dnw mem_open
	uFMOD_fs  dnw file_open, file_read, file_close
endif

if JUMP_TO_PAT_ON

	; Jump to the given pattern
	if EBASIC
		EXPORTcc DRIVER_WINMM, CuFMOD@Jump2Pattern
	else
		if PBASIC
			EXPORTcc DRIVER_DIRECTSOUND, PB_uFMOD_DSJump2Pattern
			EXPORTcc DRIVER_OPENAL,      PB_uFMOD_OALJump2Pattern
			EXPORTcc DRIVER_WINMM,       PB_uFMOD_Jump2Pattern
		else
			if VB6
				EXPORTcc DRIVER_DIRECTSOUND, ?uFMOD_Jump2Pattern@DSuF_vb@@AAGXXZ
				EXPORTcc DRIVER_WINMM,       ?uFMOD_Jump2Pattern@uF_vb@@AAGXXZ
			else
				PUBLIC uFMOD_Jump2Pattern
				uFMOD_Jump2Pattern:
			endif
		if UF_X64
			mov eax,ecx ; pat
		else
			mov eax,[esp+4]
		endif
		endif
	endif
	if UF_X64
		lea rcx,[_mod+36]
	else
		mov ecx,OFFSET _mod+36
	endif
	movzx eax,ax
	and DWORD PTR [PCX+uF_MOD_nextrow-36],0
	cmp ax,[PCX+uF_MOD_numorders-36]
	sbb edx,edx
	and eax,edx
	mov [PCX+uF_MOD_nextorder-36],eax
	if PBASIC
		ret
	else
		ret 4-UF_X64*4
	endif
endif

if VOL_CONTROL_ON

	; Set global volume [0: silence, 25: max. volume]
	vol_scale dw 1     ; -45 dB
	          dw 130   ; -24
	          dw 164   ; -23
	          dw 207   ; -22
	          dw 260   ; -21
	          dw 328   ; -20
	          dw 413   ; -19
	          dw 519   ; -18
	          dw 654   ; -17
	          dw 823   ; -16
	          dw 1036  ; -15
	          dw 1305  ; -14
	          dw 1642  ; -13
	          dw 2068  ; -12
	          dw 2603  ; -11
	          dw 3277  ; -10
	          dw 4125  ; -9
	          dw 5193  ; -8
	          dw 6538  ; -7
	          dw 8231  ; -6
	          dw 10362 ; -5
	          dw 13045 ; -4
	          dw 16423 ; -3
	          dw 20675 ; -2
	          dw 26029 ; -1
	          dw 32768 ; 0 dB
	if EBASIC
		EXPORTcc DRIVER_WINMM, CuFMOD@SetVolume
	else
		if PBASIC
			EXPORTcc DRIVER_DIRECTSOUND, PB_uFMOD_DSSetVolume
			EXPORTcc DRIVER_OPENAL,      PB_uFMOD_OALSetVolume
			EXPORTcc DRIVER_WINMM,       PB_uFMOD_SetVolume
		else
			if VB6
				EXPORTcc DRIVER_DIRECTSOUND, ?uFMOD_SetVolume@DSuF_vb@@AAGXXZ
				EXPORTcc DRIVER_WINMM,       ?uFMOD_SetVolume@uF_vb@@AAGXXZ
			else
				PUBLIC uFMOD_SetVolume
				uFMOD_SetVolume:
			endif
		if UF_X64
			mov eax,ecx ; vol
		else
			pop edx
			pop eax
		endif
		endif
	endif
		cmp eax,25
		jna get_vol_scale
		push 25
		pop PAX
	get_vol_scale:
	if UF_X64
		lea rdx,[vol_scale]
		mov ax,[rdx+rax*2]
	else
		mov ax,[vol_scale+eax*2]
	endif
		mov [ufmod_vol],eax
	if PBASIC
		ret
	else
		if UF_X64
			ret
		else
			jmp edx
		endif
	endif
endif

if PAUSE_RESUME_ON

	; Pause the currently playing song.
	if EBASIC
		EXPORTcc DRIVER_WINMM, CuFMOD@Pause
	else
		if PBASIC
			EXPORTcc DRIVER_DIRECTSOUND, PB_uFMOD_DSPause
			EXPORTcc DRIVER_OPENAL,      PB_uFMOD_OALPause
			EXPORTcc DRIVER_WINMM,       PB_uFMOD_Pause
		else
			if VB6
				EXPORTcc DRIVER_DIRECTSOUND, ?uFMOD_Pause@DSuF_vb@@AAGXXZ
				EXPORTcc DRIVER_WINMM,       ?uFMOD_Pause@uF_vb@@AAGXXZ
			else
				PUBLIC uFMOD_Pause
				uFMOD_Pause:
			endif
		endif
	endif
	mov al,1
	jmp $+4

	; Resume the currently paused song.
	if EBASIC
		EXPORTcc DRIVER_WINMM, CuFMOD@Resume
	else
		if PBASIC
			EXPORTcc DRIVER_DIRECTSOUND, PB_uFMOD_DSResume
			EXPORTcc DRIVER_OPENAL,      PB_uFMOD_OALResume
			EXPORTcc DRIVER_WINMM,       PB_uFMOD_Resume
		else
			if VB6
				EXPORTcc DRIVER_DIRECTSOUND, ?uFMOD_Resume@DSuF_vb@@AAGXXZ
				EXPORTcc DRIVER_WINMM,       ?uFMOD_Resume@uF_vb@@AAGXXZ
			else
				PUBLIC uFMOD_Resume
				uFMOD_Resume:
			endif
		endif
	endif
	xor eax,eax
	mov [ufmod_pause_],al
	ret
endif

if INFO_API_ON

; Return currently playing signal stats:
;    lo word : RMS volume in R channel
;    hi word : RMS volume in L channel
	if EBASIC
		EXPORTcc DRIVER_WINMM, CuFMOD@GetStats
	else
		if PBASIC
			EXPORTcc DRIVER_DIRECTSOUND, PB_uFMOD_DSGetStats
			EXPORTcc DRIVER_OPENAL,      PB_uFMOD_OALGetStats
			EXPORTcc DRIVER_WINMM,       PB_uFMOD_GetStats
		else
			if VB6
				EXPORTcc DRIVER_DIRECTSOUND, ?uFMOD_GetStats@DSuF_vb@@AAGXXZ
				EXPORTcc DRIVER_WINMM,       ?uFMOD_GetStats@uF_vb@@AAGXXZ
			else
				PUBLIC uFMOD_GetStats
				uFMOD_GetStats:
			endif
		endif
	endif
	push 8
	jmp $+4

; Return currently playing row and order:
;    lo word : row
;    hi word : order
	if EBASIC
		EXPORTcc DRIVER_WINMM, CuFMOD@GetRowOrder
	else
		if PBASIC
			EXPORTcc DRIVER_DIRECTSOUND, PB_uFMOD_DSGetRowOrder
			EXPORTcc DRIVER_OPENAL,      PB_uFMOD_OALGetRowOrder
			EXPORTcc DRIVER_WINMM,       PB_uFMOD_GetRowOrder
		else
			if VB6
				EXPORTcc DRIVER_DIRECTSOUND, ?uFMOD_GetRowOrder@DSuF_vb@@AAGXXZ
				EXPORTcc DRIVER_WINMM,       ?uFMOD_GetRowOrder@uF_vb@@AAGXXZ
			else
				PUBLIC uFMOD_GetRowOrder
				uFMOD_GetRowOrder:
			endif
		endif
	endif
	push 12
	pop PCX
if UF_X64
	lea rdx,[RealBlock]
else
	mov edx,OFFSET RealBlock
endif
	mov eax,[PDX]
	add PDX,PCX
	mov eax,[PDX+PAX*uF_STATS_size]
	ret

; Return the time in milliseconds since the song was started.
	if EBASIC
		EXPORTcc DRIVER_WINMM, CuFMOD@GetTime
	else
		if PBASIC
			EXPORTcc DRIVER_DIRECTSOUND, PB_uFMOD_DSGetTime
			EXPORTcc DRIVER_OPENAL,      PB_uFMOD_OALGetTime
			EXPORTcc DRIVER_WINMM,       PB_uFMOD_GetTime
		else
			if VB6
				EXPORTcc DRIVER_DIRECTSOUND, ?uFMOD_GetTime@DSuF_vb@@AAGXXZ
				EXPORTcc DRIVER_WINMM,       ?uFMOD_GetTime@uF_vb@@AAGXXZ
			else
				PUBLIC uFMOD_GetTime
				uFMOD_GetTime:
			endif
		endif
	endif
	mov eax,[time_ms]
	ret

; Return the currently playing track title, if any.
	if PBASIC
		EXPORTcc DRIVER_DIRECTSOUND, PB_uFMOD_DSGetTitle
		EXPORTcc DRIVER_OPENAL,      PB_uFMOD_OALGetTitle
		EXPORTcc DRIVER_WINMM,       PB_uFMOD_GetTitle
		push PSI
		push PDI
		push 6
		mov esi,OFFSET szTtl
		mov edi,[_PB_StringBase]
		pop PCX
		mov eax,edi
		rep movsd
		pop PDI
		pop PSI
		ret

		EXPORTcc DRIVER_DIRECTSOUND, PB_uFMOD_DSGetTitle_UNICODE
		EXPORTcc DRIVER_OPENAL,      PB_uFMOD_OALGetTitle_UNICODE
		EXPORTcc DRIVER_WINMM,       PB_uFMOD_GetTitle_UNICODE
		push PSI
		push PDI
		push 21
		mov esi,OFFSET szTtl
		mov edi,[_PB_StringBase]
		pop PCX
		xor eax,eax
		push PDI
	ucode_copy:
		lodsb
		dec ecx
		stosw
		jnz ucode_copy
		pop PAX
		pop PDI
		pop PSI
		ret
	endif

endif

; Dynamic memory allocation
alloc:
; EAX: how many bytes to allocate
if UF_X64
	push rbp
	mov rbp,rsp
	and rsp,-16
	sub rsp,32
	mov r8d,eax     ; dwBytes
	mov edx,9       ; HEAP_ZERO_MEMORY | HEAP_NO_SERIALIZE
	mov rcx,[hHeap] ; hHeap
	call HeapAlloc
	mov rsp,rbp
	pop rbp
	test rax,rax
else
	push eax
	push 9 ; HEAP_ZERO_MEMORY | HEAP_NO_SERIALIZE
	push DWORD PTR [hHeap]
	call HeapAlloc
	test eax,eax
endif
	jnz alloc_R
	pop PDX ; EIP
	pop PBX
	leave
alloc_R:
	ret

; ***********************
; * XM_MEMORY CALLBACKS *
; ***********************
mem_read:
; buf  in EAX
; size in EDX
	push PDI
	push PSI
	xchg PAX,PDI ; buf
if UF_X64
	lea rsi,[mmf]
else
	mov esi,OFFSET mmf
endif
	lodsd
	mov ecx,edx
	add edx,[PSI]
	cmp edx,eax
	jl copy
	sub eax,[PSI]
	xchg eax,ecx
copy:
	test ecx,ecx
	jle mem_read_R
	lodsd
	add PAX,[PSI]
	mov [PSI-4],edx
mem_do_copy:
	mov dl,[PAX]
	mov [PDI],dl
	inc PAX
	inc PDI
	dec ecx
	jnz mem_do_copy
mem_read_R:
	pop PSI
	pop PDI
if INFO_API_ON
	if PBASIC
	else
		if EBASIC
			EXPORTcc DRIVER_WINMM, CuFMOD@GetTitle
		else
			if VB6
				EXPORTcc DRIVER_DIRECTSOUND, ?uFMOD_GetTitle@DSuF_vb@@AAGXXZ
				EXPORTcc DRIVER_WINMM,       ?uFMOD_GetTitle@uF_vb@@AAGXXZ
			else
				PUBLIC uFMOD_GetTitle
				uFMOD_GetTitle:
			endif
		endif
		if UF_X64
			lea rax,[szTtl]
		else
			mov eax,OFFSET szTtl
		endif
	endif
endif
mem_open:
	ret

; *************************
; * XM_RESOURCE CALLBACKS *
; *************************
if XM_RC_ON
res_open:
; pszName in ESI
if UF_X64
; hModule in RDI
	push rbx
	push rbp
	mov rbp,rsp
	and rsp,-16
	sub rsp,32
	and DWORD PTR [mmf+4],0
	mov rcx,rdi ; hModule
	mov rdx,rsi ; lpName
	mov r8d,10  ; RT_RCDATA
	call FindResource
	mov rbx,rax ; hResInfo
	mov rcx,rdi
	mov rdx,rax
	call SizeofResource
	mov [mmf],eax
	mov rcx,rdi
	mov rdx,rbx
	call LoadResource
	mov [mmf+8],rax
	mov rsp,rbp
	pop rbp
	pop rbx
	ret
else
	push 10  ; RT_RCDATA
	push PSI ; pszName
	lea esi,[PBP-20] ; mmf
	and DWORD PTR [PSI+4],0
	push DWORD PTR [PSI] ; HMODULE
	call FindResource
	push PAX
	push DWORD PTR [PSI]
	push PAX
	push DWORD PTR [PSI]
	call SizeofResource
	mov [PSI],eax
	call LoadResource
	mov [esi+8],eax
	ret
endif
endif

; *********************
; * XM_FILE CALLBACKS *
; *********************
if XM_FILE_ON
file_open:
; pszName in ESI
if UF_X64
	push rbp
	mov rbp,rsp
	and rsp,-16
	sub rsp,64
	mov rcx,rsi                   ; lpFileName
	mov edx,80000000h             ; dwDesiredAccess <= GENERIC_READ
	mov r8d,1                     ; dwShareMode <= FILE_SHARE_READ
	xor r9d,r9d                   ; lpSecurityAttributes
	mov QWORD PTR [rsp+32],3      ; dwCreationDistribution <= OPEN_EXISTING
	mov QWORD PTR [rsp+40],80h    ; dwFlagsAndAttributes <= FILE_ATTRIBUTE_NORMAL
	mov QWORD PTR [rsp+48],r9     ; hTemplateFile
	call CreateFile
	mov [SW_Exit],rax
	mov DWORD PTR [mmf+8],1       ; cache_offset
	mov DWORD PTR [mmf],-1        ; maximum size
	mov rsp,rbp
	pop rbp
	ret

do_fread:
; file offset             in ECX
; buffer                  in RDI
; number of bytes to read in ESI
	push rbp
	mov rbp,rsp
	and rsp,-16
	sub rsp,48
	mov edx,ecx                   ; lDistanceToMove
	mov rcx,[SW_Exit]             ; hFile
	xor r8d,r8d                   ; lpDistanceToMoveHigh = NULL
	xor r9d,r9d                   ; dwMoveMethod         = FILE_BEGIN
	call SetFilePointer
	mov rcx,[SW_Exit]             ; hFile
	mov rdx,rdi                   ; lpBuffer
	mov r8d,esi                   ; nNumberOfBytesToRead
	lea r9,[rsp+40]               ; lpNumberOfBytesRead
	mov QWORD PTR [rsp+32],0      ; lpOverlapped         = NULL
	call ReadFile
	mov rsp,rbp
	pop rbp
	ret
else
	push 0         ; hTemplateFile
	push 80h       ; dwFlagsAndAttributes <= FILE_ATTRIBUTE_NORMAL
	push 3         ; dwCreationDistribution <= OPEN_EXISTING
	push 0         ; lpSecurityAttributes
	push 1         ; dwShareMode <= FILE_SHARE_READ
	push 80000000h ; dwDesiredAccess <= GENERIC_READ
	push PSI       ; lpFileName
	call CreateFile
	push -1
	push 1
	mov edx,OFFSET mmf
	mov [PBX+8],eax ; SW_Exit
	pop DWORD PTR [PDX+8] ; cache_offset
	pop DWORD PTR [PDX]   ; maximum size
	ret

do_fread:
; file offset             in ECX
; buffer                  in EDI
; number of bytes to read in ESI
	xor edx,edx
	mov eax,[SW_Exit]
	push PDX ; lpOverlapped         = NULL
	push PSP ; lpNumberOfBytesRead
	push PSI ; nNumberOfBytesToRead
	push PDI ; lpBuffer
	push PAX ; hFile
	push PDX ; dwMoveMethod         = FILE_BEGIN
	push PDX ; lpDistanceToMoveHigh = NULL
	push PCX ; lDistanceToMove
	push PAX ; hFile
	call SetFilePointer
	call ReadFile
	ret
endif

file_read:
; buf in EAX
; size in EDX
	push PBX
	push PSI
	push PDI
	push PBP
	xchg PAX,PDI
file_read_begin:
	test edx,edx
	jg file_read_chk_cache
file_read_done:
	pop PBP
	pop PDI
	pop PSI
	pop PBX
	ret
	; *** CHECK IN THE CACHE
file_read_chk_cache:
if UF_X64
	lea rbp,[mmf+4]
else
	mov ebp,OFFSET mmf+4
endif
	mov esi,[PBP]
	sub esi,[PBP+4] ; cache_offset
	js file_read_cache_done
	mov ecx,8192
	sub ecx,esi
	jle file_read_cache_done
if UF_X64
	lea rax,[MixBuf]
	add rsi,rax
else
	add esi,OFFSET MixBuf
endif
	sub edx,ecx
	jns file_read_do_cache
	add ecx,edx
file_read_do_cache:
	add [PBP],ecx
	rep movsb
	test edx,edx
	jle file_read_done ; data read from the cache (no need to access the FS)
file_read_cache_done:
	; *** FS BATCH READ OPERATION
	mov ecx,edx
	add ecx,[PBP]
	and ecx,0FFFFE000h
	sub ecx,[PBP]
	jle file_read_fs_done ; Too few data requested for a FS batch operation
	sub edx,ecx
	mov esi,ecx           ; number of bytes to read
	push PDX
	mov eax,[PBP]
	add [PBP],ecx
	xchg eax,ecx          ; file offset
	call do_fread
	add PDI,PSI
	pop PDX
file_read_fs_done:
	; *** UPDATE THE CACHE
	mov ecx,[PBP]
	push PDI
	and ecx,0FFFFE000h    ; file offset
	push PDX
	mov [PBP+4],ecx       ; cache_offset
	mov esi,8192          ; number of bytes to read
if UF_X64
	lea rdi,[MixBuf]      ; buffer
else
	mov edi,OFFSET MixBuf ; buffer
endif
	call do_fread
	pop PDX
	pop PDI
	jmp file_read_begin

file_close:
if UF_X64
	push rbp
	mov rbp,rsp
	and rsp,-16
	sub rsp,32
	mov rcx,[SW_Exit] ; hObject
	call CloseHandle
	mov rsp,rbp
	pop rbp
	ret
else
	push DWORD PTR [ebx+8] ; hObject <- SW_Exit
	call CloseHandle
endif

endif

uFMOD_lseek:
; pos  in EAX
; org  in ECX
; !org in Z
if UF_X64
	lea rdx,[mmf+4]
else
	mov edx,OFFSET mmf+4
endif
	jz mem_ok
	add eax,[PDX]
mem_ok:
if CHK4VALIDITY
	test eax,eax
	js mem_seek_R
	cmp eax,[PDX-4]
	ja mem_seek_R
endif
	mov [PDX],eax
mem_seek_R:
	ret

; Starts playing a song.
if EBASIC
	EXPORTcc DRIVER_WINMM, CuFMOD@PlaySong
else
	if PBASIC
		EXPORTcc DRIVER_DIRECTSOUND, PB_uFMOD_DSPlaySong
		EXPORTcc DRIVER_OPENAL,      PB_uFMOD_OALPlaySong
		EXPORTcc DRIVER_WINMM,       PB_uFMOD_PlaySong
	else
		if VB6
			EXPORTcc DRIVER_DIRECTSOUND, ?uFMOD_DSPlaySong@DSuF_vb@@AAGXXZ
			EXPORTcc DRIVER_WINMM,       ?uFMOD_PlaySong@uF_vb@@AAGXXZ
		else
			EXPORTcc DRIVER_DIRECTSOUND, uFMOD_DSPlaySong
			EXPORTcc DRIVER_OPENAL,      uFMOD_OALPlaySong
			EXPORTcc DRIVER_WINMM,       uFMOD_PlaySong
		endif
	endif
endif
if UF_X64
; RCX: lpXM, RDX: param, R8D: fdwSong, R9: IDirectSoundBuffer* / OpenAL source
	push rbx
	push rsi
	push rdi
	push rbp
	sub rsp,X64_FRAME
	mov rsi,rcx ; lpXM
	mov rdi,rdx ; param
	mov ebx,r8d ; fdwSong
if DRIVER_WINMM
else
	mov rbp,r9  ; IDirectSoundBuffer / alsource
endif
	; *** FREE PREVIOUS TRACK, IF ANY
	call uFMOD_FreeSong
if DRIVER_OPENAL
	; *** GENERATE SOME STREAMING BUFFERS
	mov ecx,totalblocks ; n
	lea rdx,[databuf]   ; *buffers
	call alGenBuffers
endif
	test rsi,rsi
	jz PlaySong_R
if DRIVER_WINMM
else
	mov [hWaveOut],rbp
endif
	; *** SET I/O CALLBACKS
	mov [mmf],edi ; param (XM_MEMORY: image size)
	and DWORD PTR [mmf+4],0
	test bl,XM_MEMORY
	lea rcx,[uFMOD_mem]
if XM_FILE_ON
	jnz set_callbacks
	test bl,XM_FILE
	lea rcx,[uFMOD_fs]
	jnz set_callbacks
else
	if XM_RC_ON
		jnz set_callbacks
		test bl,XM_FILE
		jnz FreeSong_body ; File-loading unsupported (return error)
	else
		jz FreeSong_body  ; Only memory
	endif
endif
if XM_RC_ON
	lea rcx,[uFMOD_rc]
endif
set_callbacks:
if NOLOOP_ON
	test bl,XM_NOLOOP
	setnz [ufmod_noloop]
endif
if PAUSE_RESUME_ON
	and bl,XM_SUSPENDED
	mov [ufmod_pause_],bl
endif
	mov rax,[rcx]
	mov [uFMOD_fopen],rax
	mov rax,[rcx+8]
	mov [uFMOD_fread],rax
if XM_FILE_ON
	mov rax,[rcx+16]
	mov [uFMOD_fclose],rax
endif
if VOL_CONTROL_ON
	cmp DWORD PTR [ufmod_vol],0
	jne play_vol_ok
	mov WORD PTR [ufmod_vol],32768
play_vol_ok:
endif
if DRIVER_WINMM
	; *** INIT OUTPUT PCM DRIVER
	lea rcx,[hWaveOut] ; phwo
	mov edx,-1         ; uDeviceID
	lea r8,[pcm]       ; pwfx
	xor r9d,r9d        ; dwCallback
	mov [rsp+32],r9    ; dwCallbackInstance
	mov [rsp+40],r9    ; fdwOpen
	call waveOutOpen
endif
	; *** ALLOCATE A HEAP OBJECT
	xor ecx,ecx ; flOptions
	xor edx,edx ; dwInitialSize <- 1 page
	xor r8d,r8d ; dwMaximumSize <- make it "growable"
	call HeapCreate
	mov [hHeap],rax
	test rax,rax
	jz FreeSong_body
	; LOAD NEW TRACK
	mov [mmf+8],rsi ; pMem
	lea rbp,[uFMOD_fopen]
	; uFMOD_fopen gets lpXM in RSI and param in RDI
	call LoadXM
if XM_FILE_ON
	mov ebx,eax
	call QWORD PTR [uFMOD_fclose]
	test ebx,ebx
else
	test eax,eax
endif
	jz FreeSong_body
if DRIVER_WINMM
	; *** CREATE AND START LOOPING WAVEOUT BLOCK
	lea rdx,[MixBlock]
	lea rax,[databuf]
	mov [rdx+uF_WMMBlock_lpData],rax
	mov DWORD PTR [rdx+uF_WMMBlock_dwBufferLength],FSOUND_BufferSize*4
	or DWORD PTR [rdx+uF_WMMBlock_dwLoops],-1
	mov DWORD PTR [rdx+uF_WMMBlock_dwFlags],12 ; WHDR_BEGINLOOP | WHDR_ENDLOOP
	mov rcx,[hWaveOut]
	mov r8d,uF_WMMBlock_size
	call waveOutPrepareHeader
endif
	; *** PREFILL THE MIXER BUFFER
loop_3:
if DRIVER_OPENAL
	mov eax,[uFMOD_FillBlk]
	lea rdx,[databuf]
	mov eax,[rdx+rax*4]
	mov [mmt],eax
	call alGetError
	test eax,eax
	jnz FreeSong_body
endif
	call uFMOD_SW_Fill
	cmp DWORD PTR [uFMOD_FillBlk],0
	jnz loop_3
	and QWORD PTR [SW_Exit],0
	; START THE OUTPUT
if DRIVER_DIRECTSOUND
	mov rcx,[hWaveOut] ; this
	xor edx,edx        ; dwReserved1
	xor r8d,r8d        ; dwPriority
	mov r9d,1          ; dwFlags = DSBPLAY_LOOPING
	mov rax,[rcx]
	call QWORD PTR [rax+96] ; IDirectSoundBuffer::Play
	test eax,eax
	js FreeSong_body
endif
if DRIVER_WINMM
	mov rcx,[hWaveOut]
	lea rdx,[MixBlock]
	mov r8d,uF_WMMBlock_size
	call waveOutWrite
	test eax,eax
	jnz FreeSong_body
endif
	; *** CREATE THE THREAD
	xor ecx,ecx          ; lpThreadAttributes
	xor edx,edx          ; dwStackSize
	lea r8,[uFMOD_Thread] ; lpStartAddress
	xor r9d,r9d          ; lpParameter
	mov [rsp+32],r9      ; dwCreationFlags
	mov [rsp+40],r9      ; lpThreadId
	call CreateThread
	mov [hThread],rax
	test rax,rax
	jz FreeSong_body
	mov rcx,rax
	mov edx,15 ; THREAD_PRIORITY_TIME_CRITICAL
	call SetThreadPriority
	lea rax,[hWaveOut]
PlaySong_R:
	add rsp,X64_FRAME
	pop rbp
	pop rdi
	pop rsi
	pop rbx
	ret
else
	; *** FREE PREVIOUS TRACK, IF ANY
	call uFMOD_FreeSong
if DRIVER_OPENAL
	; *** GENERATE SOME STREAMING BUFFERS
	push OFFSET databuf ; *buffers
	push totalblocks    ; n
	call alGenBuffers
	pop PAX
	pop PAX
endif
	pop PAX
	pop PDX ; lpXM
	pop DWORD PTR [mmf] ; param
if DRIVER_WINMM
else
	pop DWORD PTR [hWaveOut] ; fdwSong
endif
	pop PCX ; IDirectSoundBuffer / alsource / fdwSong
	test edx,edx
	push PAX
	jz mem_seek_R
	; *** SET I/O CALLBACKS
	push PBX
	push PSI
	push PDI
	push PBP
	mov ebx,OFFSET hWaveOut
	mov ebp,OFFSET uFMOD_fopen
if DRIVER_WINMM
else
	; IDirectSoundBuffer / alsource <-> fdwSong
	mov eax,[PBX]
	mov [PBX],ecx
	xchg ecx,eax
endif
	xor eax,eax
	mov [PBP-16],eax ; mmf+4
	test cl,XM_MEMORY
	mov esi,OFFSET uFMOD_mem
if XM_FILE_ON
	jnz set_callbacks
	test cl,XM_FILE
	lea esi,[PSI+(uFMOD_fs-uFMOD_mem)]
	jnz set_callbacks
else
	if XM_RC_ON
		jnz set_callbacks
		test cl,XM_FILE
		jnz uFMOD_FreeSong+4 ; File-loading unsupported (return error)
	else
		jz uFMOD_FreeSong+4  ; Only memory
	endif
endif
if XM_RC_ON
	if XM_FILE_ON
		lea esi,[PSI+(uFMOD_rc-uFMOD_fs)]
	else
		lea esi,[PSI+(uFMOD_rc-uFMOD_mem)]
	endif
endif
set_callbacks:
if NOLOOP_ON
	test cl,XM_NOLOOP
	setnz [PBP-24] ; ufmod_noloop
endif
if PAUSE_RESUME_ON
	and cl,XM_SUSPENDED
	mov [PBP-23],cl ; ufmod_pause_
endif
	mov edi,ebp ; uFMOD_fopen
	movsd
	movsd
if XM_FILE_ON
	movsd
endif
	mov esi,edx ; uFMOD_fopen:lpXM <= ESI
if VOL_CONTROL_ON
	cmp [PBP-4],eax ; ufmod_vol
	jne play_vol_ok
	mov WORD PTR [PBP-4],32768
play_vol_ok:
endif
	push PAX ; dwMaximumSize <- make it "growable"
	push PAX ; dwInitialSize <- 1 page
	push PAX ; flOptions
if DRIVER_WINMM
	; *** INIT OUTPUT PCM DRIVER
	push PAX ; fdwOpen
	push PAX ; dwCallbackInstance
	push PAX ; dwCallback
	push OFFSET pcm ; pwfx
	push -1  ; uDeviceID
	push PBX ; phwo
	call waveOutOpen
endif
	; *** ALLOCATE A HEAP OBJECT
	call HeapCreate
	test eax,eax
	mov [PBX-8],eax ; hHeap
	jz goto_freesong
	; LOAD NEW TRACK
	mov [PBP-12],esi ; mmf+8 <= pMem
	call LoadXM
if XM_FILE_ON
	xchg eax,edi
	call DWORD PTR [PBP+8] ; uFMOD_fclose
	test edi,edi
else
	test eax,eax
endif
goto_freesong:
	jz uFMOD_FreeSong+4
if DRIVER_WINMM
	; *** CREATE AND START LOOPING WAVEOUT BLOCK
	mov esi,OFFSET MixBlock
	mov DWORD PTR [PSI+uF_WMMBlock_dwBufferLength],FSOUND_BufferSize*4
	or DWORD PTR [PSI+uF_WMMBlock_dwLoops],-1
	push 12 ; WHDR_BEGINLOOP | WHDR_ENDLOOP
	mov DWORD PTR [PSI+uF_WMMBlock_lpData],OFFSET databuf
	pop DWORD PTR [PSI+uF_WMMBlock_dwFlags]
	push 32 ; SIZEOF WAVEHDR
	push PSI
	push DWORD PTR [PBX]
	call waveOutPrepareHeader
endif
	xor edi,edi
	; *** PREFILL THE MIXER BUFFER
loop_3:
if DRIVER_OPENAL
	mov eax,[PBX+4]
	mov eax,[OFFSET databuf+PAX*4]
	mov [mmt],eax
	call alGetError
	test eax,eax
	jnz uFMOD_FreeSong+4
endif
	call uFMOD_SW_Fill
	cmp [PBX+4],edi ; uFMOD_FillBlk
	jnz loop_3
	mov [PBX+8],edi ; SW_Exit <= 0
	; START THE OUTPUT
if DRIVER_DIRECTSOUND
	mov eax,[PBX]
	push 1   ; dwFlags = DSBPLAY_LOOPING
	push PDI ; dwPriority
	push PDI ; dwReserved1
	push PAX ; this
	mov ecx,[PAX]
	call DWORD PTR [PCX+48] ; IDirectSoundBuffer::Play
	test eax,eax
	js uFMOD_FreeSong+4
endif
if DRIVER_WINMM
	push 32 ; SIZEOF WAVEHDR
	push PSI
	push DWORD PTR [PBX] ; hWaveOut
	call waveOutWrite
	test eax,eax
	jnz uFMOD_FreeSong+4
endif
	; *** CREATE THE THREAD
	push PBP ; lpThreadID
	push PDI
	push PDI
	push OFFSET uFMOD_Thread
	push PDI
	push PDI
	call CreateThread
	test eax,eax
	mov [PBX-4],eax ; hThread
	jz uFMOD_FreeSong+4
	push 15 ; THREAD_PRIORITY_TIME_CRITICAL
	push PAX
	call SetThreadPriority
	xchg eax,ebx ; OFFSET hWaveOut
	pop PBP
	pop PDI
	pop PSI
	pop PBX
	ret
endif

if FMT_DLL
	PUBLIC DllEntry
	DllEntry:
	if UF_X64
		; Only on DLL_PROCESS_DETACH. (The Win32 entry frees the song on
		; every notification, including DLL_THREAD_ATTACH from uFMOD's own
		; thread, which then waits for itself and never plays.)
		test edx,edx
		jnz DllEntry_R
		sub rsp,40
		call uFMOD_FreeSong
		add rsp,40
	DllEntry_R:
		mov eax,1
		ret
	else
		call uFMOD_FreeSong
		xor eax,eax
		inc eax
		ret 12
	endif
endif

; Stop the currently playing song, if any, and free all resources allocated for that song.
if PBASIC
	EXPORTcc DRIVER_DIRECTSOUND, PB_uFMOD_DSStopSong
	EXPORTcc DRIVER_OPENAL,      PB_uFMOD_OALStopSong
	EXPORTcc DRIVER_WINMM,       PB_uFMOD_StopSong
endif
uFMOD_FreeSong:
if UF_X64
	push rbx
	push rsi
	push rdi
	push rbp
	sub rsp,X64_FRAME
FreeSong_body:
	; *** STOP THE THREAD
	mov rcx,[hThread]
	test rcx,rcx
	jz thread_finished
	mov [SW_Exit],rcx
	; Wait for thread to finish
	mov edx,-1 ; dwTimeout = INFINITE
	call WaitForSingleObject
	mov rcx,[hThread]
	call CloseHandle
thread_finished:
	xor ebx,ebx
if BENCHMARK_ON
	; *** RESET THE PERFORMANCE COUNTER
	mov [_uFMOD_tsc],ebx
endif
	; *** STOP, RESET AND CLOSE THE SOUND DRIVER
	mov [hThread],rbx
	mov rdi,[hWaveOut]
	mov [uFMOD_FillBlk],ebx
	test rdi,rdi
	jz snd_closed
	mov [hWaveOut],rbx
if DRIVER_DIRECTSOUND
	mov rcx,rdi ; this
	mov rax,[rdi]
	call QWORD PTR [rax+144] ; IDirectSoundBuffer::Stop
	mov rcx,rdi ; this
	xor edx,edx ; position = 0
	mov rax,[rdi]
	call QWORD PTR [rax+104] ; IDirectSoundBuffer::SetCurrentPosition
endif
if DRIVER_OPENAL
	mov ecx,edi         ; source
	call alSourceStop
	mov ecx,edi         ; source
	mov edx,1009h       ; param = AL_BUFFER
	xor r8d,r8d         ; value = NULL
	call alSourcei
	mov ecx,totalblocks ; n
	lea rdx,[databuf]   ; *buffers
	call alDeleteBuffers
endif
if DRIVER_WINMM
	mov rcx,rdi ; hwo
	call waveOutReset
	mov rcx,rdi ; hwo
	lea rdx,[MixBlock]
	mov r8d,uF_WMMBlock_size
	call waveOutUnprepareHeader
	; SHUT DOWN PCM DRIVER
	mov rcx,rdi ; hwo
	call waveOutClose
endif
snd_closed:
	; *** FREE THE HEAP
	mov rcx,[hHeap]
	xor eax,eax
	test rcx,rcx
	jz free_R
	mov [hHeap],rbx
	call HeapDestroy
	xor eax,eax
if INFO_API_ON
	; *** CLEAR THE RealBlock, time_ms, VU ARRAY AND szTtl
	mov ecx,uF_STATS_size*totalblocks/4+3
	lea rdi,[RealBlock]
	rep stosd
endif
free_R:
if DRIVER_DIRECTSOUND
	dec eax ; HRESULT <- error
endif
	add rsp,X64_FRAME
	pop rbp
	pop rdi
	pop rsi
	pop rbx
	ret

uFMOD_Thread:
	push rbp
	push rsi
	push rbx
	sub rsp,32
thread_loop_1:
if DRIVER_OPENAL
	; *** RESUME ON STARTUP AND BUFFER UNDERRUNS
	mov ecx,[hWaveOut] ; source
	mov edx,1010h      ; pname  = AL_SOURCE_STATE
	lea r8,[mmt]       ; *value = &mmt
	call alGetSourcei
	; if(state != AL_PLAYING) alSourcePlay(source);
	cmp DWORD PTR [mmt],1012h
	je source_playing
	mov ecx,[hWaveOut] ; source
	call alSourcePlay
source_playing:
	and DWORD PTR [mmt],0
	mov ecx,[hWaveOut] ; source
	mov edx,1016h      ; pname  = AL_BUFFERS_PROCESSED
	lea r8,[mmt]       ; *value = &mmt
	call alGetSourcei
	mov esi,[mmt]
endif
if DRIVER_DIRECTSOUND
	mov rcx,[hWaveOut]     ; this
	lea rdx,[mmt]          ; *pdwCurrentPlayCursor  = &mmt
	xor r8d,r8d            ; *pdwCurrentWriteCursor = NULL
	mov rax,[rcx]
	call QWORD PTR [rax+32] ; IDirectSoundBuffer::GetCurrentPosition
	mov esi,[mmt]
	shr esi,FSOUND_Block+2 ; / (FSOUND_BlockSize * 4)
	and esi,fragmentsmask  ; % totalblocks
endif
if DRIVER_WINMM
	mov DWORD PTR [mmt],4  ; TIME_BYTES
	mov rcx,[hWaveOut]
	lea rdx,[mmt]
	mov r8d,12             ; SIZEOF MMTIME
	call waveOutGetPosition
	mov esi,[mmt+4]        ; u.cb
	shr esi,FSOUND_Block+2 ; / (FSOUND_BlockSize * 4)
	and esi,fragmentsmask  ; % totalblocks
endif
thread_loop_2:
	; *** TAKE A LITTLE NAP :-)
	mov ecx,5
	call Sleep
	; *** CHECK FOR A REQUEST TO QUIT
	cmp QWORD PTR [SW_Exit],0
	je thread_loop_2_continue
	add rsp,32
	pop rbx
	pop rsi
	pop rbp
	ret
thread_loop_2_continue:
	; *** DO WE NEED TO FETCH ANY MORE DATA INTO SOUND BUFFERS?
if DRIVER_OPENAL
	dec esi
	js thread_loop_1
	and DWORD PTR [mmt],0
	mov ecx,[hWaveOut] ; source
	mov edx,1          ; n        = 1
	lea r8,[mmt]       ; *buffers = &mmt
	call alSourceUnqueueBuffers
else
	cmp [uFMOD_FillBlk],esi
	je thread_loop_1
endif
if INFO_API_ON
	if PAUSE_RESUME_ON
		cmp BYTE PTR [ufmod_pause_],0
		jne thread_realblock_ok
	endif
	lea rax,[RealBlock]
	inc BYTE PTR [rax]
	cmp BYTE PTR [rax],totalblocks
	jl thread_realblock_ok
	mov BYTE PTR [rax],0
thread_realblock_ok:
endif
	call uFMOD_SW_Fill
	jmp thread_loop_2
else
	push ebx
	push esi
	push edi
	push ebp
; uFMOD_FreeSong+4
	; *** STOP THE THREAD
	mov ebp,OFFSET hThread
	mov eax,[PBP]
	test eax,eax
	jz thread_finished
	mov [PBP+12],eax ; SW_Exit
	; Wait for thread to finish
	push PAX ; hObject
	push PBP ; dwTimeout ~ INFINITE
	push PAX ; hObject   = hThread
	call WaitForSingleObject
	call CloseHandle
thread_finished:
	xor ebx,ebx
if BENCHMARK_ON
	; *** RESET THE PERFORMANCE COUNTER
	mov [_uFMOD_tsc],ebx
endif
	; *** STOP, RESET AND CLOSE THE SOUND DRIVER
	mov [PBP],ebx   ; hThread
	mov edi,[PBP+4] ; hWaveOut
	mov [PBP+8],ebx ; uFMOD_FillBlk
	test edi,edi
	jz snd_closed
	mov [PBP+4],ebx
if DRIVER_DIRECTSOUND
	push PBX ; position = 0
	push PDI ; this
	push PDI ; this
	mov edi,[PDI]
	call DWORD PTR [PDI+72] ; IDirectSoundBuffer::Stop
	call DWORD PTR [PDI+52] ; IDirectSoundBuffer::SetCurrentPosition
endif
if DRIVER_OPENAL
	push PBX            ; value = NULL
	push 1009h          ; param = AL_BUFFER
	push PDI            ; source
	call alSourceStop
	call alSourcei
	push OFFSET databuf ; *buffers
	push totalblocks    ; n
	call alDeleteBuffers
	add esp,20
endif
if DRIVER_WINMM
	push PDI ; hwo
	push 32  ; cbwh <= SIZEOF WAVEHDR
	push OFFSET MixBlock ; pwh
	push PDI ; hwo
	push PDI ; hwo
	call waveOutReset
	call waveOutUnprepareHeader
	; SHUT DOWN PCM DRIVER
	call waveOutClose
endif
snd_closed:
	; *** FREE THE HEAP
	mov eax,[PBP-4] ; hHeap
	test eax,eax
	jz free_R
	mov [PBP-4],ebx ; hHeap
	push PAX ; hHeap
	call HeapDestroy
	xchg eax,ebx
if INFO_API_ON
	; *** CLEAR THE RealBlock, time_ms, VU ARRAY AND szTtl
	mov ecx,uF_STATS_size*totalblocks/4+3
	mov edi,OFFSET RealBlock
	rep stosd
endif
free_R:
if DRIVER_DIRECTSOUND
	dec eax ; HRESULT <- error
endif
	pop PBP
	pop PDI
	pop PSI
	pop PBX
	ret

uFMOD_Thread:
	push PBP
	push PSI
	mov ebp,OFFSET mmt
thread_loop_1:
if DRIVER_OPENAL
	; *** RESUME ON STARTUP AND BUFFER UNDERRUNS
	push PBP                ; *value = &mmt
	push 1010h              ; pname  = AL_SOURCE_STATE
	push DWORD PTR [PBP+20] ; source = hWaveOut
	call alGetSourcei
	add esp,12
	; if(state != AL_PLAYING) alSourcePlay(source);
	cmp DWORD PTR [PBP],1012h
	je source_playing
	push DWORD PTR [PBP+20] ; source = hWaveOut
	call alSourcePlay
	pop PAX
source_playing:
	push PBP                ; *value = &mmt
	push 1016h              ; pname  = AL_BUFFERS_PROCESSED
	push DWORD PTR [PBP+20] ; source = hWaveOut
	and DWORD PTR [PBP],0
	call alGetSourcei
	add esp,12
	mov esi,[PBP]
endif
if DRIVER_DIRECTSOUND
	push 0                  ; *pdwCurrentWriteCursor = NULL
	push PBP                ; *pdwCurrentPlayCursor  = &mmt
	mov eax,[PBP+20]        ; hWaveOut
	push PAX                ; this
	mov ecx,[PAX]
	call DWORD PTR [PCX+16] ; IDirectSoundBuffer::GetCurrentPosition
	mov esi,[PBP]
	shr esi,FSOUND_Block+2  ; / (FSOUND_BlockSize * 4)
	and esi,fragmentsmask   ; % totalblocks
endif
if DRIVER_WINMM
	push 4
	pop DWORD PTR [PBP]
	push 12 ; SIZEOF MMTIME
	push PBP
	push DWORD PTR [PBP+20] ; hWaveOut
	call waveOutGetPosition
	mov esi,[PBP+4] ; u.cb
	shr esi,FSOUND_Block+2  ; / (FSOUND_BlockSize * 4)
	and esi,fragmentsmask   ; % totalblocks
endif
thread_loop_2:
	; *** TAKE A LITTLE NAP :-)
	push 5
	call Sleep
	; *** CHECK FOR A REQUEST TO QUIT
	cmp DWORD PTR [PBP+28],0 ; SW_Exit
	je thread_loop_2_continue
	pop PSI
	pop PBP
	ret 4
thread_loop_2_continue:
	; *** DO WE NEED TO FETCH ANY MORE DATA INTO SOUND BUFFERS?
if DRIVER_OPENAL
	dec esi
	js thread_loop_1
else
	cmp [PBP+24],esi ; uFMOD_FillBlk
	je thread_loop_1
endif
if DRIVER_OPENAL
	push PBP                ; *buffers = &mmt
	push 1                  ; n        = 1
	push DWORD PTR [PBP+20] ; source   = hWaveOut
	and DWORD PTR [PBP],0
	call alSourceUnqueueBuffers
	add esp,12
endif
if INFO_API_ON
	if PAUSE_RESUME_ON
		cmp BYTE PTR [ufmod_pause_],0
		jne thread_realblock_ok
	endif
	mov eax,OFFSET RealBlock
	inc BYTE PTR [eax]
	cmp BYTE PTR [eax],totalblocks
	jl thread_realblock_ok
	mov BYTE PTR [eax],0
thread_realblock_ok:
endif
	push OFFSET thread_loop_2 ; EIP
endif

uFMOD_SW_Fill:
if BENCHMARK_ON
	dw 310Fh ; rdtsc
	mov [bench_t_lo],eax
endif
	mov ecx,FSOUND_BlockSize*2
	push PBX
	push PSI
	push PDI
	push PBP
if UF_X64
	sub rsp,X64_FRAME
	lea rdi,[MixBuf]
else
	mov edi,OFFSET MixBuf
endif
	xor eax,eax
	push PDI ; mixbuffer <= OFFSET MixBuf
	push PDI ; <- MixPtr
	; MIXBUFFER CLEAR
if UF_X64
	lea rsi,[_mod+36]
else
	mov esi,OFFSET _mod+36
endif
	rep stosd
if PAUSE_RESUME_ON
	cmp [ufmod_pause_],al
	xchg eax,ebp
	jne do_swfill
endif
	mov ebp,FSOUND_BlockSize
	; UPDATE MUSIC
	mov ebx,[PSI+uF_MOD_mixer_samplesleft-36]
fill_loop_1:
	test ebx,ebx
	jnz mixedleft_nz
	; UPDATE XM EFFECTS
	cmp [PSI+uF_MOD_tick-36],ebx ; new note
	mov PCX,[PSI+uF_MOD_pattern-36]
	jne update_effects
	dec ebx
	; process any rows commands to set the next order/row
	mov edx,[PSI+uF_MOD_nextorder-36]
	mov eax,[PSI+uF_MOD_nextrow-36]
	mov [PSI+uF_MOD_nextorder-36],ebx
	test edx,edx
	mov [PSI+uF_MOD_nextrow-36],ebx
	jl fill_nextrow
	mov [PSI+uF_MOD_order-36],edx
fill_nextrow:
	test eax,eax
	jl update_note
	mov [PSI+uF_MOD_row-36],eax
update_note:
	; mod+36 : ESI
	call DoNote
if ROWCOMMANDS_ON
	cmp DWORD PTR [PSI+uF_MOD_nextrow-36],-1
	jne inc_tick
endif
	mov eax,[PSI+uF_MOD_row-36]
	inc eax
	; if end of pattern
	; "if(mod->nextrow >= mod->pattern[mod->orderlist[mod->order]].rows)"
	cmp ax,[PBX]
	jl set_nextrow
	mov edx,[PSI+uF_MOD_order-36]
	movzx ecx,WORD PTR [PSI+uF_MOD_numorders-36]
	inc edx
	xor eax,eax
	cmp edx,ecx
	jl set_nextorder
	; We've reached the end of the order list. So, stop playing, unless looping is enabled.
if NOLOOP_ON
	cmp [ufmod_noloop],al
	je set_restart
if UF_X64
	pop rbx
	pop QWORD PTR [SW_Exit] ; SW_Exit : remove mixbuffer - signal thread to stop
else
	mov ebp,OFFSET hThread
	pop ebx
	pop DWORD PTR [ebp+12] ; SW_Exit : remove mixbuffer - signal thread to stop
endif
	jmp thread_finished
set_restart:
endif
	movzx edx,WORD PTR [PSI+uF_MOD_restart-36]
	cmp edx,ecx
	sbb ecx,ecx
	and edx,ecx
set_nextorder:
	mov [PSI+uF_MOD_nextorder-36],edx
set_nextrow:
	mov [PSI+uF_MOD_nextrow-36],eax
	jmp inc_tick
update_effects:
	; mod+36 : ESI
	call DoEffs
inc_tick:
	mov eax,[PSI+uF_MOD_speed-36]
	mov ebx,[PSI+uF_MOD_mixer_samplespertick-36]
	inc DWORD PTR [PSI+uF_MOD_tick-36]
if PATTERNDELAY_ON
	add eax,[PSI+uF_MOD_patterndelay-36]
endif
	cmp [PSI+uF_MOD_tick-36],eax
	jl mixedleft_nz
if PATTERNDELAY_ON
	and DWORD PTR [PSI+uF_MOD_patterndelay-36],0
endif
	and DWORD PTR [PSI+uF_MOD_tick-36],0
mixedleft_nz:
	mov edi,ebp
	cmp ebx,edi
	jae fill_ramp
	mov edi,ebx
fill_ramp:
	pop PDX  ; <- MixPtr
	sub ebp,edi
	lea PAX,[PDX+PDI*8]
	push PAX ; MixPtr += (SamplesToMix<<3)
	; tail    : [arg0]
	; len     : EDI
	; mixptr  : EDX
	; _mod+36 : ESI
	call Ramp
if INFO_API_ON
	lea eax,[PDI+PDI*4]
	cdq
	shl eax,2
	mov ecx,FSOUND_MixRate/50
	div ecx
	; time_ms += SamplesToMix*FSOUND_OOMixRate*1000
	add [time_ms],eax
endif
	sub ebx,edi ; MixedLeft -= SamplesToMix
	test ebp,ebp
	jnz fill_loop_1
	mov [PSI+uF_MOD_mixer_samplesleft-36],ebx ; <= MixedLeft
if INFO_API_ON
	mov edx,[uFMOD_FillBlk]
if UF_X64
	lea rax,[tInfo+4]
	lea rdx,[rax+rdx*uF_STATS_size]
else
	lea edx,[edx*uF_STATS_size + OFFSET tInfo+4]
endif
	mov ecx,[PSI + uF_MOD_row-36]
	or ecx,[PSI + uF_MOD_order-2-36]
	mov [PDX],ecx
endif
do_swfill:
	; *** CLIP AND COPY BLOCK TO OUTPUT BUFFER
	pop PAX ; skip MixPtr
	pop PSI ; <- mixbuffer
if INFO_API_ON
	; ebx : L channel RMS volume
	; ebp : R channel RMS volume
	xor ebx,ebx
endif
if DRIVER_DIRECTSOUND
if UF_X64
	; Lock the output buffer
	mov edx,[uFMOD_FillBlk]
	shl edx,FSOUND_Block+2     ; dwOffset = uFMOD_FillBlk x FSOUND_BlockSize*4
	mov rcx,[hWaveOut]         ; this
	mov r8d,FSOUND_BlockSize*4 ; dwBytes
	lea r9,[mmt+8]             ; ppvAudioPtr1
	lea rax,[mmt]
	mov [rsp+32],rax           ; pdwAudioBytes1
	xor eax,eax
	mov [rsp+40],rax           ; ppvAudioPtr2
	mov [rsp+48],rax           ; pdwAudioBytes2
	mov [rsp+56],rax           ; dwFlags
	mov rax,[rcx]
	call QWORD PTR [rax+88]    ; IDirectSoundBuffer::Lock
	test eax,eax
	jns DS_lock_ok
	cmp eax,88780096h ; DSERR_BUFFERLOST
	jne DS_R
	; Try to restore the buffer
	mov rcx,[hWaveOut]         ; this
	mov rax,[rcx]
	call QWORD PTR [rax+160]   ; IDirectSoundBuffer::Restore
	jmp DS_R
DS_lock_ok:
	mov ecx,[mmt]
	mov rdi,[mmt+8] ; <dest. ptr>
else
	mov eax,[esi-8] ; uFMOD_FillBlk
	; Lock the output buffer
	cdq
	shl eax,FSOUND_Block+2 ; x FSOUND_BlockSize*4
	mov edi,OFFSET mmt
	push PDX ; Lock:dwFlags
	push PDX ; Lock:pdwAudioBytes2
	push PDX ; Lock:ppvAudioPtr2
	push PDI ; Lock:pdwAudioBytes1
	stosd
	push PDI ; Lock:ppvAudioPtr1
	push FSOUND_BlockSize*4 ; Lock:dwBytes
	push PAX ; Lock:dwOffset
	mov eax,[PDI+16]
	push PAX ; this
	mov ecx,[PAX]
	call DWORD PTR [PCX+44] ; IDirectSoundBuffer::Lock
	test eax,eax
	jns DS_lock_ok
	cmp eax,88780096h ; DSERR_BUFFERLOST
	jne DS_R
	; Try to restore the buffer
	mov eax,[PDI+16]
	push PAX ; this
	mov ecx,[PAX]
	call DWORD PTR [PCX+80] ; IDirectSoundBuffer::Restore
	jmp DS_R
DS_lock_ok:
	mov ecx,[edi-4]
	mov edi,[edi]   ; <dest. ptr>
endif
endif
if DRIVER_WINMM
if UF_X64
	mov eax,[uFMOD_FillBlk]
	shl eax,FSOUND_Block+2 ; x FSOUND_BlockSize*4
	lea rdi,[databuf]
	add rdi,rax
else
	mov eax,[esi-8] ; uFMOD_FillBlk
	shl eax,FSOUND_Block+2 ; x FSOUND_BlockSize*4
	lea edi,[eax+OFFSET databuf]
endif
endif
if DRIVER_OPENAL
	mov PDI,PSI
if UF_X64
else
	push FSOUND_MixRate     ; freq
	push FSOUND_BlockSize*4 ; size
	push esi                ; *data
endif
endif
if DRIVER_DIRECTSOUND
	shr ecx,1
	jz SW_Fill_Ret
else
	mov ecx,FSOUND_BlockSize*2
endif
	align 4
fill_loop_2:
	lodsd
if INFO_API_ON
	push PDI
	cdq
	mov edi,eax
	push PSI
	xor eax,edx
	mov esi,255*volumerampsteps/2
	sub eax,edx
	xor edx,edx
	div esi
	cmp edx,255*volumerampsteps/4
	pop PSI
	sbb eax,-1
	cmp eax,8000h
	sbb edx,edx
	not edx
	or eax,edx
	sar edi,31
	and eax,7FFFh
if VOL_CONTROL_ON
	mul DWORD PTR [ufmod_vol]
	shr eax,15
endif
	; sum. the L and R channel RMS volume
	ror ecx,1
	sbb edx,edx
	and edx,eax
	add ebp,edx ; += |vol|
	rol ecx,1
	sbb edx,edx
	not edx
	and edx,eax
	add ebx,edx ; += |vol|
	xor eax,edi
	sub eax,edi
	pop PDI
else
	mov ebx,eax
	cdq
	xor eax,edx
	sub eax,edx
	mov ebp,255*volumerampsteps/2
	xor edx,edx
	div ebp
	cmp edx,255*volumerampsteps/4
	sbb eax,-1
	cmp eax,8000h
	sbb edx,edx
	not edx
	or eax,edx
	sar ebx,31
	and eax,7FFFh
if VOL_CONTROL_ON
	mul DWORD PTR [ufmod_vol]
	shr eax,15
endif
	xor eax,ebx
	sub eax,ebx
endif
	dec ecx
	stosw
	jnz fill_loop_2
SW_Fill_Ret:
if DRIVER_DIRECTSOUND
	; Unlock the output buffer
if UF_X64
	mov rcx,[hWaveOut]        ; this
	mov rdx,[mmt+8]           ; pvAudioPtr1
	mov r8d,[mmt]             ; dwAudioBytes1
	xor r9d,r9d               ; pvAudioPtr2
	mov [rsp+32],r9           ; dwAudioBytes2
	mov rax,[rcx]
	call QWORD PTR [rax+152]  ; IDirectSoundBuffer::Unlock
else
	mov edi,OFFSET mmt
	push PCX                  ; Unlock:pdwAudioBytes2
	push PCX                  ; Unlock:ppvAudioPtr2
	push DWORD PTR [PDI]      ; Unlock:pdwAudioBytes1
	push DWORD PTR [PDI+4]    ; Unlock:ppvAudioPtr1
	mov eax,[PDI+20]
	push PAX ; this
	mov ecx,[PAX]
	call DWORD PTR [ecx+76]   ; IDirectSoundBuffer::Unlock
endif
DS_R:
endif
if DRIVER_OPENAL
if UF_X64
	mov ecx,[mmt]              ; buffer
	mov edx,1103h              ; format = AL_FORMAT_STEREO16
	lea r8,[MixBuf]            ; *data
	mov r9d,FSOUND_BlockSize*4 ; size
	mov DWORD PTR [rsp+32],FSOUND_MixRate ; freq
	call alBufferData
	mov ecx,[hWaveOut]         ; source
	mov edx,1                  ; n
	lea r8,[mmt]               ; *buffers
	call alSourceQueueBuffers
else
	push 1103h                ; format = AL_FORMAT_STEREO16
	push DWORD PTR [mmt]      ; buffer
	call alBufferData
	push OFFSET mmt           ; *buffers
	push 1                    ; n
	push DWORD PTR [hWaveOut] ; source
	call alSourceQueueBuffers
	add esp,32
endif
endif
	mov eax,[uFMOD_FillBlk]
	inc eax
	cmp eax,totalblocks
	jl SW_Fill_R
	xor eax,eax
SW_Fill_R:
	mov [uFMOD_FillBlk],eax
if INFO_API_ON
	shr ebp,FSOUND_Block      ; R_vol / FSOUND_BlockSize
	shl ebx,16-FSOUND_Block   ; (L_vol / FSOUND_BlockSize) << 16
	mov bx,bp
if UF_X64
	lea rdx,[tInfo]
	mov [rdx+rax*uF_STATS_size],ebx
else
	mov DWORD PTR [OFFSET tInfo+eax*uF_STATS_size],ebx
endif
endif
if UF_X64
	add rsp,X64_FRAME
endif
	pop PBP
	pop PDI
	pop PSI
	pop PBX
if BENCHMARK_ON
	dw 310Fh ; rdtsc
	sub eax,[bench_t_lo]
	mov [_uFMOD_tsc],eax
endif
	ret
