.model small
.stack 100h

.data
	start_msg db "Programa, kuri nuskaito simboliu eilute ir atspausdina pozicijas simboliu, sutampanciu su pirmuoju", 13, 10, 24h
	task_msg  db "Enter text: $"
	buffer    db 255, ?, 255 dup(?) 
	new_line  db 13, 10, 24h
.code
start:
	mov dx, @data
	mov ds, dx
	
	mov dx, offset start_msg
	mov ah, 09h
	int 21h
	
	mov dx, offset buffer
	mov ah, 0ah
	int 21h

	mov dx, offset new_line
	mov ah, 09h
	int 21h
	
	xor cx, cx
	mov cl, ds:[buffer + 1]  	;patalpinu i cl buferio antra elementa, kuris yra lygus nuskaitytu simboliu kiekiui
	cmp cx, 00h						
	je close					
	xor bx, bx					
	mov bx, offset buffer + 2	;bx naudojamas kaip buferio iteratorius 
	jmp check
	
check:
	inc bx
	mov al, ds:[buffer + 2]		;patalpinu i al nuskaitytos eilutes pirma elementa
	cmp al, ds:[bx]				;ir lyginu ji su kiekvienu sekanciu elementu
	je print
	loop check
	jmp close

print:
	push bx						;siunciu bx i stack'a, kad issaugoti jo reiksme
	sub bx, offset buffer + 2	;minusuoju buferio offset'a, kad bx'e liktu elemento numeris nuskaitytoje eiluteje
	cmp bx, 10	
	jb one_digit
	cmp bx, 100
	jb two_digit				
	jmp three_digit

one_digit:
	mov dx, bx
	add dx, 30h					
	mov ah, 02h
	int 21h
	pop bx
	
	mov dx, 20h
	mov ah, 02h
	int 21h
	loop check

two_digit:
	mov ax, bx
	mov dl, 10
	div dl
	push ax
	mov dl, al
	add dl, 30h
	mov ah, 02h
	int 21h

	pop ax
	mov dl, ah
	add dl, 30h
	mov ah, 02h
	int 21h
	pop bx

	mov dx, 20h
	mov ah, 02h
	int 21h
	loop check

three_digit:
	mov ax, bx
	mov dl, 100
	div dl
	push ax
	mov dl, al
	add dl, 30h
	mov ah, 02h
	int 21h
	pop ax
	mov al, ah
	xor ah, ah
	mov bx, ax
	jmp two_digit

close:
	mov ah, 4ch
	int 21h
end start