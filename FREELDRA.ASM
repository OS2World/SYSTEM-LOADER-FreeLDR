; freeldra.asm

.386P

pic_mask equ 21h
pic_eoi equ 20h

com_data equ 00h
com_ier equ 01h
com_iir equ 02h
com_lcr equ 03h
com_mcr equ 04h
com_sts equ 05h   ;;; line status register
com_msr equ 06h

EXTRN _sprintf:NEAR
EXTRN _auxil:NEAR,_KernelLoader:NEAR
EXTRN _FindIODelay:NEAR,_IODelay:NEAR,_SetPITChip:NEAR,_EnableA20Line:NEAR
PUBLIC _DispNTS,_DebugNTS
PUBLIC __RealCvtVector

; .MODEL tiny
DGROUP GROUP _TEXT,_DATA,_CVTSEG
ASSUME DS:DGROUP,CS:DGROUP

; .CODE
_TEXT SEGMENT WORD PUBLIC 'CODE' USE16

	org 100h

start:
	; The following gruesome hack is necessary to make
	; CS:IP equal xxxx:100h.  TLINK assumes this will be
	; the case, but actually CS:IP is yyyy:0h when we are
	; loaded from the bootstrap loader.

	mov bx,offset RetfTarget
	mov ax,cs
	sub ax,10h
	push ax  ; segment
	push bx  ; offset
	retf

RetfTarget:

	; First store the "File Table" pointer
	mov ax, es
	mov word ptr cs:FileTblPtr+2,ax
	mov word ptr cs:FileTblPtr,di

	; Now store the BPB pointer
	mov ax, ds
	mov word ptr cs:BPBPtr+2,ax
	mov word ptr cs:BPBPtr,si

	; Now store the boot drive and boot flags
	mov cs:BootFlags,dh
	mov cs:BootDrive,dl

	; Set all segment regs equal to CS
	mov ax, cs
	mov ds, ax
	mov es, ax

	cli
	mov ss, ax
	mov sp, 0a342h ; FIX THIS!! What should it be, really?
	sti

	; ifdef DEBUG
	call _asc_enb  ; set up COM2 for 9600, N81
	; endif

	call _auxil ; calls C code

	; Now display BPB ptr, File table ptr, boot drive, boot flags
	mov al,BootFlags
	xor ah,ah
	push ax
	mov al,BootDrive
	xor ah,ah
	push ax
	mov dx,word ptr FileTblPtr+2 ; segment
	mov ax,word ptr FileTblPtr   ; offset
	push dx
	push ax
	mov dx,word ptr BPBPtr+2 ; segment
	mov ax,word ptr BPBPtr	 ; offset
	push dx
	push ax
	lea dx,ds:HelloMessage
	push dx
	lea dx,ds:MsgBuff
	push dx
	call _sprintf
	add sp,10h

	lea si, ds:MsgBuff
	push si
	call _DispNTS
	add sp,2

	; ifdef DEBUG
	lea si, ds:MsgBuff
	push si
	call _DebugNTS
	add sp,2
	; endif

	; Now copy contents of File Table
	push ds
	lea di,FileTable
	lds si,FileTblPtr
	mov cx,0015h
	rep movsw
	pop ds

	; Now copy contents of BPB
	push ds
	lea di,BPBTable
	lds si,BPBPtr
	mov cx,001fh
	rep movsb
	pop ds

	; Display contents of File Table

	push word ptr [FileTable + 12h]
	push word ptr [FileTable + 10h]
	push word ptr [FileTable + 0eh]
	push word ptr [FileTable + 0ch]
	push word ptr [FileTable + 0ah]
	push word ptr [FileTable + 08h]
	push word ptr [FileTable + 06h]
	push word ptr [FileTable + 04h]
	push word ptr [FileTable + 02h]
	push word ptr [FileTable + 00h]

	lea dx,ds:FTMsg1
	push dx
	lea dx,ds:MsgBuff
	push dx
	call _sprintf
	add sp,18h

	lea si, ds:MsgBuff
	push si
	call _DispNTS
	add sp,2

	; ifdef DEBUG
	lea si, ds:MsgBuff
	push si
	call _DebugNTS
	add sp,2
	; endif

	; Display micro-FSD entry points
	push word ptr [FileTable + 28h] ; terminate
	push word ptr [FileTable + 26h]
	push word ptr [FileTable + 24h] ; close
	push word ptr [FileTable + 22h]
	push word ptr [FileTable + 20h] ; read
	push word ptr [FileTable + 1Eh]
	push word ptr [FileTable + 1Ch] ; open
	push word ptr [FileTable + 1Ah]

	lea dx,ds:FTMessage
	push dx
	lea dx,ds:MsgBuff
	push dx
	call _sprintf
	add sp,14h

	lea si, ds:MsgBuff
	push si
	call _DispNTS
	add sp,2

	; ifdef DEBUG
	lea si, ds:MsgBuff
	push si
	call _DebugNTS
	add sp,2
	; endif

	; Now find and display the I/O delay value
	call _FindIODelay

	push ax   ; the IO Delay
	lea dx,ds:IODelayMsg
	push dx
	lea dx,ds:MsgBuff
	push dx
	call _sprintf
	add sp,6

	lea si, ds:MsgBuff
	push si
	call _DispNTS
	add sp,2

	; ifdef DEBUG
	lea si, ds:MsgBuff
	push si
	call _DebugNTS
	add sp,2
	; endif

	call _SetPITChip

	; OK, time to do the memory thing.
	int 12h
	mov Int12Value,ax
	push ax   ; the return value
	lea dx,ds:Int12Msg
	push dx
	lea dx,ds:MsgBuff
	push dx
	call _sprintf
	add sp,6

	lea si, ds:MsgBuff
	push si
	call _DispNTS
	add sp,2

	; ifdef DEBUG
	lea si, ds:MsgBuff
	push si
	call _DebugNTS
	add sp,2
	; endif

	mov ah,88h
	int 15h
	mov Int1588Value,ax
	push ax   ; the return value
	lea dx,ds:Int1588Msg
	push dx
	lea dx,ds:MsgBuff
	push dx
	call _sprintf
	add sp,6

	lea si, ds:MsgBuff
	push si
	call _DispNTS
	add sp,2

	; ifdef DEBUG
	lea si, ds:MsgBuff
	push si
	call _DebugNTS
	add sp,2
	; endif

	; And now the moment you've all been waiting for: loading the kernel!!
	mov bx,offset DGROUP:FileTable
	mov ax,ds
	push ax
	push bx
	call _KernelLoader
	add sp,4

	call _EnableA20Line  ;; not implemented yet

	call _IODelay  ; just for kicks

	;;; Now terminate program

	; ifdef DEBUG
HltInst:
	hlt
	jmp HltInst
	; endif

	mov  ah,4ch	       ;DOS terminate program function
	int  21h

	;;; END of Program !!

_DispNTS proc near   ; display null-terminated string at ds:si on screen
	push bp
	mov bp,sp

	mov si,[bp+4]

Disp1:	mov al,[si]
	cmp al,0
	je Disp2
	mov ah, 0eh  ; int 10h/ah=0eh: write char on screen in teletype mode
	mov bx,0
	push si
	int 10h
	pop si
	inc si
	jmp Disp1
Disp2:
	pop bp
	ret

_DispNTS endp


_DebugNTS proc near   ; display null-terminated string at ds:si on COM port
	push bp
	mov bp,sp

	mov si,[bp+4]

Disp3:	mov al,[si]
	cmp al,0
	je Disp4
	push si

	push ax
	call _com_out
	pop ax

	pop si
	inc si
	jmp Disp3
Disp4:
	pop bp
	ret

_DebugNTS endp


; Comm routines are courtesy of Ray Duncan, *Advanced MS-DOS Programming*,
; 2d. ed., pp. 113-125
;;;;;;;;; void _com_out(int);
_com_out     proc near
    push bp
    mov bp,sp

    mov ax,[bp+4]
    push dx
    push ax
    mov dx,sp_base
    add dx,com_sts  ;;; line status register (base reg + 05h)
co1:
    in al,dx
    and al,20h	 ;; is transmit buffer empty?
    jz co1	 ;; no, must wait

    pop ax
    mov dx,sp_base
    add dx,com_data   ;;; transmitter holding register (base reg + 0h)
    out dx,al
    pop dx

    pop bp
    ret
_com_out endp


;;;;;;;;;  void asc_enb() ; port, brd, lcr are HARDCODED in this version
_asc_enb     proc near
    push bp
    mov bp,sp
    ;; here we could subtract something from sp for local vars.

    mov ax,2   ;; the port # (1-4)  -- HARDCODE 2 (COM2) for now
    mov port,al
    cmp al,1
    je port1
    cmp al,2
    je port2
    cmp al,3
    je port3

    ;; So al=4
    mov sp_base, 02e8h
    mov com_int,0bh
    mov int_mask,08h
    jmp portx

port1:
    mov sp_base, 03f8h
    mov com_int,0ch
    mov int_mask,10h
    jmp portx

port2:
    mov sp_base, 02f8h
    mov com_int,0bh
    mov int_mask,08h
    jmp portx

port3:
    mov sp_base, 03e8h
    mov com_int,0ch
    mov int_mask,10h

portx:

    ;; Now set the baud rate.
    ;; (See Wyatt, _Advanced Assembly Language_, p. 81)
    mov dx, sp_base
    add dx, com_lcr  ;; line control register
    in al,dx
    or al,10000000b  ;; set bit 7 to enable alternate registers
    out dx,al

    mov ax,0ch ;; the brd  ; HARDCODE 0ch for 9600 baud
    mov dx,sp_base
    add dx,com_data  ;; or BRDL
    out dx,al

    mov al,ah
    mov dx,sp_base
    add dx,com_ier  ;; or BRDH
    out dx,al

    mov dx, sp_base
    add dx, com_lcr  ;; line control register
    in al,dx
    and al,01111111b  ;; clear bit 7 to enable normal registers
    out dx,al

    ;; Now set the data format, e.g. N81, E71, etc.
    mov ax,3 ;; the lcr  ; HARDCODE 3 for "N81"
    and al,01111111b  ;; make sure bit 7 is off
    out dx,al	;; Here, DX already points to Line Control Register

    ;; Now set DTR/RTS and enable interrupts.
    mov dx,sp_base
    add dx,com_mcr    ;;; modem control register (02fch)
    mov al,0bh	      ;;; 1011b -- set DTR, RTS, and OUT2 bits
    out dx,al
    mov dx,sp_base
    add dx,com_ier    ;;; interrupt enable register (02f9h)
    mov al,1	      ;;; set "data available in RDR" interrupt
    out dx,al
    in al,pic_mask	   ;;; read current 8259 mask  (pic_mask is 21h)
    mov dl,int_mask    ;;; int_mask is 08h for COM2
    not dl
    and al, dl
    out pic_mask,al

    ;; here we would add back to sp whatever we subtracted for local vars
    pop bp
    ret
_asc_enb    endp



_TEXT ENDS


;.DATA
_DATA SEGMENT WORD PUBLIC 'DATA' USE16

;	 EXTRN	  _Repetitions:WORD	   ;externally defined
;	 PUBLIC   _StartingValue	   ;available to other modules
_StartingValue    DW 0
HelloMessage DB 'BPBPtr: %08lx FileTblPtr: %08lx Bootdr: %02x BootFl %02x',13,10,0,0
FTMsg1 DB 'cfiles: %04x ldr: %04x:%08lx muFSD: %04x:%08lx miniFSD: %04x:%08lx',13,10,0,0
FTMessage DB 'muOpen: %08lx muRead: %08lx muClose: %08lx muTerm: %08lx',13,10,0,0
IODelayMsg DB 'IO Delay count: %04xh',13,10,0,0
Int12Msg DB 'Int 12h returns %04xh',13,10,0,0
Int1588Msg DB 'Int 15h/88h returns %04xh',13,10,0,0
MsgBuff DB 200 dup (32)

port db 02h	    ; COM2 by default
sp_base dw 02f8h    ; serial port base address (02f8h = COM2)
com_int db 0bh	;; IRQ vector (IRQ3 = 0bh, IRQ4 = 0ch)
int_mask db 08h ; mask for IRQ3 is 08h, for IRQ4 it's 10h

FileTblPtr dd 00000000h
BPBPtr dd 00000000h
BootFlags db 0
BootDrive db 0

FileTable dw 21 dup (?)
BPBTable db 31 dup (?)

Int12Value dw (?)
Int1588Value dw (?)

DummyTable dw 10 dup (?)

_DATA ENDS

; This _CVTSEG segment appears to be necessary to keep the linker
; from complaining about the lack of C runtime startup code
_CVTSEG 	SEGMENT USE16
; PubSym@	  _RealCvtVector, <label  word>,  __CDECL__
__RealCvtVector label word
    DW 100h dup (0)
_RealCvtVector@ equ __RealCvtVector
_CVTSEG    ENDS

      END  start
