; ------------------------------------------------------------------
; io_print_mon - Вывод текста на монитор в текстовом режиме 80х25
; IN : SI - Указатель текста (нулевой символ окончания)

io_print_mon:
	pusha

	mov ah, 0Eh			

.repeat:
	lodsb				
	cmp al, 0
	je .done			

	int 10h				
	jmp .repeat

.done:
	popa
	ret


; ------------------------------------------------------------------
; io_input_text - Получение текста с клавиатуры
; IN : SI - локация на буффер текста
; OUT: SI - текст длинной максимум 255 символов!

io_input_text:
	pusha

	mov di, si			
	mov cx, 0			


.more:					
	mov ax, 0
	mov ah, 10h			
	int 16h

	cmp al, 13			
	je .done

	cmp al, 8			
	je .backspace			

	cmp al, ' '			
	jb .more

	cmp al, '~'
	ja .more

	jmp .nobackspace


.backspace:
	cmp cx, 0			
	je .more			

	call io_cur_pos		
	cmp dl, 0
	je .backspace_linestart

	pusha
	mov ah, 0Eh			
	mov al, 8
	int 10h				
	mov al, 32
	int 10h
	mov al, 8
	int 10h
	popa

	dec di				
	

	dec cx				

	jmp .more


.backspace_linestart:
	dec dh				
	mov dl, 79
	call io_move_cursor

	mov al, ' '			
	mov ah, 0Eh
	int 10h

	mov dl, 79			
	call io_move_cursor

	dec di				
	dec cx				

	jmp .more


.nobackspace:
	pusha
	mov ah, 0Eh			
	int 10h
	popa

	stosb				
	inc cx				
	cmp cx, 254			
	jae near .done

	jmp near .more			


.done:
	mov ax, 0			
	stosb

	mov ah, 0Eh			
	mov al, 13
	int 10h
	mov al, 10
	int 10h

	popa
	ret


; ------------------------------------------------------------------
; io_move_cursor - передвижение курсора
; IN: DH, DL = столбец, строка

io_move_cursor:
	pusha

	mov bh, 0
	mov ah, 2
	int 10h	

	popa
	ret


; ------------------------------------------------------------------
; io_cur_pos - Возврат позиции курсора
; OUT: DH, DL = столбец, строка

io_cur_pos:
	pusha

	mov bh, 0
	mov ah, 3
	int 10h	

	mov [.tmp], dx
	popa
	mov dx, [.tmp]
	ret


	.tmp dw 0

; ------------------------------------------------------------------
; str_uppercase - конвертация текста в CAPS
; IN/OUT: AX = вывод текста в верхнем регистре

	str_uppercase:
		pusha
	
		mov si, ax			
	
	.more:
		cmp byte [si], 0		
		je .done			
	
		cmp byte [si], 'a'		
		jb .noatoz
		cmp byte [si], 'z'
		ja .noatoz
	
		sub byte [si], 20h		
	
		inc si
		jmp .more
	
	.noatoz:
		inc si
		jmp .more
	
	.done:
		popa

; ------------------------------------------------------------------
; str_length - Возврат длины строки
; IN : AX - указатель на текст
; OUT: AX = длина строки

str_length:
	pusha

	mov bx, ax

	mov cx, 0

.more:
	cmp byte [bx], 0
	je .done
	inc bx
	inc cx
	jmp .more


.done:
	mov word [.tmp_counter], cx
	popa

	mov ax, [.tmp_counter]
	ret


	.tmp_counter	dw 0


; ------------------------------------------------------------------
; str_compare - сравнивание двух строк
; IN : SI = строка 1, DI = строка 2
; OUT: CF будет установлен если одинаковы - чистый если разные

str_compare:
	pusha

.more:
	mov al, [si]			
	mov bl, [di]

	cmp al, bl	
	jne .not_same

	cmp al, 0			
	je .terminated

	inc si
	inc di
	jmp .more


.not_same:	
	popa				
	clc				
	ret


.terminated:			
	popa
	stc				
	ret


; ------------------------------------------------------------------
; fs_file_list - Получение списка файлов
; IN/OUT: SI = Локация на буфер для имен файлов

fs_file_list:
	pusha

	mov word [.file_list_tmp], si

	mov eax, 0			

	call disk_reset_floppy		

	mov ax, 19			
	call disk_convert_l2hts

	mov si, disk_buffer		
	mov bx, si

	mov ah, 2			
	mov al, 14			

	pusha				


.read_root_dir:
	popa
	pusha

	stc
	int 13h				
	call disk_reset_floppy		
	jnc .show_dir_init		

	call disk_reset_floppy		
	jnc .read_root_dir
	jmp .done			

.show_dir_init:
	popa

	mov ax, 0
	mov si, disk_buffer		

	mov word di, [.file_list_tmp]	


.start_entry:
	mov al, [si+11]			
	cmp al, 0Fh			
	je .skip

	test al, 18h			
	jnz .skip			

	mov al, [si]
	cmp al, 229			
	je .skip

	cmp al, 0			
	je .done


	mov cx, 1			
	mov dx, si			

.testdirentry:
	inc si
	mov al, [si]		
	cmp al, ' '			
	jl .nxtdirentry
	cmp al, '~'
	ja .nxtdirentry

	inc cx
	cmp cx, 11			
	je .gotfilename
	jmp .testdirentry


.gotfilename:				
	mov si, dx			

	mov cx, 0
.loopy:
	mov byte al, [si]
	cmp al, ' '
	je .ignore_space
	mov byte [di], al
	inc si
	inc di
	inc cx
	cmp cx, 8
	je .add_dot
	cmp cx, 11
	je .done_copy
	jmp .loopy

.ignore_space:
	inc si
	inc cx
	cmp cx, 8
	je .add_dot
	jmp .loopy

.add_dot:
	mov byte [di], '.'
	inc di
	jmp .loopy

.done_copy:
	mov byte [di], ' '		
	inc di

.nxtdirentry:
	mov si, dx			

.skip:
	add si, 32			
	jmp .start_entry


.done:
	dec di
	mov byte [di], 0		

	popa
	ret


	.file_list_tmp		dw 0


; ------------------------------------------------------------------
; fs_load_file - загрузка файла в RAM
; IN : AX - название файла, CX = адресс для загруки файла
; OUT: BX = размер файла в байтах (установка флага если файл не найден)

fs_load_file:
	call str_uppercase
	call disk_filename_convert
	jc .root_problem

	mov [.filename_loc], ax		
	mov [.load_position], cx	

	mov eax, 0			

	call disk_reset_floppy		
	jnc .floppy_ok	

	mov si, .err_msg_floppy_reset	
	call io_print_mon
	jmp $


.floppy_ok:				
	mov ax, 19			
	call disk_convert_l2hts

	mov si, disk_buffer		
	mov bx, si

	mov ah, 2			
	mov al, 14			

	pusha	


.read_root_dir:
	popa
	pusha

	stc				
	int 13h				
	jnc .search_root_dir		

	call disk_reset_floppy		
	jnc .read_root_dir

	popa
	jmp .root_problem		

.search_root_dir:
	popa

	mov cx, word 224		
	mov bx, -32			

.next_root_entry:
	add bx, 32			
	mov di, disk_buffer		
	add di, bx

	mov al, [di]			

	cmp al, 0			
	je .root_problem

	cmp al, 229			
	je .next_root_entry		

	mov al, [di+11]			

	cmp al, 0Fh			
	je .next_root_entry

	test al, 18h			
	jnz .next_root_entry

	mov byte [di+11], 0		

	mov ax, di			
	call str_uppercase

	mov si, [.filename_loc]		

	call str_compare		
	jc .found_file_to_load

	loop .next_root_entry

.root_problem:
	mov bx, 0			
	stc				
	ret


.found_file_to_load:			
	mov ax, [di+28]			
	mov word [.file_size], ax

	cmp ax, 0			
	je .end				

	mov ax, [di+26]			
	mov word [.cluster], ax

	mov ax, 1			
	call disk_convert_l2hts

	mov di, disk_buffer		
	mov bx, di

	mov ah, 2			
	mov al, 9			

	pusha

.read_fat:
	popa				
	pusha

	stc
	int 13h
	jnc .read_fat_ok

	call disk_reset_floppy
	jnc .read_fat

	popa
	jmp .root_problem


.read_fat_ok:
	popa


.load_file_sector:
	mov ax, word [.cluster]		
	add ax, 31

	call disk_convert_l2hts		

	mov bx, [.load_position]


	mov ah, 02			
	mov al, 01

	stc
	int 13h
	jnc .calculate_next_cluster	

	call disk_reset_floppy		
	jnc .load_file_sector

	mov si, .err_msg_floppy_reset
	call io_print_mon
	jmp $


.calculate_next_cluster:
	mov ax, [.cluster]
	mov bx, 3
	mul bx
	mov bx, 2
	div bx				
	mov si, disk_buffer		
	add si, ax
	mov ax, word [ds:si]

	or dx, dx			

	jz .even			
					

.odd:
	shr ax, 4			
	jmp .calculate_cluster_cont	

.even:
	and ax, 0FFFh			

.calculate_cluster_cont:
	mov word [.cluster], ax		

	cmp ax, 0FF8h
	jae .end

	add word [.load_position], 512
	jmp .load_file_sector		


.end:
	mov bx, [.file_size]		
	clc				
	ret


	.bootd		db 0 		
	.cluster	dw 0 		
	.pointer	dw 0 		

	.filename_loc	dw 0		
	.load_position	dw 0		
	.file_size	dw 0	

	.string_buff	times 12 db 0	; For size (integer) printing

	.err_msg_floppy_reset	db 'fs_load_file: Floppy failed to reset', 0


; ==================================================================
; Вспомогательные функции FDD
; ==================================================================
; ------------------------------------------------------------------
; disk_filename_convert - конвертирует "TEST.BIN" в "TEST    BIN" (Нужно для FS - FAT12)
; IN : AX = указатель на текст
; OUT: AX = сконвертированный текст (carry set if invalid)

disk_filename_convert:
	pusha

	mov si, ax

	call str_length
	cmp ax, 12			
	jg .failure			

	cmp ax, 0
	je .failure			

	mov dx, ax			

	mov di, .dest_string

	mov cx, 0
.copy_loop:
	lodsb
	cmp al, '.'
	je .extension_found
	stosb
	inc cx
	cmp cx, dx
	jg .failure			
	jmp .copy_loop

.extension_found:
	cmp cx, 0
	je .failure			

	cmp cx, 8
	je .do_extension		

.add_spaces:
	mov byte [di], ' '
	inc di
	inc cx
	cmp cx, 8
	jl .add_spaces

.do_extension:
	lodsb				
	cmp al, 0
	je .failure
	stosb
	lodsb
	cmp al, 0
	je .failure
	stosb
	lodsb
	cmp al, 0
	je .failure
	stosb

	mov byte [di], 0		

	popa
	mov ax, .dest_string
	clc				
	ret


.failure:
	popa
	stc				
	ret


	.dest_string	times 14 db 0


; --------------------------------------------------------------------------
; Reset floppy disk

disk_reset_floppy:
	push ax
	push dx
	mov ax, 0
	mov dl, [bootdev]
	stc
	int 13h
	pop dx
	pop ax
	ret


;--------------------------------------------------------------------------
;disk_convert_l2hts -- Вычисление Головки, Трека, Сектора для INT13h
;IN : logical sector in AX
;OUT: correct registers for int 13h

disk_convert_l2hts:
	push bx
	push ax

	mov bx, ax		

	mov dx, 0		
	div word [SecsPerTrack]	
	add dl, 01h			
	mov cl, dl			
	mov ax, bx

	mov dx, 0			
	div word [SecsPerTrack]		
	mov dx, 0
	div word [Sides]		
	mov dh, dl			
	mov ch, al			

	pop ax
	pop bx

	mov dl, [bootdev]	
	ret

	Sides dw 2
	SecsPerTrack dw 18
	bootdev db 0			

	disk_buffer equ 24576