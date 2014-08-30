.proc math_add32
	push_ay

	clc
	php
	ldy #0
loop:
	plp
	lda (MPTR1),y
	adc (MPTR2),y
	sta (MPTR3),y
	php
	iny
	cpy #4
	bne loop

	plp

	pull_ay
	rts
.endproc


.proc math_div32
	push_axy

	;; some mapping of labels
	dividend = TMP1
	divisor = TMP2
	remainder = TMP3
	result = dividend
	temp = TMP4


	ldy #0
loop_init:
	lda (MPTR1),y
	sta dividend,y		; copy argument 1
	lda (MPTR2),y
	sta divisor,y		; copy argument 2
	lda #0
	sta remainder,y		; preset remainder to zero
	iny
	cpy #4
	bne loop_init


	ldx #32			; repeat for each bit: ...
divloop:
	asl dividend		; dividend*2, msb -> Carry
	rol dividend+1
	rol dividend+2
	rol dividend+3	
	rol remainder		; remainder*2 + msb from carry
	rol remainder+1
	rol remainder+2
	rol remainder+3


	ldy #0
	sec
	php
loop_substract:
	plp
	lda remainder,y
	sbc divisor,y
	sta temp,y
	php
	iny
	cpy #4
	bne loop_substract
	plp				; clean up stack and restore carry for next branch

	bcc skip			; if carry=0 then divisor didn't fit in yet
	mov32 temp, remainder		; else substraction result is new remainder
	inc result			; and INCrement result cause divisor fit in 1 times

skip:
	dex
	bne divloop	


	ldy #0
loop_copy_result:
	lda result,y
	sta (MPTR3),y
	lda remainder,y
	sta (MPTR4),y
	iny
	cpy #4
	bne loop_copy_result

	pull_axy
	rts
.endproc



.proc math_mul32
	push_ay

	ldy #0
loop_init:
	lda (MPTR1),y
	sta TMP1,y
	lda (MPTR2),y
	sta TMP2,y
	lda #0
	sta (MPTR3),y
	iny
	cpy #4
	bne loop_init

loop:
	lsr TMP2+3
	ror TMP2+2
	ror TMP2+1
	ror TMP2
	bcc skip_add	; if least-significant bit wasn't set, skip addition

	ldy #0
	clc
	php
loop_add:
	plp
	lda (MPTR3),y
	adc TMP1,y
	sta (MPTR3),y
	php
	iny
	cpy #4
	bne loop_add
	plp		; clean up stack


skip_add:	
	asl TMP1	; shift left...
	rol TMP1+1	; ... and rotate carry bit in from low to high
	rol TMP1+2
	rol TMP1+3

	lda TMP2	; check if factor is zero already
	ora TMP2+1
	ora TMP2+2
	ora TMP2+3
	bne loop

	pull_ay
	rts
.endproc



.proc math_sub32
	push_ay

	sec
	php
	ldy #0
loop:
	plp				; get carry back from stack
	lda (MPTR1),y
	sbc (MPTR2),y
	sta (MPTR3),y
	php
	iny
	cpy #4			; this ruins the carry flags 
	bne loop

	plp

	pull_ay
	rts
.endproc

