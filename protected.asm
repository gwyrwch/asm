org 0
use16

jmp main

;include 'idt.asm'

; Print string to screen
; si - address of the begin of string


redirect_IRQ:
; BX = { BL = Начало для IRQ 0..7, BH = начало для IRQ 8..15 }
; DX = Маска прерываний IRQ ( DL - для IRQ 0..7, DH - IRQ 8..15 )

        ; APIC Off
        mov     ecx,1bh
        rdmsr
        or      ah,1000b
        wrmsr

        mov     al,11h
        out     0a0h,al
        out     20h,al

        mov     al,bh
        out     0a1h,al
        mov     al,bl
        out     21h,al

        mov     al,02
        out     0a1h,al
        mov     al,04
        out     21h,al

        mov     al,01
        out     0a1h,al
        out     21h,al

        mov     al,dh
        out     0a1h,al
        mov     al,dl
        out     21h,al

        ; APIC On
        ;mov     ecx,1bh
        ;rdmsr
        ;and     ah,11110111b
        ;wrmsr

        ret

;========================================
;; Данные
;========================================
save_ss dw ?
save_sp dw ?
save_ds dw ?
save_es dw ?
save_fs dw ?
save_gs dw ?

;========================================
;; Код 16бит
;========================================
main:

    mov ax,3
    int 10h

    ;mov si, hi_real
    ;call putstr

    mov [save_ss], ss
    mov [save_ds], ds
    mov [save_es], es
    mov [save_fs], fs
    mov [save_gs], gs
    mov [save_sp], sp

    mov ax, 0x2401
    int 0x15

    call    disable_interrupts

    ;in   al,92h
    ;or   al,2
    ;out 92h,al

    lgdt [GDTR]  
    lidt [IDTR]

    call set_PE 

    ;jmp $
    jmp fword 8:protected_mode_begining;


;========================================
;; Функции
;========================================

; Устанавливает флаг PE
set_PE:
    mov     eax, cr0 ; прочитать регистр CR0
    or      al, 1    ; установить бит PE,
    mov     cr0, eax ; с этого момента мы в защищенном режиме
    ret

; Запрещает маскируемые и немаскируемые прерывания
disable_interrupts:
    cli ;запрещаем прерывания
    mov al,8Fh;запрещаем NMI
    out 70h,al
    in al,71h
    ret

putstr:
    lodsb
    or al,al
    jz  putstrd
    mov ah,0x0E
    mov bx,0x0007
    int 0x10
    jmp putstr
putstrd:
    retn


;========================================
;; Код 32бит
;========================================


use32

protected_mode_begining:

    ;jmp $
    mov eax,10h ;здесь пихаем селекторы
    mov es,ax 
    mov ds,ax
    mov fs,ax
    mov ss,ax
    mov ax,18h
    mov gs,ax

    mov  dx, 0xFFFF
    mov  bx, 0x2820
    call redirect_IRQ

    in   al, 70h
    and  al, 7Fh
    out  70h, al
    sti

    mov  edi, 0xA8000 + 0xA0
    mov  esi, hi_string  
    cld

    int 1
 
    jmp $



    ;jmp $
;========================================
; задачи
;========================================


; задача 1
;task_1:
;        mov        byte ptr ds:[edi],al ; вывести символ на экран
;        inc        al                   ; увеличить код символа
;        add        edi,2                ; увеличить адрес символа
; переключиться на задачу 0
;        db         0EAh
;        dd         0
;        dw         SEL_TSS0
; сюда будет приходить управление, когда задача 0 начнет выполнять переход
; на задачу 1 во всех случаях, кроме первого
;        mov        ecx,02000000h        ; небольшая пауза, зависящая от скорости
;        loop       $                    ; процессора
;        jmp        task_1
;========================================
; Обработчики прерываний
;========================================
test_handler:
	


int9_handler:
    push ax
    push edi
    xor  ax, ax

    ; запрашиваем позиционный код клавиши
    in   al, 060h

    dec  al   ; Нажат ли <Esc> ? (его сканкод = 1)
    jnz _continue_handling

    add  edi, 0xA0 
    mov  esi, esc
    int 1

    pop  edi
    pop  ax
    ;jmp  int_EOI
    call pressed_esc

_continue_handling:
  
    ; посылка подтверждения обрабоки в порт клавиатуры
    ; (установка и сброс 7 бита порта 061h)
   Ack:
    in   al, 061h
    or   al, 80
    out  061h, al
    xor  al, 80
    out  061h, al

clear_request:
    pop  edi
    pop  ax
    jmp  int_EOI

print_handler:
    pushad

    loo:                     
        lodsb
        test al, al
        jz   .exit
        stosb
        mov  al, 7
        stosb
        jmp  loo

    .exit:
    popad
    ;int 2
    iret

task_1:

	lodsb
	test al, al 	
	stosb
	
	
	iret

exGP_handler:
    pop  eax 
    add  edi, 0xA0
    mov  esi, gp
    int  1
    iret

int8_handler:

    add  edi, 0xA4

    push esi
    mov esi, hi_string
    int 1
	pop esi
	

    push edi
    mov edi, 0xA8000
    int 2
    pop edi
    
    jmp  int_EOI     ; сбросим заявку на прерывание



int_EOI:
    ; сброс заявки в контроллере прерываний: посылка End-Of-Interrupt (EOI) ...
    push ax
    mov  al, 20h
    out  020h, al   ; ... в ведущий (Master) контроллер ...
    out  0a0h, al   ; ... и в ведомый (Slave) контроллер.
    pop  ax
    iret           ; возврат из прерывания



stub:
    pusha
    ; interrupt handler for isr0-33
	popa
	iret

ascii    db 0,'1234567890-+',0,0,'QWERTYUIOP[]',0,0,'ASDFGHJKL;',"'`",0,0,'ZXCVBNM,./',0,'*',0,' ',0, 0,0,0,0,0,0,0,0,0,0, 0,0, '789-456+1230.', 0,0
esc db '** ESC **',0


pressed_esc:
    	add  edi, 0xA0 
    	mov  esi, hi_real  

    	int 1
    	call disable_interrupts
    	
    	jmp fword 32:protected_mode_exiting


;========================================
; Код 16бит
;========================================

use16
;org $ - 10000h
protected_mode_exiting:

    mov eax, cr0
    and al, 0xFE
    mov cr0, eax

    jmp 0x1000:real_mode




real_mode:

    mov ss,[save_ss]
    mov sp,[save_sp]
    mov ds,[save_ds]
    mov es,[save_es]
    mov fs,[save_fs]
    mov gs,[save_gs]
    

    lidt [IDTR]

    in         al,70h              ; индексный порт CMOS
    and        al,07Fh             ; сброс бита 7 отменяет блокирование NMI
    out        70h,al

    
    jmp $


hi_real db 'Hello from Real', 0
task_0_string db 'Task0',0
hi_string db 'Hello from Protected', 0
string   db '  Switched to ProtectedMode. Press <Esc> to clear display', 0
gp db '** GENERAL PROTECTION FAULT **',0
;========================================
;; Таблица дескрипторов
;========================================
align   8

gdt32:
    dd 0x0, 0x0

    dw 0xFFFF ; segment length, bits 0-15
    dw 0x0    ; segment base, bits 0-15
    db 0x1    ; segment base, bits 16-23
    db 0x9A   ; flags (8 bits)
    db 0x40   ; flags (4 bits) + segment length, bits 16-19
    db 0x0    ; segment base, bits 24-31

    dw 0xFFFF
    dw 0x0
    db 0x1
    db 0x92
    db 0xCF ; db 0x40
    db 0x0

    dw 0xFFFF
    dw 0x8000
    db 0x0B
    db 0x92
    db 0x40
    db 0x0

    dw 0xFFFF
    dw 0x0
    db 0x1
    db 0x9A
    db 0x0
    db 0x0

    dw 0xFFFF
    dw 0x0
    db 0x1
    db 0x92
    db 0x0
    db 0x0
; сегмент TSS задачи 0 (32-битный свободный TSS)
    dw 067h
    dw 0
    db 0
    db 10001001b
    db 01000000b
    db 0


label GDT_SIZE at $-gdt32
GDTR:
    dw GDT_SIZE-1
    dd gdt32+10000h


IDT:
;    dd 0x0, 0x0

;0:
    dw stub
    dw 0x0008
    db 0x0
    db 10101110b
    dw 0x0000

;1:
    ;dw stub
    dw print_handler
    dw 0x0008
    db 0x0
    db 10001110b
    dw 0x0000

;2:
    dw task_1
    dw 0x0008
    db 0x0
    db 10101110b
    dw 0x0000

;3:
    dw stub
    dw 0x0008
    db 0x0
    db 10101110b
    dw 0x0000

;4:
    dw stub
    dw 0x0008
    db 0x0
    db 10101110b
    dw 0x0000

;5:
    dw stub
    dw 0x0008
    db 0x0
    db 10101110b
    dw 0x0000

;6:
    dw stub
    dw 0x0008
    db 0x0
    db 10101110b
    dw 0x0000

;7:
    dw stub
    dw 0x0008
    db 0x0
    db 10101110b
    dw 0x0000

;8:
    dw int8_handler
    dw 0x0008
    db 0x0
    db 10001110b
    dw 0x0000

;9:
    dw stub
    dw 0x0008
    db 0x0
    db 10101110b
    dw 0x0000

;10:
    dw stub
    dw 0x0008
    db 0x0
    db 10101110b
    dw 0x0000

;11:
    dw stub
    dw 0x0008
    db 0x0
    db 10101110b
    dw 0x0000

;12:
    dw stub
    dw 0x0008
    db 0x0
    db 10101110b
    dw 0x0000

;13:
    dw exGP_handler
    dw 0x0008
    db 0x0
    db 10001110b
    dw 0x0000

;14:
    dw stub
    dw 0x0008
    db 0x0
    db 10101110b
    dw 0x0000

;15:
    dw stub
    dw 0x0008
    db 0x0
    db 10101110b
    dw 0x0000

;16:
    dw stub
    dw 0x0008
    db 0x0
    db 10101110b
    dw 0x0000

;17:
    dw stub
    dw 0x0008
    db 0x0
    db 10101110b
    dw 0x0000

;18:
    dw stub
    dw 0x0008
    db 0x0
    db 10101110b
    dw 0x0000

;19:
    dw stub
    dw 0x0008
    db 0x0
    db 10101110b
    dw 0x0000

;20:
    dw stub
    dw 0x0008
    db 0x0
    db 10101110b
    dw 0x0000

;21:
    dw stub
    dw 0x0008
    db 0x0
    db 10101110b
    dw 0x0000

;22:
    dw stub
    dw 0x0008
    db 0x0
    db 10101110b
    dw 0x0000

;23:
    dw stub
    dw 0x0008
    db 0x0
    db 10101110b
    dw 0x0000

;24:
    dw stub
    dw 0x0008
    db 0x0
    db 10101110b
    dw 0x0000

;25:
    dw stub
    dw 0x0008
    db 0x0
    db 10101110b
    dw 0x0000

;26:
    dw stub
    dw 0x0008
    db 0x0
    db 10101110b
    dw 0x0000

;27:
    dw stub
    dw 0x0008
    db 0x0
    db 10101110b
    dw 0x0000

;28:
    dw stub
    dw 0x0008
    db 0x0
    db 10101110b
    dw 0x0000

;29:
    dw stub
    dw 0x0008
    db 0x0
    db 10101110b
    dw 0x0000

;30:
    dw stub
    dw 0x0008
    db 0x0
    db 10001110b
    dw 0x0000

;31:
    dw stub
    dw 0x0008
    db 0x0
    db 10001110b
    dw 0x0000

;32:
    dw int8_handler
    dw 0x0008
    db 0x0
    db 10001110b
    dw 0x0000

;33:
    dw int9_handler
    dw 0x0008
    db 0x0
    db 10001110b
    dw 0x0000

IDTR:
    dw $ - IDT - 1 ; size (16 bits), always one less of its true size
    dd IDT + 0x1000 * 0x10

.real_pointer:
    dw 0x3FF
    dd 0x0



cursor   dd 0
SEL_TSS0           equ   101000b
SEL_TSS1           equ   110000b
