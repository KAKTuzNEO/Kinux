	mov ax, 2000h
	mov ds, ax
	mov es, ax

	mov si, ver
	call io_print_mon
	mov si, author_msg
	call io_print_mon

loop:
	mov si, prompt
	call io_print_mon
	mov si, user_input
	call io_input_text

	cmp byte [si], 0
	call io_cur_pos
	dec dl
	call io_move_cursor
	
	je loop

	cmp word [si], "ls"
	je list_files
	cmp word [si], "reboot"
	je reboot

	mov ax, si
	mov cx, 32768
	call fs_load_file
	jc load_fail

	call 32768
	jmp loop


reboot:
        mov ax, 0
        int 19h

load_fail:
	mov si, load_fail_msg
	call io_print_mon
	jmp loop

list_files:
	mov si, file_list
	call fs_file_list
	call io_print_mon
	jmp loop

	%include "msg.asm"

	user_input	times 256 db 0
	file_list	times 1024 db 0

	%include "lib.asm"
