.model small
.stack 100h

.data
    ifn db 13 dup (0)
    ofn db 13 dup (0)
    ifh dw ?
    ofh dw ?
    ;Strings
    open_if_error_msg db "Couldn't open input file", 0Dh, 0Ah, 24h
    create_of_error_msg db "Couldn't create output file", 0Dh, 0Ah, 24h

.code
start:
    mov ax, @data
    mov ds, ax
    xor ax, ax

read_pars:
    ;Logic: disasm [/?] [input file] [output file]
    xor ch, ch
    mov cl, [es:80h] ;par length
    cmp cl, 0

open_if:
    mov ax, 3D00h
    lea dx, ifn
    int 21h
    jc open_if_error
    mov ifh, ax
    jmp create_of

open_if_error:
    mov ah, 09h
    lea dx, open_if_error_msg
    int 21h

create_of:
    mov ax, 3C00h
    xor cx, cx
    lea dx, ofn
    int 21h
    jc create_of_error
    mov ofh, ax
    jmp main_logic

create_of_error:
    mov ah, 09h
    lea dx, create_of_error_msg
    int 21h

main_logic:
    nop

clean_exit:
    mov ax, 4C00h
    int 21h
end start