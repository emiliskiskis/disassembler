mov dx, [bp+si+A5D2h]
mov [bx+si], AA03h
mov ax, 4C00h
mov ax, es:[4C00h]
mov ds:[4C00h], ax
mov ds, dx
