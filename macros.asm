
.macro push_axy
	pha		; push accumulator to stack
	txa		; x -> a
	pha		; push x to stack
	tya		; y -> a
	pha		; push y to stack
.endmacro

.macro pull_axy
	pla		; pull y from stack
	tay		; a -> y
	pla		; pull x from stack
	tax		; a -> x
	pla		; pull a from stack
.endmacro


.macro push_ax
	pha
	txa
	pha
.endmacro


.macro pull_ax
	pla
	tax
	pla
.endmacro

.macro push_ay
	pha
	tya
	pha
.endmacro


.macro pull_ay
	pla
	tay
	pla
.endmacro


.macro push_vregs
	lda VREG1
	pha
	lda VREG2
	pha
.endmacro


.macro pull_vregs
	pla
	sta VREG2
	pla
	sta VREG1
.endmacro


.macro put_address ADDR, L1, L2
	lda #<ADDR
	sta L1
	lda #>ADDR
 .ifnblank L2
	sta L2
 .else
	sta L1+1
 .endif
.endmacro


.macro put_address_lo ADDR, L1
	lda #<ADDR
	sta L1
.endmacro


.macro mov16 SRC, DEST
	lda SRC
	sta DEST
	lda SRC+1
	sta DEST+1
.endmacro

.macro mov32 SRC, DEST
	lda SRC
	sta DEST
	lda SRC+1
	sta DEST+1
	lda SRC+2
	sta DEST+2
	lda SRC+3
	sta DEST+3
.endmacro


.macro prepare_rts ADDR
	lda #>(ADDR - 1)
	pha
	lda #<(ADDR - 1)
	pha
.endmacro


.macro add32 SRC1, SRC2, DEST
	put_address SRC1, MPTR1
	put_address SRC2, MPTR2
	put_address DEST, MPTR3
	jsr math_add32
.endmacro

.macro div32 SRC1, SRC2, DEST1, DEST2
	put_address SRC1, MPTR1
	put_address SRC2, MPTR2
	put_address DEST1, MPTR3
	put_address DEST2, MPTR4
	jsr math_div32
.endmacro

.macro mul32 SRC1, SRC2, DEST
	put_address SRC1, MPTR1
	put_address SRC2, MPTR2
	put_address DEST, MPTR3
	jsr math_mul32
.endmacro

.macro sub32 SRC1, SRC2, DEST
	put_address SRC1, MPTR1
	put_address SRC2, MPTR2
	put_address DEST, MPTR3
	jsr math_sub32
.endmacro


