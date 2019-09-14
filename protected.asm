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

    mov ax, 3
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
    ; lidt [IDTR]

    call set_PE 

    ; jmp $
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

    pushad

    lo1:                     
        lodsb
        test al, al
        jz   .ex1
        stosb
        mov  al, 7
        stosb
        jmp  lo1

    .ex1:
    popad


    add  edi, 0xA0 
    mov  esi, hi_real  

    pushad
    lo2:                     
        lodsb
        test al, al
        jz   .ex2
        stosb
        mov  al, 7
        stosb
        jmp  lo2

    .ex2:
    popad

    call disable_interrupts
        
    jmp fword 32:protected_mode_exiting
 
    ; jmp $

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
    

    in         al,70h              ; индексный порт CMOS
    and        al,07Fh             ; сброс бита 7 отменяет блокирование NMI
    out        70h,al

    
    jmp $


hi_real db 'Hello from Real', 0
hi_string db 'Hello from Protected', 0


;========================================
;; Таблица дескрипторов
;========================================
align   8

gdt32:
    dd 0x0, 0x0 ; null descriptor


    ; code segment
    dw 0xFFFF ; segment length, bits 0-15
    dw 0x0    ; segment base, bits 0-15
    db 0x1    ; segment base, bits 16-23
    db 0x9A   ; flags (8 bits)
    ;1   00   1  101   0
    ;P   DPL  S  TYPE  A
    db 0x40   ; flags (4 bits) + segment length, bits 16-19
    ;0100 0000
    ;GDXU
    db 0x0    ; segment base, bits 24-31

    
    ; data32 segment read&write
    dw 0xFFFF
    dw 0x0
    db 0x1
    db 0x92
    ;1   00   1  001   0
    ;P   DPL  S  TYPE  A
    db 0xCF ; db 0x40
    ;1100 1111
    ;GDXU   
    db 0x0

    
    ; data32 segment read&write (video segment)
    dw 0xFFFF
    dw 0x8000
    db 0x0B
    db 0x92
    db 0x40
    ;0100 0000
    ;GDXU
    db 0x0

    ; code16 segment
    dw 0xFFFF
    dw 0x0
    db 0x1
    db 0x9A
    db 0x0
    db 0x0

    ; data16 segment 
    dw 0xFFFF
    dw 0x0
    db 0x1
    db 0x92
    db 0x0
    db 0x0

label GDT_SIZE at $-gdt32
GDTR:
    dw GDT_SIZE-1
    dd gdt32+10000h




