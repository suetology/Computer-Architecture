.model small
.stack 100h

.data
    filename            db "lab.txt"
    filehandle          dw ?

    last_frame          db 00h  ;naudojama laiko fiksavimui

    cell_size           db 0ah
    pixel_pos_x         dw 00h
    pixel_pos_y         dw 00h
    grid                db 1000 dup(0), 0
    grid_width          db ?

    player_x            db 01h
    player_y            db 01h
    player_color        db 02h
    player_boosted      db 00h  ;1 kai true, 0 kai false
    monster_x           db 0ah
    monster_y           db 0ah
    monster_direction   db 00h
    boost_x             db 08h
    boost_y             db 09h

    game_active         db 01h
    game_won            db 00h   
    win_msg             db "You won :)", 13, 10, '$'
    lose_msg            db "You lose :(", 13, 10, '$' 

.code
    mov dx, @data
    mov ds, dx

    mov ah, 3dh     
    mov al, 0
    mov dx, offset filename
    int 21h

    mov filehandle, ax 

    mov ah, 3fh
    mov bx, filehandle          
    mov cx, 1000
    mov dx, offset grid
    int 21h                 ;nuskaitau labirinta is failo

    mov ah, 3eh
    mov bx, filehandle 
    int 21h

    call CALCULATE_WIDTH

render:
    call PICKUP_BOOST   ;tikrina, ar zaidejai pasieme boost'a
    call CHECK_MONSTER  ;tikrina, ar zaidejas susidure su monstru
    call CLEAR_SCREEN 
    call DRAW_GRID
    call DRAW_PLAYER
    call DRAW_MONSTER
    call DRAW_BOOST

check_frame:
    cmp game_active, 00h
    je game_over    

    call MOVE_PLAYER    
    cmp ax, 0abcdh      ;   procedura patalpina i ax 0h jeigu zaidejas nepajudejo, arba 0abcdh, jeigu pajudejo
    je render           ;   jeigu pajudejo, viska piesia is naujo

    mov ah, 2ch         ;   gauna laika, dh = sekundes
    int 21h

    cmp dh, last_frame  ;   tikrina, ar praejo sekunde nuo paskutinio uzfiksuoto laiko 
    je check_frame 

    mov last_frame, dh  ;   jeigu sekunde praejo, fiksuoja ja, ir pajudina monstra (montras judes kas sekunde)
    call MOVE_MOSTER    
    jmp render          ;   kai pajudejo, viska piesia is naujo

game_over:
    call CLEAR_SCREEN

    mov ah, 02h
    mov bh, 00h 
    mov dh, 04h 
    mov dl, 04h
    int 10h              ;  keicia kursoro posicija, kad tekstas atsirastu arciau ekrano centro

    mov ah, 09h
    cmp game_won, 01h
    je show_win_msg
    jmp show_lose_msg

show_win_msg:
    mov dx, offset win_msg
    jmp print

show_lose_msg:
    mov dx, offset lose_msg

print:
    int 21h
    
    mov ah, 4ch
    int 21h

proc CLEAR_SCREEN
    mov ah, 00h             
    mov al, 13h
    int 10h             ;   nustato video rezima 13h, skirta darbui su grafika (320 x 200)

    mov ah, 0bh
    mov bh, 00h         
    mov bl, 00h
    int 10h             ;   uzpildo ekrana juoda spalva
    ret
endp

proc MOVE_PLAYER 
    mov ah, 01h         
    int 16h             ;   tikrina, ar buvo paspausta bet kokia klavisa
    jnz continue        ;jei taip, apdoroju, kokia klavisa buvo paspausta
    xor ax, ax          ;jei ne, grazinu ax su reiksme 0
    ret

    continue:
        mov ah, 00h
        int 16h         ;   gaunu, kokia klavisa buvo paspausta

        cmp al, 'w'
        je check_up
        cmp al, 's'
        je check_down
        cmp al, 'a'
        je check_left
        cmp al, 'd'
        je check_right
        xor ax, ax
        ret

    check_up:
        mov al, grid_width    
        mov dl, player_y 
        dec dl                      ;   gaunu virsutini langeli grid bufferyje
        mul dl                      ;(y - 1) * grid_width + x
        mov bx, offset grid         
        add bx, ax
        xor ax, ax
        mov al, player_x
        add bx, ax
        cmp byte ptr ds:[bx], ' '   ;   tikrinu, ar pro ji galima praeiti,
        je move_up                  ;jei taip, judu i virsu
        ret
    move_up:                        
        dec player_y
        mov ax, 0abcdh              ;   grazinu ax su reiksme 0abcdh
        ret

    check_down:
        mov al, grid_width
        mov dl, player_y 
        inc dl
        mul dl
        mov bx, offset grid
        add bx, ax
        xor ax, ax
        mov al, player_x
        add bx, ax
        cmp byte ptr ds:[bx], ' '
        je move_down
        ret
    move_down:
        inc player_y
        mov ax, 0abcdh
        ret

    check_right:    
        mov al, grid_width
        mov dl, player_y
        mul dl
        mov bx, offset grid
        add bx, ax
        xor ax, ax
        mov al, player_x
        add bx, ax
        inc bx
        cmp byte ptr ds:[bx], ' '
        je move_right
        ret
    move_right:
        inc player_x 
        mov ax, 0abcdh
        ret

    check_left:
        mov al, grid_width
        mov dl, player_y 
        mul dl
        mov bx, offset grid
        add bx, ax
        xor ax, ax
        mov al, player_x
        add bx, ax
        dec bx
        cmp byte ptr ds:[bx], ' '
        je move_left
        ret
    move_left:
        dec player_x
        mov ax, 0abcdh
        ret
endp 

proc MOVE_MOSTER
    jmp start                           ;   pradzioje praleidziu krypties generacija, 
    recalculate_direction:              ;kad montras eitu tiesiai, kol nesusidurs su kliutim
        call RAND                       ;   pseudo-atsitiktinai generuoju monstro krypti 

    start:
        cmp monster_direction, 0      
        je check_up_m
        cmp monster_direction, 1
        je check_right_m
        cmp monster_direction, 2
        je check_down_m
        cmp monster_direction, 3
        je check_left_m
        jmp recalculate_direction
    
    check_up_m:
        mov al, grid_width
        mov dl, monster_y 
        dec dl
        mul dl
        mov bx, offset grid
        add bx, ax
        xor ax, ax
        mov al, monster_x 
        add bx, ax
        cmp byte ptr ds:[bx], ' '           ;   kaip ir su zaideju, tikrina, ar gali montras praeiti
        je move_up_m
        jmp recalculate_direction           ;   bet jeigu montras negali praeiti, generuoja krypti is naujo
    move_up_m:
        dec monster_y
        ret

    check_down_m:
        mov al, grid_width
        mov dl, monster_y 
        inc dl
        mul dl
        mov bx, offset grid
        add bx, ax
        xor ax, ax
        mov al, monster_x
        add bx, ax
        cmp byte ptr ds:[bx], ' '
        je move_down_m
        jmp recalculate_direction
    move_down_m:
        inc monster_y
        ret

    check_right_m: 
        mov al, grid_width
        mov dl, monster_y
        mul dl
        mov bx, offset grid
        add bx, ax
        xor ax, ax
        mov al, monster_x
        add bx, ax
        inc bx
        cmp byte ptr ds:[bx], ' '
        je move_right_m
        jmp recalculate_direction
    move_right_m:
        inc monster_x 
        ret

    check_left_m:
        mov al, grid_width
        mov dl, monster_y 
        mul dl
        mov bx, offset grid
        add bx, ax
        xor ax, ax
        mov al, monster_x
        add bx, ax
        dec bx
        cmp byte ptr ds:[bx], ' '
        je move_left_m
        jmp recalculate_direction
    move_left_m:
        dec monster_x
        ret
endp 

proc DRAW_PLAYER
    mov cl, player_x            
    mov dl, player_y 
    mov al, player_color
    call DRAW_CELL
    ret
endp

proc DRAW_MONSTER
    mov cl, monster_x
    mov dl, monster_y 
    mov al, 04h
    call DRAW_CELL
    ret
endp

proc CHECK_MONSTER
    mov ah, player_x
    mov al, player_y
    cmp ah, monster_x
    jne return_c
    cmp al, monster_y 
    jne return_c

    mov game_active, 00h        ;   kai montras susidure su zaideju, zaidimas baigiasi

    cmp player_boosted, 00h     ;   tikrina, ar buvo zaidejas boostintas, jei taip - laimi, jei ne - pralaimi
    je lose
    jmp win

    win: 
        mov game_won, 01h
        jmp return_c
    lose:
        mov game_won, 00h

    return_c:
        ret
endp

proc DRAW_BOOST
    cmp boost_x, 0ffh           ;   jeigu boost'as jau buvo paimtas (boost_x = 0ffh), jo piest nereikia
    je return 
    mov cl, boost_x 
    mov dl, boost_y 
    mov al, 0dh
    call DRAW_CELL

    return:
        ret 
endp

proc PICKUP_BOOST
    mov ah, player_x
    mov al, player_y
    cmp ah, boost_x
    jne return_pickup
    cmp al, boost_y
    jne return_pickup
    
    mov player_color, 03h       ;   tikrina, ar susidure zaidejas su boost'u, jei taip, keicia jo spalva,
    mov player_boosted, 01h     ;busena
    mov boost_x, 0ffh           ;ir slepia boost'a
    return_pickup:
        ret
endp

proc DRAW_GRID
    mov si, offset grid             ;   pagal grid buffer'i piesia labirinta po viena langeli
    dec si
    xor cx, cx                      ;   istustina cx ir dx, nes su ju pagalba ciklas
    xor dx, dx                      ;pies langelius atitinkamose pozicijose

    draw_grid_horizontal:   
        inc si                      ;   kiekviena iteracija inkrementina si, kad patikrinti visa buffer'i
        cmp byte ptr ds:[si], 10    ;   jeigu sutinka carriage return'a, reiskia laikas piesti kita eilute
        je increment_y              
        ;cmp byte ptr ds:[si], 10    ;   kadangi new line simbolis eina ir karto po carriage return'o, ji   
        ;je draw_grid_horizontal     ;paprasciausiai praleidziu
        cmp byte ptr ds:[si], 0     ;   jeigu sutinku null simboli, reiskia buffer'is baigesi
        je return_draw
        cmp byte ptr ds:[si], 49    ;   jeigu sutinku '1' simboli, reikia nupiesti siena
        jne increment_x             ;   jeigu sutinku dar kita simboli, tiketinai space'a, paprasciausiai
                                    ;einu tikrinti kita langeli
        mov al, 0fh                 ;   nustato balta spalva
        push cx                     ;   push'ina cx ir dx, kad issaugoti x ir y pozicijas 
        push dx 
        call DRAW_CELL              ;   piesia langeli, pries kvieciant reikia i al patalpinti norima spalva,
        pop dx                      ;i cl - x pozicija labirinto atzvilgiu, i dl - y pozicija
        pop cx

        increment_x:                
            inc cl                  ;   kiekvina karta inkremenntina x
            jmp draw_grid_horizontal
        increment_y:
            xor cl, cl              ;   kai pereina i kita eile inkrementina y ir isnulina x
            inc dl
            jmp draw_grid_horizontal
    return_draw:
        ret
endp

proc DRAW_CELL                      ;   piesia langeli cell_size dydzio 
    push ax                         ;   push'ina ax, nes al'e yra langelio spalva
    mov al, cl                      
    mov ch, cell_size
    mul ch
    mov cx, ax
    mov pixel_pos_x, cx              

    mov al, dl
    mov dh, cell_size
    mul dh
    mov dx, ax  
    mov pixel_pos_y, dx             ;   skaiciuoja langelio virsutinio kairiojo kampo x ir y pozicijas ekrano
                                    ;atzvilgiu (pikseliu atzvilgiu) ir issaugoja jas pixel_pos_x ir pixel_pos_y
    draw_cell_horizontal:
        pop ax                      ;   pop'ina ax, kad gauti spalva
        mov ah, 0ch                 
        mov bh, 00h
        int 10h                     ;   piesia pikseli pozicijoje (cx; dx)
        push ax

        inc cx                      ;   inkrementina x
        mov ax, cx
        sub ax, pixel_pos_x         ;   atima nuo gautos x pozicijos, langelio pirmojo pikselio x reikme
        xor bh, bh                  ;(pixel_pos_x), kad gauti reiksme, kiek jau pikseliu buvo nupiesta eileje, ir 
        mov bl, cell_size           ;jeigu ju kiekis virsija cell_size, pereina i kita eile
        cmp ax, bx        
        jb draw_cell_horizontal

        inc dx                      ;   inkrementina y
        mov cx, pixel_pos_x         ;   grazina i cx virsutinio pikselio pozicija pixel_pos_y
        mov ax, dx               
        sub ax, pixel_pos_y
        xor bh, bh
        mov bl, cell_size 
        cmp ax, bx 
        jb draw_cell_horizontal 
    pop ax
    ret
endp

proc RAND
    mov ah, 2ch             ;   gauna laika
    int 21h 
    
    xor ax, ax              
    mov al, dl              ;   i dl eina 1/100 sekundes dalis 
    mov dl, 4               ;   dalinu ja is 4 
    div dl  
    mov monster_direction, ah      ;    issaugoju dalybos liekana kaip nauja krypti
    ret
endp

proc CALCULATE_WIDTH
    mov si, offset grid             ;   su si iteruoja pro visa grid buffer'i

    count:  
        mov bl, byte ptr ds:[si]    ;   kai sutinka carriage return'a - skaiciuoja
        cmp bl, 10
        je calculate
        inc si
        jmp count

    calculate:
        mov bx, offset grid         
        sub si, bx              ;   atima nuo si, kuris yra lygus offset grid + grid plotis, offset'a, kad gauti ploti
        add si, 1               ;   prideda 2, nes tam, kad kiti skaiciavimai butu teisingi reikia uzskaityti 
        mov bx, si              ;carriage return'a ir new line'a
        mov grid_width, bl
        ret
endp
end