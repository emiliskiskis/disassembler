.model small
.stack 100h

.data

.code
start:
    mov ax, @data
    mov ds, ax
    xor ax, ax

    
    

    mov ax, 4C00h
    int 21h
end start