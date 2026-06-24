;  ========================================================================
;
;  (C) Copyright 2023 by Molly Rocket, Inc., All Rights Reserved.
;
;  This software is provided 'as-is', without any express or implied
;  warranty. In no event will the authors be held liable for any damages
;  arising from the use of this software.
;
;  Please see https://computerenhance.com for more information
;
;  ========================================================================

;  ========================================================================
;  LISTING 132
;  ========================================================================

global MOVAllBytesASM
global NOPAllBytesASM
global CMPAllBytesASM
global DECAllBytesASM

section .text

;
; NOTE(casey): These ASM routines are written for the Windows
; 64-bit ABI. They expect RCX to be the first parameter (the count),
; and in the case of MOVAllBytesASM, RDX to be the second
; parameter (the data pointer). To use these on a platform
; with a different ABI, you would have to change those registers
; to match the ABI.
;
; on ubuntu RCX -> RDI RDX -> RSI

MOVAllBytesASM:
    xor rax, rax
.loop:
    mov [rsi + rax], al
    inc rax
    cmp rax, rdi
    jb .loop
    ret

NOPAllBytesASM:
    xor rax, rax
.loop:
    db 0x0f, 0x1f, 0x00 ; NOTE(casey): This is the byte sequence for a 3-byte NOP
    inc rax
    cmp rax, rdi
    jb .loop
    ret

CMPAllBytesASM:
    xor rax, rax
.loop:
    inc rax
    cmp rax, rdi
    jb .loop
    ret

DECAllBytesASM:
.loop:
    dec rdi
    jnz .loop
    ret

;  ========================================================================
;
;  (C) Copyright 2023 by Molly Rocket, Inc., All Rights Reserved.
;
;  This software is provided 'as-is', without any express or implied
;  warranty. In no event will the authors be held liable for any damages
;  arising from the use of this software.
;
;  Please see https://computerenhance.com for more information
;
;  ========================================================================

;  ========================================================================
;  LISTING 135
;  ========================================================================

global NOP3x1AllBytes
global NOP1x3AllBytes
global NOP1x9AllBytes

section .text

;
; NOTE(casey): These ASM routines are written for the Windows
; 64-bit ABI. They expect RCX to be the first parameter (the count),
; and if applicable, RDX to be the second parameter (the data pointer).
; To use these on a platform with a different ABI, you would have to
; change those registers to match the ABI.
;

NOP3x1AllBytes:
    xor rax, rax
.loop:
    db 0x0f, 0x1f, 0x00 ; NOTE(casey): This is the byte sequence for a 3-byte NOP
    inc rax
    cmp rax, rdi
    jb .loop
    ret

NOP1x3AllBytes:
    xor rax, rax
.loop:
    nop
    nop
    nop
    inc rax
    cmp rax, rdi
    jb .loop
    ret

NOP1x9AllBytes:
    xor rax, rax
.loop:
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    inc rax
    cmp rax, rdi
    jb .loop
    ret

;  ========================================================================
;
;  (C) Copyright 2023 by Molly Rocket, Inc., All Rights Reserved.
;
;  This software is provided 'as-is', without any express or implied
;  warranty. In no event will the authors be held liable for any damages
;  arising from the use of this software.
;
;  Please see https://computerenhance.com for more information
;
;  ========================================================================

;  ========================================================================
;  LISTING 136
;  ========================================================================

global ConditionalNOP

section .text

;
; NOTE(casey): These ASM routines are written for the Windows
; 64-bit ABI. They expect RCX to be the first parameter (the count),
; and if applicable, RDX to be the second parameter (the data pointer).
; To use these on a platform with a different ABI, you would have to
; change those registers to match the ABI.
;

ConditionalNOP:
    xor rax, rax
.loop:
    mov r10, [rsi + rax]
	inc rax
	test r10, 1
    jnz .skip
	nop
.skip:
    cmp rax, rdi
    jb .loop
    ret

;  ========================================================================
;
;  (C) Copyright 2023 by Molly Rocket, Inc., All Rights Reserved.
;
;  This software is provided 'as-is', without any express or implied
;  warranty. In no event will the authors be held liable for any damages
;  arising from the use of this software.
;
;  Please see https://computerenhance.com for more information
;
;  ========================================================================

;  ========================================================================
;  LISTING 144
;  ========================================================================

global Read_x1
global Read_x2
global Read_x3
global Read_x4

section .text

;
; NOTE(casey): These ASM routines are written for the Windows
; 64-bit ABI. They expect the count in rcx and the data pointer in rdx.
;

Read_x1:
	align 64
.loop:
    mov rax, [rsi]
    sub rdi, 1
    jnle .loop
    ret

Read_x2:
	align 64
.loop:
    mov rax, [rsi]
    mov rax, [rsi]
    sub rdi, 2
    jnle .loop
    ret

Read_x3:
    align 64
.loop:
    mov rax, [rsi]
    mov rax, [rsi]
    mov rax, [rsi]
    sub rdi, 3
    jnle .loop
    ret

Read_x4:
	align 64
.loop:
    mov rax, [rsi]
    mov rax, [rsi]
    mov rax, [rsi]
    mov rax, [rsi]
    sub rdi, 4
    jnle .loop
    ret

;  ========================================================================
;
;  (C) Copyright 2023 by Molly Rocket, Inc., All Rights Reserved.
;
;  This software is provided 'as-is', without any express or implied
;  warranty. In no event will the authors be held liable for any damages
;  arising from the use of this software.
;
;  Please see https://computerenhance.com for more information
;
;  ========================================================================

;  ========================================================================
;  LISTING 150
;  ========================================================================

global Read_4x2
global Read_8x2
global Read_16x2
global Read_16x3
global Read_32x2
global Read_64x2

section .text

;
; NOTE(casey): These ASM routines are written for the Windows
; 64-bit ABI. They expect RCX to be the first parameter (the count),
; and in the case of MOVAllBytesASM, RDX to be the second
; parameter (the data pointer). To use these on a platform
; with a different ABI, you would have to change those registers
; to match the ABI.
;

Read_4x2:
    xor rax, rax
	align 64
.loop:
    mov r8d, [rsi ]
    mov r8d, [rsi + 4]
    add rax, 8
    cmp rax, rdi
    jb .loop
    ret

Read_8x2:
    xor rax, rax
	align 64
.loop:
    mov r8, [rsi ]
    mov r8, [rsi + 8]
    add rax, 16
    cmp rax, rdi
    jb .loop
    ret

Read_16x2:
    xor rax, rax
	align 64
.loop:
    vmovdqu xmm0, [rsi]
    vmovdqu xmm0, [rsi + 16]
    add rax, 32
    cmp rax, rdi
    jb .loop
    ret

Read_16x3:
    xor rax, rax
	align 64
.loop:
    vmovdqu xmm0, [rsi]
    vmovdqu xmm0, [rsi + 16]
    vmovdqu xmm0, [rsi + 32]
    add rax, 48
    cmp rax, rdi
    jb .loop
    ret

Read_32x2:
    xor rax, rax
	align 64
.loop:
    vmovdqu ymm0, [rsi]
    vmovdqu ymm0, [rsi + 32]
    add rax, 64
    cmp rax, rdi
    jb .loop
    ret

Read_64x2:
    xor rax, rax
	align 64
.loop:
    vmovdqu32 zmm0, [rsi]
    vmovdqu32 zmm0, [rsi + 64]
    add rax, 128
    cmp rax, rdi
    jb .loop
    ret


;rdi count, rsi data, rdx mask 
global CasheBandwidth
CasheBandwidth:
    xor rax, rax
    xor rbx, rbx
	align 64
.loop:
    vmovdqu64 zmm0, [rsi + rbx]
    add rbx, 64
    vmovdqu64 zmm1, [rsi + rbx]
    add rbx, 64
    and rbx, rdx
    add rax, 128
    cmp rax, rdi
    jb .loop
    ret

