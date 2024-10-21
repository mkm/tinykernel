block_size equ 0x200
block_count equ (end - resurrection) / block_size

; Memory Map
ivt equ 0x00000
bda equ 0x00400
vga_info equ 0x00500
vga_mode_info equ 0x00600
free1 equ 0x00700
boot equ 0x07C00
free2 equ 0x07E00
ptttt equ 0x60000
pttt equ 0x61000
ptt equ 0x62000
pttt_id equ 0x63000
stack equ 0x70000
bios equ 0x80000
ext equ 0x100000

vga_sig equ 0x00
vga_version equ 0x04
vga_oem_off equ 0x06
vga_oem_seg equ 0x08
vga_cap equ 0x0A
vga_modes_off equ 0x0E
vga_modes_seg equ 0x10
vga_total_memory equ 0x12

vgam_attr equ 0x00
vgam_width equ 0x12
vgam_height equ 0x14
vgam_bits equ 0x19
vgam_framebuffer equ 0x28

[BITS 16]
[ORG 0x7C00]

genesis:
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ax, stack >> 4
    mov ss, ax
    xor sp, sp

    call clear_screen

; read from disk
    mov bx, block_count
read_loop:
    mov cx, bx
    cmp cx, 0x80
    jna .last_read
    mov cx, 0x80
.last_read:
    sub bx, cx
    mov ah, 0x42 ; extended read function
    mov dl, 0x80 ; drive number
    mov si, disk_addr_packet
    mov [disk_addr_packet.num_blocks], cx
    int 0x13
    jc .error
    add [disk_addr_packet.buf_seg], DWORD 0x1000
    add [disk_addr_packet.sector], DWORD 0x80
    test bx, bx
    jnz read_loop

    jmp resurrection

.error:
    mov di, str_read_error
    mov si, str_read_error_len
    call println
    hlt
    jmp $ - 1

disk_addr_packet:
    db 0x10 ; size of packet
    db 0x0 ; reserved
.num_blocks:
    dw 0x80 ; number of blocks
    dw resurrection ; buffer offset
.buf_seg:
    dw 0x0 ; buffer segment
.sector:
    dq 0x1 ; first sector

cursor:
    dw 0

; clear_screen()
clear_screen:
    push es
    mov ax, 0xB800
    mov es, ax
    mov ax, 0x0720
    mov cx, 80 * 25
    xor di, di
    rep stosw
    mov WORD [cursor], 0
    pop es
    ret

; print(str@di, len@si)
print:
    push es
    mov ax, 0xB800
    mov es, ax
    mov cx, si
    mov si, di
    mov di, [cursor]
    mov ah, 0x07

    test cx, cx
    jmp .loop_test
.loop:
    lodsb
    stosw
    dec cx
.loop_test:
    jnz .loop

    mov [cursor], di
    pop es
    ret

print_space:
    mov di, str_space
    mov si, str_space_len
    jmp print

; println(str@di, len@si)
println:
    call print
; deliberate fall through to newline()

; newline()
newline:
    mov ax, [cursor]
    xor dx, dx
    mov cx, 160
    div cx
    sub dx, 160
    sub [cursor], dx
    ret

hex_string:
    db "0x"
.digits:
    times 4 db 0

hexes:
    db "0123456789ABCDEF"

; print_hex(num@di)
print_hex:
    push bx
    xor bx, bx
    mov cx, di
    mov di, hex_string.digits

    mov bl, ch
    shr bl, 4
    mov al, [hexes + bx]
    stosb

    mov bl, ch
    and bl, 0x0F
    mov al, [hexes + bx]
    stosb

    mov bl, cl
    shr bl, 4
    mov al, [hexes + bx]
    stosb

    mov bl, cl
    and bl, 0x0F
    mov al, [hexes + bx]
    stosb

    pop bx
    mov di, hex_string
    mov si, 6
    jmp print

str_read_error:
    db "Read error"
str_read_error_len equ $ - str_read_error

; padding
    times (0x1FE - $ + genesis) nop

.magic:
    db 0x55, 0xAA

resurrection:
    mov di, str_resurrected
    mov si, str_resurrected_len
    call println
    call get_vga_info
    mov di, [vga_info + vga_total_memory]
    call print_hex
    mov di, str_of_video_memory
    mov si, str_of_video_memory_len
    call println
    mov ax, [vga_info + vga_modes_seg]
    mov gs, ax
    mov bx, [vga_info + vga_modes_off]

    mov di, str_info_header
    mov si, str_info_header_len
    call println

    xor bp, bp
    jmp .mode_loop_test
.mode_loop:
    mov di, gs:[bx]
    call get_vga_mode_info
    mov ax, [vga_mode_info + vgam_attr]
    test ax, 0b00010000 ; graphics mode bit
    jz .next
    test ax, 0b10000000 ; linear framebuffer bit
    jz .next
    cmp WORD [vga_mode_info + vgam_width], 1024
    jne .next
    cmp WORD [vga_mode_info + vgam_height], 768
    jne .next
    mov di, gs:[bx]
    mov bp, di
    call print_hex
    call print_space
    mov di, [vga_mode_info + vgam_attr]
    call print_hex
    call print_space
    mov di, [vga_mode_info + vgam_width]
    call print_hex
    call print_space
    mov di, [vga_mode_info + vgam_height]
    call print_hex
    call print_space
    mov di, [vga_mode_info + vgam_bits]
    and di, 0xFF
    call print_hex
    call print_space
    mov di, [vga_mode_info + vgam_framebuffer + 0x2]
    call print_hex
    call print_space
    mov di, [vga_mode_info + vgam_framebuffer]
    call print_hex
    call print_space
    call newline
.next:
    add bx, 2
.mode_loop_test:
    cmp WORD gs:[bx], 0xFFFF
    jne .mode_loop

    mov di, bp
    ; call set_vga_mode

    cli
    lgdt [gdtr]
    mov eax, cr0
    or al, 0x1
    mov cr0, eax
    jmp 0x8:apotheosis

.done:
    hlt
    jmp .done

gdt:
; null segment
    dq 0
; code segment
    dw 0xFF
    dw 0x00
    db 0x0
    db 0b10011010
    db 0b11001111
    db 0x0
; data segment
    dw 0xFF
    dw 0x00
    db 0x0
    db 0b10010010
    db 0b11001111
    db 0x0
gdt_end:

gdtr:
    dw gdt_end - gdt - 1
    dd gdt

; get_vga_info()
get_vga_info:
    mov di, vga_info
    mov ax, 0x4F00
    int 0x10
    ret

; get_vga_mode_info()
get_vga_mode_info:
    mov cx, di
    mov di, vga_mode_info
    mov ax, 0x4F01
    int 0x10
    ret

; set_vga_mode(mode@di)
set_vga_mode:
    mov bx, di
    or bx, 0x4000
    mov ax, 0x4F02
    int 0x10
    ret

str_space:
    db " "
str_space_len equ $ - str_space

str_resurrected:
    db "Resurrected, ", '0' + (block_count / 10) % 10, '0' + block_count % 10, " blocks read"
str_resurrected_len equ $ - str_resurrected

str_of_video_memory:
    db " * 64KB of video memory"
str_of_video_memory_len equ $ - str_of_video_memory

str_info_header:
    db "mode   flags  width  height bits   addr"
str_info_header_len equ $ - str_info_header

[BITS 32]
apotheosis:
    mov ax, 0x10
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax

; init page tables
    mov edi, ptttt
    mov cr3, edi
    xor eax, eax
    mov ecx, 0x1000 * 4
    rep stosb

    mov DWORD [ptttt], pttt | 0b11
    mov DWORD [ptttt + 0x800], pttt_id | 0b11
    mov DWORD [pttt], ptt | 0b11
    mov DWORD [pttt_id], 0b10000011
    mov DWORD [ptt], 0b10000011

; enable PAE
    mov eax, cr4
    or eax, 1 << 5
    mov cr4, eax

; enable long mode
    mov ecx, 0xC0000080
    rdmsr
    or eax, 1 << 8
    wrmsr

; enable paging
    mov eax, cr0
    or eax, 1 << 31
    mov cr0, eax

    mov BYTE [gdt + 0x08 + 6], 0b10101111
    mov BYTE [gdt + 0x10 + 6], 0b10101111
    lgdt [gdtr]
    jmp 0x8:divinity

[BITS 64]
divinity:
    mov ax, 0x10
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax
    mov rsp, stack + 0x8000

    xor r15, r15
    cmp DWORD [kernel], 0x464C457F ; ELF magic
    jne elf_error
    inc r15 ; 1
    cmp BYTE [kernel + 4], 2 ; 64-bit
    jne elf_error
    inc r15 ; 2
    cmp WORD [kernel + 18], 0x3E ; x86-64
    jne elf_error
    inc r15 ; 3
    mov rbx, [kernel + 32] ; program header start
    lea rbx, [rbx + kernel]
    xor edx, edx
    mov dx, [kernel + 54] ; size of entry
    xor ecx, ecx
    mov cx, [kernel + 56] ; number of entries

    xor eax, eax
    mov r10, 0x100000
.loop:
    push rcx
    cmp DWORD [rbx], 1
    jne .loop_test
    mov rsi, [rbx + 8] ; file offset
    lea rsi, [rsi + kernel]
    mov rdi, [rbx + 16] ; memory offset
    lea rdi, [rdi + 0x100000]
    push rdi
    mov rcx, [rbx + 40] ; memory size
    mov rbp, rcx
    rep stosb
    cmp rdi, r10
    cmovg r10, rdi
    pop rdi
    mov rcx, [rbx + 32] ; data size
    rep movsb
.loop_test:
    add rbx, rdx
    pop rcx
    loop .loop
    inc r15 ; 4

    sub r10, 0x100000

    mov rax, [kernel + 24] ; program entry
    lea rax, [rax + 0x100000]
    mov rdi, r10
    push rax
    ret

elf_error:
    hlt
    jmp $-1

ALIGN 0x200

kernel:
incbin "kernel.elf"

ALIGN 0x200

end:
