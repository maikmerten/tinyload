BUFFERPAGE = 2					; pages 2 and 3 serve as buffer für 512-bytes sectors
BUFFERBASE = BUFFERPAGE * 256	; absolute starting address of buffer
LOADPAGE = 8					; load files into memory starting with this page
LASTLOADPAGE = 223				; last page to load into


;; Memory positions for FAT layout information.
;; Many variables here could fit in less than 4 bytes.
;; However, this makes 32-bit math much easier.
BYTESPERSECTOR = $0000
SECTORSPERCLUSTER = BYTESPERSECTOR + 4
RESERVEDSECTORS = SECTORSPERCLUSTER + 4
FATCOPIES = RESERVEDSECTORS + 4
ROOTENTRIES = FATCOPIES + 4
SECTORSPERFAT = ROOTENTRIES + 4
ROOTSTART = SECTORSPERFAT + 4
ROOTSIZE = ROOTSTART + 4
DATASTART = ROOTSIZE + 4
POSITION = DATASTART + 4
CURRENTCLUSTER = POSITION + 4
OFFSET = CURRENTCLUSTER + 4
CURRENTPAGE = OFFSET + 4


;;
;; read basic information from FAT boot block
;; and do some basic computations regarding the fs layout
;;
.proc fat_init

	jsr fat_buffer_sector

	;; sectors per cluster
	lda BUFFERBASE + 13
	sta SECTORSPERCLUSTER

	;; reserved sectors
	lda BUFFERBASE + 14
	sta RESERVEDSECTORS

	;; number of FAT copies
	lda BUFFERBASE + 16
	sta FATCOPIES

	;; determine bytes per sector
	lda BUFFERBASE + 11
	sta BYTESPERSECTOR
	lda BUFFERBASE + 12
	sta BYTESPERSECTOR+1

	;; number of root directory entries
	lda BUFFERBASE + 17
	sta ROOTENTRIES
	lda BUFFERBASE + 18
	sta ROOTENTRIES+1

	;; sectors per FAT
	lda BUFFERBASE + 22
	sta SECTORSPERFAT
	lda BUFFERBASE + 23
	sta SECTORSPERFAT+1

	;; using put_address_lo for setting up math pointers
	;; this works as all our variables and constants are in
	;; page 0


	;; compute position of root directory
	;mul32 SECTORSPERFAT, FATCOPIES, ROOTSTART
	put_address_lo SECTORSPERFAT, MPTR1
	put_address_lo FATCOPIES, MPTR2
	put_address_lo ROOTSTART, MPTR3
	jsr math_mul32

	;add32 ROOTSTART, RESERVEDSECTORS, ROOTSTART
	put_address_lo ROOTSTART, MPTR1
	put_address_lo RESERVEDSECTORS, MPTR2
	jsr math_add32

	;; compute size of root directory
	;mul32 ROOTENTRIES, CONST32_32, ROOTSIZE
	put_address_lo ROOTENTRIES, MPTR1
	put_address_lo CONST32_32, MPTR2
	put_address_lo ROOTSIZE, MPTR3
	jsr math_mul32

	;div32 ROOTSIZE, BYTESPERSECTOR, ROOTSIZE, TMP
	put_address_lo ROOTSIZE, MPTR1
	put_address_lo BYTESPERSECTOR, MPTR2
	put_address_lo TMP, MPTR4
	jsr math_div32

	;; compute position of data region
	;; the two first entries in the FAT are special and don't point to data
	;; offset the start of the data region accordingly
	;mul32 SECTORSPERCLUSTER, CONST32_2, TMP4
	put_address_lo SECTORSPERCLUSTER, MPTR1
	put_address_lo CONST32_2, MPTR2
	put_address_lo TMP4, MPTR3
	jsr math_mul32
	;add32 ROOTSTART, ROOTSIZE, DATASTART
	put_address_lo ROOTSTART, MPTR1
	put_address_lo ROOTSIZE, MPTR2
	put_address_lo DATASTART, MPTR3
	jsr math_add32

	;sub32 DATASTART, TMP4, DATASTART
	put_address_lo DATASTART, MPTR1
	put_address_lo TMP4, MPTR2
	jsr math_sub32


	rts
.endproc

;;
;; loads sector denoted by (ARG1,ARG1+1,ARG1+2) into buffer
;;
.proc fat_buffer_sector
	lda #BUFFERPAGE
	sta ARG2
	jsr io_sd_read_block
	rts
.endproc



;;
;; Determines next cluster in chain.
;; Reads CURRENTCLUSTER and writes there as well.
;;
.proc fat_next_cluster
	push_ay

	;; compute sector for cluster entry
	;mul32 CURRENTCLUSTER, CONST32_2, ARG1		; each cluster entry is two bytes in FAT16
	put_address_lo CURRENTCLUSTER, MPTR1
	put_address_lo CONST32_2, MPTR2
	put_address_lo ARG1, MPTR3
	jsr math_mul32
	;div32 ARG1, BYTESPERSECTOR, ARG1, OFFSET	; compute sector position and byte offset
	put_address_lo ARG1, MPTR1
	put_address_lo BYTESPERSECTOR, MPTR2
	put_address_lo OFFSET, MPTR4
	jsr math_div32

	;add32 ARG1, RESERVEDSECTORS, ARG1			; add starting position of the FAT
	put_address_lo RESERVEDSECTORS, MPTR2
	jsr math_add32

	jsr fat_buffer_sector				; load sector with the relevant piece of the cluster chain

	jsr util_clear_arg1
	lda #BUFFERPAGE
	sta ARG1+1					; use ARG1 as pointer for a change
	add32 ARG1, OFFSET, ARG1	; add byte offset
	ldy #0
	lda (ARG1),y
	sta CURRENTCLUSTER
	iny
	lda (ARG1),y
	sta CURRENTCLUSTER+1

	pull_ay
	rts
.endproc



;;
;; Load complete cluster (as denoted by CURRENTCLUSTER) into pages starting with CURRENTPAGE.
;; Increments CURRENTPAGE accordingly.
;;
.proc fat_load_cluster
	push_ax


	;mul32 CURRENTCLUSTER, SECTORSPERCLUSTER, POSITION
	put_address_lo CURRENTCLUSTER, MPTR1
	put_address_lo SECTORSPERCLUSTER, MPTR2
	put_address_lo POSITION, MPTR3
	jsr math_mul32
	;add32 POSITION, DATASTART, POSITION
	put_address_lo POSITION, MPTR1
	put_address_lo DATASTART, MPTR2
	jsr math_add32

	;; argument to advance sector position
	put_address_lo CONST32_1, MPTR2

	ldx #0
	stx RET			; return code: zero is OK
loop_sectors:

	lda CURRENTPAGE
	cmp #LASTLOADPAGE
	bcs out_of_mem	; if carry set: CURRENTPAGE >= LASTLOADPAGE

load:
	mov32 POSITION, ARG1
	lda CURRENTPAGE
	sta ARG2

	jsr io_sd_read_block

	;add32 POSITION, CONST32_1, POSITION		; advance sector position
	jsr math_add32
	inc CURRENTPAGE							; advance page...
	inc CURRENTPAGE							; ... two times (a sector is 512 bytes)
	inx
	cpx SECTORSPERCLUSTER
	bne loop_sectors

end:
	pull_ax
	rts

out_of_mem:
	lda #1			; return code: not OK
	sta RET
	bne end
.endproc


;;
;; This routine will try to find and load a file with a name matching S_AUTOEXEC
;;
.proc fat_load_autoexec
	;; ------------------------------------------------------------
	;; put down code for "file not found"
	;; ------------------------------------------------------------
	lda #$FF
	sta CURRENTCLUSTER
	sta CURRENTCLUSTER+1

	;; ------------------------------------------------------------
	;; loop over every sector of root dir
	;; ------------------------------------------------------------
	ldx #0
loop_sectors:

	jsr util_clear_arg1
	stx ARG1
	add32 ARG1, ROOTSTART, ARG1
	jsr fat_buffer_sector
	jsr fat_find_autoexec_in_buffer

	inx
	cpx ROOTSIZE
	bne loop_sectors

	;; check if a file was found
	lda CURRENTCLUSTER
	cmp #$FF
	bne load
	lda CURRENTCLUSTER+1
	cmp #$FF
	bne load

	;; file not found, store non-zero return code
	sta RET
	beq end

	;; ------------------------------------------------------------
	;; load file
	;; ------------------------------------------------------------
load:
	lda #LOADPAGE			; starting page of load
	sta CURRENTPAGE

loop_cluster:
	jsr fat_load_cluster
	lda RET					; check for out-of-memory status
	bne end

	jsr fat_next_cluster

	;; check for end of cluster chain
	lda CURRENTCLUSTER
	cmp #$FF
	bne loop_cluster
	lda CURRENTCLUSTER+1
	cmp #$F8
	bcc loop_cluster
	
end:
	rts
.endproc

;;
;; Searches through a directory in the buffer.
;;
.proc fat_find_autoexec_in_buffer
	push_axy

	;; initialize position (memorized in ARG1)
	jsr util_clear_arg1
	lda #BUFFERPAGE
	sta ARG1+1
	
loop_entries:

	;; PTR1: Pointer to dir entry
	mov16 ARG1, PTR1

	;; ------------------------------------------------------------
	;; check status of directory entry
	;; ------------------------------------------------------------
	ldy #0
	lda (PTR1),y
	beq end				; entry empty, no subsequent entry
	cmp #$e5
	beq next_entry		; file deleted

	ldy #11
	lda (PTR1),y
	and #$02
	bne next_entry		; file hidden

	;; ------------------------------------------------------------
	;; compare file name of entry with S_AUTOEXEC
	;; ------------------------------------------------------------

	ldy #11
compare_filename:
	dey
	lda (PTR1),y
	cmp S_AUTOEXEC,y
	bne next_entry
	tya
	bne compare_filename


	;; ------------------------------------------------------------
	;; file name matches!
	;; ------------------------------------------------------------
	ldy #26
	lda (PTR1),y
	sta CURRENTCLUSTER
	iny
	lda (PTR1),y
	sta CURRENTCLUSTER+1
	jmp end

next_entry:
	;add32 ARG1, CONST32_32, ARG1		; advance position by 32 bytes
	put_address_lo ARG1, MPTR1
	put_address_lo CONST32_32, MPTR2
	put_address_lo ARG1, MPTR3
	jsr math_add32
	inx
	cpx #16								; iterate over 16 entries
	beq end
	jmp loop_entries

end:
	pull_axy
	rts
.endproc


