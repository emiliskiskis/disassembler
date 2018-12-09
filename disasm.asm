.model small
.stack 100h

.data
    ifn db 13 dup (0)
    ofn db 13 dup (0)
    ifh dw ?
    ofh dw 1
    in_buff db 1024 dup (?)
    in_buff_end dw ?
    in_buff_length dw ?
    READ_LENGTH dw 1024
    out_buff db 1024 dup (?)
    out_buff_i dw 0
    ;Disassembler logic
    d_val db 0
    w_val db 0
    reg_val db 0
    mod_val db 0
    rm_val db 0
    sreg_val db 0
    s_val db 0
    b_imm_val db 0
    w_imm_val dw 0
    b_offset_val db 0
    w_offset_val dw 0
    ;Strings
    ;Errors
    newline db 0Dh, 0Ah, 24h
    open_if_error_msg db "Couldn't open input file$"
    create_of_error_msg db "Couldn't create output file$"
    read_file_error_msg db "Error reading file$"
    ;Help text
    help_msg db "Usage: disasm [input file] [output file]", 0Dh, 0Ah, 9, "/?: show this help text", 0Dh, 0Ah, 9, "input file: source executable to be disassembled", 0Dh, 0Ah, 9, "output file: .asm file with disassembled code", 0Dh, 0Ah, 24h
    ;Instruction expressions
    registers db "alcldlblahchdhbhaxcxdxbxspbpsidi"
    ;Explanation on registers (each is two bytes):
    ;   for mod=11 or reg=000->111:
    ;   w=0: registers[0:16]
    ;   w=1: registers[17:32]
    ;   Sequence is AL CL DL BL AH CH DH BH
    ;               AX CX DX BX SP BP SI DI
    ;Two-letter commands
    com_2_main db "in"
    com_2_lgic db "or"
    com_2_jmps db "jajbjejgjljpjojs"
    ;Three-letter commands
    com_3_main db "movpopoutlealdsles"
    com_3_arit db "addadcincsubsbbdeccmpmuldivneg"
    com_3_deci db "aaadaaaasdasaamaad"
    com_3_conv db "cbwcwd"
    com_3_lgic db "notshlshrsarrolrorrclrcrandxor"
    com_3_strs db "rep"
    com_3_call db "ret"
    com_3_jmps db "jmpjaejbejgejlejnejnojnpjns"
    com_3_intr db "int"
    com_3_sync db "clcstccmccldstdclistihltesc"
    ;Four-letter commands
    com_4_main db "pushxchgxlatlahfsahfpopf"
    com_4_arit db "imulidiv"
    com_4_lgic db "test"
    com_4_strs db "movscmpsscaslodsstos"
    com_4_call db "call"
    com_4_jmps db "jcxz"
    com_4_cycl db "loop"
    com_4_intr db "iret"
    com_4_sync db "waitlock"
    ;Five-letter commands
    com_5_main db "pushf"
    com_5_strs db "repne"
    com_5_cycl db "loope"
    ;Six-letter commands
    com_6_cycl db "loopne"

;in or ja jb je jg jl jp jo js
;mov pop out lea lds les add adc inc sub sbb dec cmp mul div neg
;    aaa daa aas das aam aad cbw cwd not shl shr sar rol ror rcl
;    rcr and xor rep ret jmp jae jbe jge jle jne jno jnp jns int
;    clc stc cmc cld std cli sti hlt esc

;push xchg xlat lahf sahf popf imul idiv test movs cmps scas lods
;    stos call jcxz loop iret wait lock

;pushf repne loope

;loopne

.code
start:
    mov ax, @data
    mov ds, ax
    xor ax, ax
    jmp read_pars

do_help:
    mov ah, 09h
    lea dx, help_msg
    int 21h
;clean_exit:
    mov ax, 4C00h
    int 21h

read_pars:
    ;Logic: disasm [/?] [input file] (output file)
    xor ch, ch
    mov cl, [es:80h] ;par length
    cmp cl, 0
    je do_help
    dec cl
    mov si, 82h
    cmp word ptr [es:si], "?/"
    je do_help
    read_ifn:
        lea di, ifn
        read_ifn_loop:
            mov dl, byte ptr [es:si]
            cmp dl, " "
            je end_read_ifn
            mov [di], dl
            inc si
            inc di
        loop read_ifn_loop
    end_read_ifn:
    cmp cl, 0
    je open_if
    inc si
    read_ofn:
        lea di, ofn
        read_ofn_loop:
            mov dl, byte ptr [es:si]
            cmp dl, 0
            je open_if
            cmp dl, 0Dh
            je open_if
            mov [di], dl
            inc si
            inc di
        loop read_ofn_loop

open_if:
    mov ax, 3D00h
    lea dx, ifn
    int 21h
    jc open_if_error
    mov ifh, ax
    jmp create_of

open_if_error:
    lea dx, open_if_error_msg
    call PrintText

create_of:
    mov ax, 3C00h
    xor cx, cx
    lea dx, ofn
    int 21h
    jc create_of_error
    mov ofh, ax
    jmp main_logic

create_of_error:
    lea dx, create_of_error_msg
    call PrintText

main_logic:
    call Read
    lea di, out_buff
    xor ax, ax
    xor bx, bx
    xor cx, cx
    xor dx, dx

    main_loop:
        ;MOV instruction
        mov dl, byte ptr [si]
        mov al, dl
        xor al, 10001000b
        cmp al, 4
        jae skip_001
        call parse_mov_1
        jmp cont_main_loop
        skip_001:
        mov al, dl
        xor al, 11000110b
        cmp al, 2
        jae skip_002
        ;call parse_mov_2
        jmp cont_main_loop
        skip_002:
        mov al, dl
        xor al, 10110000b
        cmp al, 16
        jae skip_003
        ;call parse_mov_3
        jmp cont_main_loop
        skip_003:
        xor al, dl
        xor al, 10100000b
        cmp al, 2
        jae skip_004
        ;call parse_mov_4
        jmp cont_main_loop
        skip_004:

        ;Increase input buffer iterator (si) address and check for read and print req's
        cont_main_loop:
            inc si
            cmp si, in_buff_end
            jb skip_read
            cmp in_buff_length, 1024
            jb exit_main_loop
            call Read
            cmp in_buff_length, 0
            je exit_main_loop
            skip_read:
            cmp out_buff_i, 1024
            jb skip_print
            call Print
            skip_print:
    jmp main_loop
    exit_main_loop:
    ;Flush buffers after exit
    call Print

clean_exit:
    mov ax, 4C00h
    int 21h

proc Read
    push ax
    push bx
    push cx
    push dx
    
    mov ah, 3Fh
    mov bx, ifh
    mov cx, READ_LENGTH
    lea dx, in_buff
    int 21h
    jnc read_file_success
    read_file_error:
    mov ah, 09h
    lea dx, read_file_error_msg
    int 21h
    ;end

    read_file_success:

    lea si, in_buff
    mov in_buff_end, si
    add in_buff_end, ax
    mov in_buff_length, ax
    
    pop dx
    pop cx
    pop bx
    pop ax
    ret
endp Read

;Print current amount of characters from output buffer to output file, reset di to beginning
proc Print
    push ax
    push bx
    push cx
    push dx
    
    mov ah, 40h
    mov bx, ofh
    mov cx, out_buff_i
    lea dx, out_buff
    int 21h

    mov out_buff_i, 0
    lea di, out_buff

    pop dx
    pop cx
    pop bx
    pop ax
    ret
endp Print

;Right now to STD until $, will improve to output buffer with checks and everything
proc PrintText
    push ax

    mov ah, 09h
    ;dx required before call
    int 21h
    lea dx, newline
    int 21h

    pop ax
    ret
endp PrintText

proc read_b_offset_val
    push dx
    inc si
    mov dl, [si]
    mov b_offset_val, dl
    pop dx
    ret
endp

proc read_w_offset_val
    push dx
    inc si
    mov dl, [si]
    inc si
    mov dh, [si]
    mov w_offset_val, dx
    pop dx
    ret
endp

proc parse_mov_1
    ;w_val
    mov al, dl
    and dl, 1b
    mov w_val, dl

    ;d_val
    mov al, dl
    and al, 10b
    shr al, 1
    mov d_val, al
    
    ;Next byte!
    inc si
    mov dl, byte ptr [si]

    ;mod_val
    mov al, dl
    and al, 11000000b
    shr al, 6
    mov mod_val, al

    ;reg_val
    mov al, dl
    and al, 111000b
    shr al, 3
    mov reg_val, al

    ;rm_val
    mov al, dl
    and al, 111b
    mov rm_val, al

    cmp mod_val, 01b
    jne mov_1_mod_cont
    call read_b_offset_val
    jmp no_offset
    mov_1_mod_cont:
    cmp mod_Val, 10b
    jne no_offset
    call read_w_offset_val
    no_offset:

    ret
endp parse_mov_1

end start