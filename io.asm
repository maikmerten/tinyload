IOBASE   = $FFD1	; register to read/write data from ACIA
IOSTATUS = $FFD0	; location of status register
IOCMD    = $FFD0	; location of command register
IOCMD_INIT = $15;	; init value for ACIA
IOSTATUS_RXFULL = $01;
IOSTATUS_TXEMPTY = $02;

SDDATA = $FFD8
SDSTATUS = $FFD9
SDCONTROL = $FFD9
SDLBA0 = $FFDA
SDLBA1 = $FFDB
SDLBA2 = $FFDC



;;
;; initialize input/output
;;
.proc io_init
	;; initialize ACIA
	lda #IOCMD_INIT
	sta IOCMD

	rts
.endproc


;;
;; Transmit single character to ACIA output device
;; a-register contains argument
;;
.proc io_write_char
	pha

readstatus:
	lda IOSTATUS	; load status register
	and #IOSTATUS_TXEMPTY        ; Is the tx register empty?
	beq readstatus	; busy waiting till ready

	pla		; get character
	sta IOBASE	; write to output

	rts		; end subroutine	
.endproc


;;
;; Transmit a 0-terminated string to output device
;;
.proc io_write_string
	push_ay

	ldy #$0
fetchnext:
	lda (ARG1),y
	beq exit
	jsr io_write_char
	iny
	jmp fetchnext
exit:
	pull_ay
	rts
.endproc


;;
;; read a 512-byte block from the SD card.
;; (ARG1,ARG1+1,ARG1+2): block index on SD card
;; (ARG2) and (ARG2)+1: pages to write data into
;;
.proc io_sd_read_block
	push_axy

wait:
	lda SDSTATUS
	cmp #128
	bne wait	

	lda ARG1
	sta SDLBA0
	lda ARG1+1
	sta SDLBA1
	lda ARG1+2
	sta SDLBA2

	lda #0
	sta ARG1
	sta SDCONTROL	; issue read command

	ldx ARG2	; dump into page (ARG2) and following page
	ldy #2		; read two chunks of 256 bytes
read_to_page:
	stx ARG1+1
	inx
	jsr io_sd_read_to_page
	dey
	bne read_to_page

	pull_axy
	rts
.endproc

;;
;; read 256 bytes and put it into page designated by (ARG1,ARG1+1)
;;
.proc io_sd_read_to_page
	push_ay

	ldy #0

loop:
	lda SDSTATUS
	cmp #224
	bne loop

	lda SDDATA
	sta (ARG1),y

	iny
	bne loop	; we're done once we wrap around to zero again

	pull_ay
	rts
.endproc





