;;
;; A minimal loader that tries to load and execute a file
;; from a FAT16-formatted SD card.
;;


;; Basic definitions ################################################


;; positions of basic constants
CONST32_1 = $a0
CONST32_2 = $a4
CONST32_32 = $a8

;; arguments, return values, temporary zp storage
;; those are not guaranteed to be preserved by normal subroutines
;; interrupt handlers, however, *are* mandated to restore those!
ARG1 = $c0
ARG2 = ARG1 + 4
RET = ARG2 + 4
TMP = RET + 4
TMP1 = TMP
TMP2 = TMP1 + 4
TMP3 = TMP2 + 4
TMP4 = TMP3 + 4

;; some space to save registers if we cannot use the stack
SAVEA = TMP4 + 4
SAVEX = SAVEA + 1
SAVEY = SAVEX + 1

;; some storage for pointers
PTR1 = SAVEY + 1
PTR2 = PTR1 + 2
PTR3 = PTR2 + 2

;; pointers for math (arguments and result)

MPTR1 = PTR3 + 2	; first argument
MPTR2 = MPTR1 + 2	; second argument
MPTR3 = MPTR2 + 2	; primary result
MPTR4 = MPTR3 + 2	; secondary result (where relevant, like remainder of division)

;; those *are* saved by subroutines and interrupts!
VREG1 = MPTR4 + 2
VREG2 = VREG1 + 1

;; IRQ vector for applications
IRQ_VEC = VREG2 + 1


;; A few special characters
C_LF = $0A	; line feed
C_CR = $0D	; carriage return
C_BS = $08	; backspace
C_PT = $2E	; point
C_SP = $20	; space
C_EX = $21	; exclamation mark




;; Macros ###########################################################

.include "macros.asm"


;; Predefined Data ##################################################

.segment "DATA"

S_AUTOEXEC: .asciiz "AUTOEXECBIN"


;; Code #############################################################

.segment "CODE"

.include "util.asm"
.include "math.asm"
.include "io.asm"
.include "fat.asm"

.proc START
	sei
	cld			; clear decimal mode
	ldx #$FF
	txs			; initialize stack pointer


	;; clear zero-page to avoid having to clear variables
	lda #0
	tax
clear_zp:
	sta $0000,x
	inx
	bne clear_zp

	;; put some constants in ZP
	lda #1
	sta CONST32_1
	lda #2
	sta CONST32_2
	lda #32
	sta CONST32_32

	
	jsr io_init
	jsr fat_init


	cli

	;; look for autoexec.bin on SD card #########################
	jsr fat_load_autoexec;
	lda RET
	bne error			; file not found?

	jmp $0800			; jump into loaded code

error:
	;; print out exclamation mark in case of an error
	lda #C_EX
	jsr io_write_char
	bne error

.endproc


;;
;; IRQ handler
;;
.proc IRQ
	pha		; save affected register

	lda IRQ_VEC	; check if IRQ vector is zero
	ora IRQ_VEC+1
	beq end		; if so, skip

	; there is no indirect jsr so push return address to stack
	; so the actual IRQ handler code can rts later on
	prepare_rts end
	jmp (IRQ_VEC)

end:
	pla		; restore register
	rti		; return from interrupt
.endproc



; system vectors ####################################################

.segment "VECTORS"
.org    $FFFA

.addr	IRQ		; NMI vector
.addr	START		; RESET vector
.addr	IRQ		; IRQ vector


