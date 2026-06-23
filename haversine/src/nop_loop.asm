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
