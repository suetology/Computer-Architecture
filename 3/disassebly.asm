.model small 
.stack 100h 

.data
    src_filename    db "src.com"
    src_filehandle  dw ?
    out_filename    db "out.asm"
    out_filehandle  dw ?

    src_buffer      db 256 dup(0)    ;si
    out_buffer      db 0, 0, 1000 dup(0)    ;di
    temp_buffer     db 256 dup(0)

    flag            db 0
    mod_offset      db 0, 0, 0
    reg_value       db 0
    rm_value        db 0
    w_value         db 0 
    d_value         db 0
    num_value       db 0, 0
    sr_value        db 0

    adress          dw 0100h
    si_start        dw 0

    byte_buffer     db 8 dup(0)
    regs_b          db "alcldlblahchdhbh"
    regs_w          db "axcxdxbxspbpsidiescsssds"
    memory          db 0, "bx+si", 1, "bx+di", 2, "bp+si", 3, "bp+di", 4, "si", 5, "di", 6, "bp", 7, "bx", 8
    xlat_name       db 4, "xlat"
    rcr_name        db 3, "rcr"
    not_name        db 3, "not"
    out_name        db 3, "out"
    mov_name        db 3, "mov"

.code
    mov dx, @data
    mov ds, dx

    call READ_SRC
    mov si, offset src_buffer 
    mov si_start, si
    mov di, offset temp_buffer

    main_loop:
        call WRITE_ADRESS
        call WRITE_COMMAND_CODE
        call TEMP_TO_OUT
        mov byte ptr flag, 0 
        call CHECK_XLAT
        cmp byte ptr flag, 1
        je main_loop
        call CHECK_RCR
        cmp byte ptr flag, 1
        je main_loop
        call CHECK_NOT
        cmp byte ptr flag, 1
        je main_loop
        call CHECK_OUT
        cmp byte ptr flag, 1
        je main_loop
        call CHECK_MOV1
        cmp byte ptr flag, 1
        je main_loop
        call CHECK_MOV2
        cmp byte ptr flag, 1
        je main_loop
        call CHECK_MOV3
        cmp byte ptr flag, 1
        je main_loop
        call CHECK_MOV4
        cmp byte ptr flag, 1
        je main_loop
        call CHECK_MOV5
        cmp byte ptr flag, 1
        je main_loop

    call CREATE_OUT_FILE
    call PRINT_BUFFER

    mov ah, 4ch
    int 21h  

proc READ_SRC
    mov ah, 3dh
    mov al, 0
    mov dx, offset src_filename
    int 21h
    mov src_filehandle, ax 

    mov ah, 3fh
    mov bx, src_filehandle 
    mov cx, 256
    mov dx, offset src_buffer
    int 21h
    ret
endp

proc CREATE_OUT_FILE
    mov ah, 3ch
    mov cx, 02h
    mov dx, offset out_filename
    int 21h 
    mov out_filehandle, ax
    ret 
endp

proc PRINT_BUFFER
    mov ah, 40h 
    mov bx, out_filehandle
    mov cx, word ptr out_buffer
    mov dx, offset out_buffer + 2
    int 21h
    ret
endp

proc TEMP_TO_OUT
    cmp word ptr flag, 0
    je return_moving
    mov di, offset temp_buffer
    mov bx, offset out_buffer + 2
    mov ax, word ptr out_buffer
    add bx, ax

    move_bytes:
        cmp byte ptr ds:[di], 0
        je end_moving
        mov al, byte ptr ds:[di]
        mov byte ptr ds:[bx], al
        inc di 
        inc bx
        jmp move_bytes 

    end_moving:
        mov ax, offset out_buffer + 2
        sub bx, ax
        mov word ptr out_buffer, bx
        call CLEAR_TEMP_BUFFER
    return_moving:
        ret 
endp

proc CLEAR_TEMP_BUFFER 
    mov cx, 256
    mov di, offset temp_buffer
    
    loop_clear:
        mov byte ptr ds:[di], 0
        inc di
        loop loop_clear
    
    mov di, offset temp_buffer
    ret 
endp 

proc CHECK_XLAT 
    cmp byte ptr ds:[si], 11010111b 
    jne return_xlat

    mov byte ptr flag, 1
    mov bx, offset xlat_name
    call WRITE_COMMAND_NAME
    call WRITE_NEW_LINE
    inc si

    return_xlat:
        ret
endp

proc CHECK_NOT 
    mov al, byte ptr ds:[si]
    and al, 11111110b
    cmp al, 11110110b
    jne return_not

    mov byte ptr flag, 1
    mov bx, offset not_name
    call WRITE_COMMAND_NAME
    
    call GET_MOD
    call GET_RM
    call GET_W

    call WRITE_RM
    call WRITE_NEW_LINE

    call SKIP_BYTES

    return_not:
        ret 
endp

proc CHECK_RCR
    mov al, byte ptr ds:[si]
    and al, 11111100b
    cmp al, 11010000b
    jne return_rcr

    mov byte ptr flag, 1
    mov bx, offset rcr_name
    call WRITE_COMMAND_NAME
    
    call GET_MOD
    call GET_RM
    call GET_W

    call WRITE_RM
    call WRITE_COMMA

    mov al, byte ptr ds:[si]
    and al, 00000010b
    cmp al, 00000000b 
    je write_1

    mov byte ptr w_value, 0
    mov byte ptr reg_value, 1
    call WRITE_REGISTER_NAME
    jmp rcr_end

    write_1:
        mov dl, '1'
        mov byte ptr ds:[di], dl
        inc di

    rcr_end:
        call WRITE_NEW_LINE
    
    call SKIP_BYTES

    return_rcr:
        ret 
endp

proc CHECK_OUT
    mov al, byte ptr ds:[si]
    and al, 11110110b
    cmp al, 11100110b
    jne return_out 

    mov byte ptr flag, 1
    mov bx, offset out_name 
    call WRITE_COMMAND_NAME

    mov al, byte ptr ds:[si]
    and al, 00001000b
    cmp al, 00000000b 
    jne dx_port 

    xor ax, ax
    mov al, byte ptr ds:[si + 1]
    mov dl, 16 
    div dl 
    call WRITE_HEX 
    mov al, ah 
    call WRITE_HEX
    mov byte ptr ds:[di], 'h'
    inc di

    jmp skip_port

    dx_port:
        mov byte ptr reg_value, 010b 
        mov byte ptr w_value, 1b
        call WRITE_REGISTER_NAME
    
    skip_port: 
        call WRITE_COMMA
    
    call GET_W
    mov byte ptr reg_value, 0 
    call WRITE_REGISTER_NAME

    call WRITE_NEW_LINE 

    mov al, byte ptr ds:[si]
    inc si 
    and al, 00001000b
    cmp al, 0
    jne return_out

    inc si 

    return_out:
        ret
endp

proc CHECK_MOV1
    mov al, byte ptr ds:[si]
    and al, 11111110b
    cmp al, 11000110b
    jne return_mov1

    mov byte ptr flag, 1
    mov bx, offset mov_name
    call WRITE_COMMAND_NAME

    call GET_W
    call GET_RM
    call GET_MOD 

    call WRITE_RM
    call WRITE_COMMA

    add si, 2

    cmp byte ptr mod_offset, 01b 
    je inc_si 
    cmp byte ptr mod_offset, 10b 
    je inc_si 
    cmp byte ptr mod_offset, 11b 
    je clear_mod

    cmp byte ptr rm_value, 110b 
    jne inc_si 

    mov byte ptr mod_offset, 10b
    jmp inc_si

    clear_mod:
        mov byte ptr mod_offset, 0

    inc_si:
        xor ax, ax 
        mov al, byte ptr mod_offset
        add si, ax
    
    
    mov bx, si
    call GET_NUM 
    call WRITE_NUM
    call WRITE_NEW_LINE

    xor ax, ax 
    mov al, byte ptr w_value
    add si, ax 
    inc si

    return_mov1:
        ret
endp

proc CHECK_MOV2 
    mov al, byte ptr ds:[si]
    and al, 11111100b
    cmp al, 10100000b
    jne return_mov2

    mov byte ptr flag, 1
    mov bx, offset mov_name
    call WRITE_COMMAND_NAME 

    mov byte ptr mod_offset, 00b
    mov al, byte ptr ds:[si + 1]
    mov byte ptr mod_offset + 2, al
    mov al, byte ptr ds:[si + 2]
    mov byte ptr mod_offset + 1, al 

    call GET_W
    call GET_D
    mov byte ptr rm_value, 110b

    cmp byte ptr d_value, 1
    jne mov2_register

    dec si 
    call WRITE_RM
    inc si 
    jmp mov2_second_operand

    mov2_register:
        mov byte ptr reg_value, 0
        call WRITE_REGISTER_NAME

    mov2_second_operand:
        call WRITE_COMMA

    cmp byte ptr d_value, 1
    jne mov2_memory

    mov byte ptr reg_value, 0
    call WRITE_REGISTER_NAME
    jmp mov2_end

    mov2_memory:
        dec si
        call WRITE_RM 
        inc si

    mov2_end:
        call WRITE_NEW_LINE
        add si, 3

    return_mov2:
    ret 
endp

proc CHECK_MOV3
    mov al, byte ptr ds:[si]
    and al, 11111100b
    cmp al, 10001000b
    jne return_mov3

    mov byte ptr flag, 1
    mov bx, offset mov_name
    call WRITE_COMMAND_NAME 

    call GET_D 
    call GET_W 
    call GET_MOD
    call GET_REG
    call GET_RM

    cmp byte ptr d_value, 0
    jne mov3_register

    call WRITE_RM
    jmp mov3_second_operand

    mov3_register:
        call WRITE_REGISTER_NAME

    mov3_second_operand:
        call WRITE_COMMA

    cmp byte ptr d_value, 0
    jne mov3_rm

    call WRITE_REGISTER_NAME
    jmp mov3_end

    mov3_rm:
        call WRITE_RM

    mov3_end:
        call WRITE_NEW_LINE
        call SKIP_BYTES

    return_mov3:
        ret     
endp 

proc CHECK_MOV4
    mov al, byte ptr ds:[si]
    and al, 11111101b
    cmp al, 10001100b
    jne return_mov4

    mov byte ptr flag, 1
    mov bx, offset mov_name
    call WRITE_COMMAND_NAME 

    mov byte ptr w_value, 1
    call GET_D
    call GET_MOD
    call GET_SR
    call GET_RM
    
    cmp byte ptr d_value, 1
    jne mov4_rm

    mov byte ptr reg_value, 8
    mov al, byte ptr sr_value
    add byte ptr reg_value, al
    call WRITE_REGISTER_NAME
    jmp mov4_second_operand

    mov4_rm:
        call WRITE_RM

    mov4_second_operand:
        call WRITE_COMMA

    cmp byte ptr d_value, 1
    jne mov4_register

    call WRITE_RM
    jmp mov4_end

    mov4_register:
        mov byte ptr reg_value, 8
        mov al, byte ptr sr_value
        add byte ptr reg_value, al
        call WRITE_REGISTER_NAME
    
    mov4_end:
        call WRITE_NEW_LINE
        call SKIP_BYTES
    return_mov4:
        ret 
endp

proc CHECK_MOV5
    mov al, byte ptr ds:[si]
    and al, 11110000b
    cmp al, 10110000b
    jne return_mov5

    mov byte ptr flag, 1
    mov bx, offset mov_name
    call WRITE_COMMAND_NAME  
    
    mov al, byte ptr ds:[si]
    and al, 00000111b
    mov byte ptr reg_value, al
    mov al, byte ptr ds:[si]
    and al, 00001000b
    shr al, 3
    mov byte ptr w_value, al

    call WRITE_REGISTER_NAME
    call WRITE_COMMA

    mov bx, si
    inc bx
    call GET_NUM
    call WRITE_NUM
    call WRITE_NEW_LINE

    add si, 2
    xor ax, ax 
    mov al, byte ptr w_value
    add si, ax

    return_mov5:
        ret
endp

proc SKIP_BYTES
    call GET_MOD
    call GET_RM
    add si, 2 

    cmp byte ptr mod_offset, 11b
    je return_skip 

    cmp byte ptr mod_offset, 00h 
    jne return_skip
    cmp byte ptr rm_value, 110b 
    jne return_skip 

    add si, 2

    return_skip:
        ret 
endp

proc GET_MOD
    mov al, byte ptr ds:[si + 1]
    and al, 11000000b 
    shr al, 6 

    mov bx, offset mod_offset
    mov byte ptr ds:[bx], al
    mov byte ptr ds:[bx + 1], 0
    mov byte ptr ds:[bx + 2], 0

    cmp al, 00000011b 
    je return_mod
    cmp al, 00000000b 
    je return_mod
    
    mov dl, byte ptr ds:[si + 2]
    mov byte ptr ds:[bx + 2], dl

    cmp al, 01b 
    je return_mod

    mov dl, byte ptr ds:[si + 3]
    mov byte ptr ds:[bx + 1], dl

    return_mod:
        ret 
endp

proc GET_REG
    mov al, byte ptr ds:[si + 1]
    and al, 00111000b
    shr al, 3
    mov reg_value, al
    ret
endp

proc GET_RM 
    mov al, byte ptr ds:[si + 1]
    and al, 00000111b 
    mov rm_value, al 
    ret
endp

proc GET_SR
    mov al, byte ptr ds:[si + 1]
    and al, 00011000b
    shr al, 3
    mov sr_value, al
    ret
endp

proc GET_W 
    mov al, byte ptr ds:[si]
    and al, 00000001b 
    mov w_value, al
    ret 
endp

proc GET_D 
    mov al, byte ptr ds:[si]
    and al, 00000010b
    shr al, 1
    mov d_value, al
    ret
endp

proc GET_NUM    ;gets num from ds:[bx]
    mov word ptr num_value, 0
    mov ax, word ptr ds:[bx]
    mov bx, offset num_value
    mov byte ptr ds:[bx + 1], al 
    
    cmp byte ptr w_value, 1 
    jne return_num

    mov byte ptr ds:[bx], ah

    return_num:
    ret 
endp

proc WRITE_NUM 
    xor ax, ax
    mov al, byte ptr num_value
    mov dl, 16 
    div dl 
    call WRITE_HEX 
    mov al, ah
    call WRITE_HEX 
    xor ax, ax
    mov al, byte ptr num_value + 1
    mov dl, 16 
    div dl 
    call WRITE_HEX 
    mov al, ah
    call WRITE_HEX 
    mov byte ptr ds:[di], 'h'
    inc di
    ret 
endp 

proc WRITE_RM 
    mov al, mod_offset
    cmp al, 00000011b
    je write_register

    call WRITE_MEMORY
    jmp return_write_rm

    write_register:
        xor ax, ax
        mov al, byte ptr reg_value
        push ax
        mov dl, byte ptr rm_value
        mov byte ptr reg_value, dl
        call WRITE_REGISTER_NAME
        pop ax
        mov byte ptr reg_value, al
    return_write_rm:
        ret 
endp

proc WRITE_REGISTER_NAME 
    cmp byte ptr w_value, 1
    je word_reg

    mov bx, offset regs_b
    jmp set_reg 

    word_reg: 
        mov bx, offset regs_w
    
    set_reg: 
    xor ax, ax 
    mov al, reg_value
    mov dl, 2
    mul dl 

    add bx, ax 
    
    mov dl, byte ptr ds:[bx]
    mov byte ptr ds:[di], dl 
    inc di
    inc bx
    mov dl, byte ptr ds:[bx]
    mov byte ptr ds:[di], dl 
    inc di

    ret 
endp 

proc WRITE_MEMORY
    mov dl, '['
    mov byte ptr ds:[di], dl
    inc di  

    cmp byte ptr rm_value, 6
    jne skip_exception
    cmp byte ptr mod_offset, 0
    je exception

    skip_exception:
        mov bx, offset memory
    
    search_memory:
        mov cl, byte ptr ds:[bx]
        cmp cl, byte ptr rm_value 
        je found_memory
        inc bx 
        jmp search_memory
    
    found_memory:
        inc cl 
        inc bx
    
    write_mem:
        mov dl, byte ptr ds:[bx]
        mov byte ptr ds:[di], dl
        inc di
        inc bx 
        cmp byte ptr ds:[bx], cl 
        je check_offset
        jmp write_mem

    check_offset:
        mov al, mod_offset
        cmp al, 00b
        je close_memory
        mov dl, '+'
        mov byte ptr ds:[di], dl
        inc di
        call WRITE_OFFSET

    close_memory:
        mov dl, ']'
        mov byte ptr ds:[di], dl
        inc di 
        jmp return_memory
    
    exception:
        mov bx, offset mod_offset

        mov dl, byte ptr ds:[si + 2]
        mov byte ptr ds:[bx + 2], dl
        mov dl, byte ptr ds:[si + 3]
        mov byte ptr ds:[bx + 1], dl

        call WRITE_OFFSET
        jmp close_memory

    return_memory:
        ret 
endp

proc WRITE_OFFSET   
    mov bx, offset mod_offset + 1
    mov cx, word ptr ds:[bx]

    xor ax, ax
    mov al, cl
    mov dl, 16  
    div dl 

    call WRITE_HEX
    mov al, ah 
    call WRITE_HEX

    xor ax, ax 
    mov al, ch
    mov dl, 16 
    div dl 

    call WRITE_HEX
    mov al, ah 
    call WRITE_HEX

    mov dl, 'h'
    mov byte ptr ds:[di], dl 
    inc di
    ret 
endp

proc WRITE_HEX  ;writes from al
    cmp al, 10
    jb write_number

    add al, 87
    mov byte ptr ds:[di], al
    inc di
    jmp return_hex

    write_number:
        add al, 48 
        mov byte ptr ds:[di], al
        inc di
    
    return_hex:
        ret 
endp

proc WRITE_COMMA 
    mov byte ptr ds:[di], ','
    inc di 
    ret 
endp

proc WRITE_NEW_LINE 
    mov byte ptr ds:[di], 13
    inc di
    mov byte ptr ds:[di], 10
    inc di 
    ret 
endp

proc WRITE_COMMAND_NAME ; bx - offset of command
    xor cx, cx 
    mov cl, byte ptr ds:[bx]
    inc bx  

    add_letter:
        mov al, byte ptr ds:[bx]
        mov byte ptr ds:[di], al 
        inc bx 
        inc di
        loop add_letter
    
        mov byte ptr ds:[di], 32 
        inc di 
    ret 
endp

proc WRITE_ADRESS 
    cmp word ptr flag, 0
    je return_adress
    push di

    mov di, offset out_buffer + 2
    mov ax, word ptr out_buffer
    add di, ax 

    mov bx, offset adress
    mov cl, byte ptr ds:[bx + 1]
    mov ch, byte ptr ds:[bx]

    xor ax, ax
    mov al, cl
    mov dl, 16  
    div dl 

    call WRITE_HEX
    mov al, ah 
    call WRITE_HEX

    xor ax, ax 
    mov al, ch
    mov dl, 16 
    div dl 

    call WRITE_HEX
    mov al, ah 
    call WRITE_HEX

    mov byte ptr ds:[di], 'h'
    inc di
    mov byte ptr ds:[di], ':'
    inc di 
    mov byte ptr ds:[di], ' '
    inc di 

    add word ptr out_buffer, 7

    pop di
    return_adress:
        ret
endp

proc WRITE_COMMAND_CODE
    cmp word ptr flag, 0
    je return_command

    push di
    mov bx, si_start 
    
    mov di, offset out_buffer + 2
    mov ax, word ptr out_buffer
    add di, ax 
    xor ch, ch

    write_command_byte:
        mov cl, byte ptr ds:[bx]
        xor ax, ax
        mov al, cl
        mov dl, 16  
        div dl 

        call WRITE_HEX
        mov al, ah 
        call WRITE_HEX

        mov byte ptr ds:[di], ' '
        inc di
        add ch, 3

        inc bx
        cmp bx, si 
        jne write_command_byte 

    mov cl, ch
    xor ch, ch 
    add word ptr out_buffer, cx 

    mov bx, si 
    sub bx, si_start
    add adress, bx
    mov si_start, si 

    pop di
    return_command:
        ret 
endp

end