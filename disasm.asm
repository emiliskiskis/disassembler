.model small
.stack 100h

.data
    ifn db 13 dup (0)
    ofn db 13 dup (0)
    ifh dw ?
    ofh dw 1
    READ_LENGTH dw 1024
    PRINT_LENGTH dw 1024
    in_buff db 1024 dup (?)
    in_buff_end dw ?
    in_buff_length dw ?
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
    imm_val dw 0
    offset_val dw 0
    ;Strings
    ;Errors
    newline db 0Dh, 0Ah, 24h
    open_if_error_msg db "Couldn't open input file$"
    create_of_error_msg db "Couldn't create output file$"
    read_file_error_msg db "Error reading file$"
    ;Help text
    help_msg db "Usage: disasm [input file] [output file]", 0Dh, 0Ah, 9, "/?: show this help text", 0Dh, 0Ah, 9, "input file: source executable to be disassembled", 0Dh, 0Ah, 9, "output file: .asm file with disassembled code", 0Dh, 0Ah, 24h
    ;Instruction expressions
    special_symbols db " ,[]:+"
    registers db "alcldlblahchdhbhaxcxdxbxspbpsidi"
    ;Explanation on registers (each is two bytes):
    ;   for mod=11 or reg=000->111:
    ;   w=0: registers[0:16]
    ;   w=1: registers[17:32]
    ;   Sequence is AL CL DL BL AH CH DH BH
    ;               AX CX DX BX SP BP SI DI
    rm_0_registers db "bx+sibx+dibp+sibp+di"
    rm_4_registers db "sidibpbx"
    segments db "escsssds"
    is_byte db "byte ptr "
    is_word db "word ptr "
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
    je skip_read_ofn
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
    skip_read_ofn:

    mov ax, ds
    mov es, ax
    xor ax, ax

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
        call CheckInstruction

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

proc CheckInstruction
    ;MOV instruction
    mov dl, byte ptr [si]
    mov al, dl
    xor al, 10001000b
    cmp al, 4
    jae skip_mov_1
    call parse_mov_1
    jmp cont_main_loop
    skip_mov_1:
    mov al, dl
    xor al, 11000110b
    cmp al, 2
    jae skip_mov_2
    call parse_mov_2
    jmp cont_main_loop
    skip_mov_2:
    mov al, dl
    xor al, 10110000b
    cmp al, 2
    jae skip_mov_3
    call parse_mov_3
    jmp cont_main_loop
    skip_mov_3:
    ;parse_mov_45 has d flag inverted
    mov al, dl
    xor al, 10100000b
    cmp al, 4
    jae skip_mov_45
    call parse_mov_45
    jmp cont_main_loop
    skip_mov_45:

    ret
endp CheckInstruction

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

proc CheckBuffer
    push ax

    mov ax, out_buff_i
    add ax, cx
    cmp ax, PRINT_LENGTH
    jbe checkbuffer_skip_print
    call Print
    checkbuffer_skip_print:

    pop ax
    ret
endp CheckBuffer

;Push cx characters from ds:si to output buffer (es:di)
proc PushToBuffer
    call CheckBuffer
    add out_buff_i, cx
    rep movsb

    ret
endp PushToBuffer

;Push special symbol from db special_symbols, bx is index
proc PushSpecialSymbol
    push si
    mov cx, 1
    call CheckBuffer
    lea si, special_symbols+bx
    call PushToBuffer
    pop si
    ret
endp PushSpecialSymbol

proc PushHexValue
    ;dx is word value to be pushed
    push ax
    mov cx, 5
    call CheckBuffer

    cmp dh, 0
    je pushhexvalue_byte
    mov al, dh
    and al, 0F0h
    shr al, 4
    add al, 30h
    mov byte ptr [di], al
    inc di
    
    mov al, dh
    and al, 0Fh
    add al, 30h
    mov byte ptr [di], al
    inc di

    add out_buff_i, 2

    pushhexvalue_byte:
    mov al, dl
    and al, 0F0h
    shr al, 4
    add al, 30h
    mov byte ptr [di], al
    inc di

    mov al, dl
    and al, 0Fh
    add al, 30h
    mov byte ptr [di], al
    inc di
    
    mov byte ptr [di], "h"
    inc di

    add out_buff_i, 3

    pop ax
    ret
endp PushHexValue

proc PushNewline
    mov cx, 2
    call CheckBuffer

    mov byte ptr [di], 13
    inc di
    mov byte ptr [di], 10
    inc di

    add out_buff_i, 2
    ret
endp PushNewline

;Print text until $ and then add a newline
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

proc read_bytes
    xor dh, dh
    inc si
    mov dl, [si]
    cmp mod_val, 01b
    je read_b_offset
    inc si
    mov dh, [si]
    read_b_offset:

    ret
endp

;Parse 111111dw mod reg r/m [b/w offset]
proc parse_dwmodregrm
    ;w_val
    mov al, dl
    and al, 1b
    mov w_val, al

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

    ret
endp parse_dwmodregrm

proc parse_reg
    push si

    lea si, registers
    cmp w_val, 0
    je parse_reg_skip_add
    add si, 8
    parse_reg_skip_add:
    add si, si
    mov cx, 2
    call PushToBuffer
    mov bx, 1
    call PushSpecialSymbol
    mov bx, 0
    call PushSpecialSymbol
    pop si

    ret
endp parse_reg

proc parse_rm
    cmp mod, 11b
    jne parse_rm_skip_mod11
    call parse_reg
    ret
    ;mod < 11b
    parse_rm_skip_mod11:
    cmp rm_val, 4
    jb parse_rm_0
    ;parse_rm_4:
    cmp rm_val, 110b
    jne parse_rm_skip_direct
    cmp mod, 00b
    jne parse_rm_skip_direct
    call read_bytes
    call PushHexValue
    ret
    parse_rm_skip_direct:
    push si
    lea si, rm_0_registers
    mul si, 5
    mov cx, 5
    call PushToBuffer
    pop si
    
    cmp mod, 00b
    jne parse_rm_offset
    ret
    parse_rm_offset:
    call 
    parse_rm_0:
    
    ret
endp parse_rm

proc parse_mov
    push si

    mov cx, 3
    lea si, com_3_main
    call PushToBuffer
    mov bx, 0
    call PushSpecialSymbol

    pop si
    ret
endp parse_mov

proc parse_mov_1
    xor bx, bx

    call parse_dwmodregrm
    call parse_mov
    cmp d_val, 1
    je parse_mov_1_d1
    ;parse_mov_1_d0:
    call parse_rm
    call parse_reg
    ret
    parse_mov_1_d1:
    call parse_reg
    ;Format becomes mov_XX,_ (_ is space)
    call parse_rm
    call PushNewline
    
    ret
endp parse_mov_1

proc parse_mov_2
    call parse_dwmodregrm
    ret
endp parse_mov_2

proc parse_mov_3
    ret
endp parse_mov_3

proc parse_mov_45
    ret
endp parse_mov_45

end start