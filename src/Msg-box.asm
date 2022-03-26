    SECTION "Message Box Variables",WRAM0

;-------------------------------------------------------------------------------

saved_scx: DS 1
saved_scy: DS 1

MESSAGE_BOX_HEIGHT EQU 8*5
MESSAGE_BOX_MSG_TILES_HEIGHT EQU 3 ; 2 tiles for the border

MESSAGE_BOX_Y   EQU (((144-MESSAGE_BOX_HEIGHT)/2)&(~7)) ; Align to 8 pixels
MESSAGE_BOX_SCY EQU (144-MESSAGE_BOX_Y)

message_box_enabled: DS 1 ; 1 if enabled

;###############################################################################

    SECTION "Message Box Functions Bank 0",ROM0

;-------------------------------------------------------------------------------

MessageBoxHandlerSTAT:

    ; This handler is only called if the message box is active, no need to check

    ; This is a critical section, but as we are inside an interrupt handler
    ; there is no need to use 'di' and 'ei' with WAIT_SCREEN_BLANK.

    ld      a,[rLYC]
    cp      a,MESSAGE_BOX_Y-1
    jr      nz,.hide

        ; Show

        WAIT_SCREEN_BLANK

        ld      a,[rLCDC]
        and     a,(~LCDCF_BG9C00) & $FF
        or      a,LCDCF_BG8000
        ld      [rLCDC],a

        ld      a,[rLCDC]
        and     a,(~LCDCF_BG9C00|LCDCF_BG8000) & $FF
        ld      [rLCDC],a

        xor     a,a
        ld      [rSCX],a
        ld      a,MESSAGE_BOX_SCY
        ld      [rSCY],a

        ld      a,MESSAGE_BOX_Y+MESSAGE_BOX_HEIGHT-1
        ld      [rLYC],a

        ret

.hide:
        ; Hide

        WAIT_SCREEN_BLANK

        ld      a,[rLCDC]
        or      a,LCDCF_BG9C00
        and     a,(~LCDCF_BG8000) & $FF
        ld      [rLCDC],a

        ld      a,[saved_scx]
        ld      [rSCX],a
        ld      a,[saved_scy]
        ld      [rSCY],a

        ld      a,MESSAGE_BOX_Y-1
        ld      [rLYC],a

        ret

;-------------------------------------------------------------------------------

MessageBoxHide::

    di

    WAIT_SCREEN_BLANK

    ld      a,[saved_scx]
    ld      [rSCX],a
    ld      a,[saved_scy]
    ld      [rSCY],a

        ld      a,[rLCDC]
        or      a,LCDCF_BG9C00
        and     a,(~LCDCF_BG8000) & $FF
        ld      [rLCDC],a

    xor     a,a
    ld      [rSTAT],a

    ld      bc,$0000
    call    irq_set_LCD

    ei

    xor     a,a
    ld      [message_box_enabled],a

    ret

;-------------------------------------------------------------------------------

MessageBoxShow::

    ld      a,1
    ld      [message_box_enabled],a

    ld      a,[rSCX]
    ld      [saved_scx],a
    ld      a,[rSCY]
    ld      [saved_scy],a

    ld      bc,MessageBoxHandlerSTAT
    call    irq_set_LCD

    ld      a,STATF_LYC
    ld      [rSTAT],a

    ld      hl,rIE
    set     1,[hl] ; enable STAT interrupt

    ret

;-------------------------------------------------------------------------------

MessageBoxIsShowing::

    ld      a,[message_box_enabled]

    ret

;-------------------------------------------------------------------------------

MessageBoxClear::

    xor     a,a
    ld      [rVBK],a

    ld      hl,$9800 + 32*19 + 1

    REPT    MESSAGE_BOX_MSG_TILES_HEIGHT

        ld      b,18
        ld      d,O_SPACE
.loop_clear\@:
        WAIT_SCREEN_BLANK ; Clobbers registers A and C
        ld      [hl],d
        inc     hl
        dec     b
        jr      nz,.loop_clear\@

        ld      de,32-18
        add     hl,de
    ENDR

    ret

;-------------------------------------------------------------------------------

MessageBoxPrint:: ; bc = pointer to string

    ; Clear message box

    push    bc ; (*) save pointer

    call    MessageBoxClear

    pop     bc ; (*) restore pointer

    ; Print message

    xor     a,a
    ld      [rVBK],a

    ld      hl,$9800 + 32*19 + 1

.loop:
    ld      a,[bc]
    inc     bc
    and     a,a
    ret     z ; Return if the character is a 0 (string terminator)

    cp      a,$0A ; $0A is a line feed character
    jr      nz,.not_line_jump
        ld      de,32
        add     hl,de

        ld      a,l
        and     a,(~31) & $FF ; align to next line
        inc     a ; skip first column
        ld      l,a

        jr      .loop ; continue
.not_line_jump:

    push    bc
    ld      b,a
    di
    WAIT_SCREEN_BLANK ; Clobbers registers A and C
    ld      a,b
    ld      [hl+],a
    ei
    pop     bc

    jr      .loop

;-------------------------------------------------------------------------------

MessageBoxPrintMessageID:: ; a = message ID

    ld      d,a ; save ID
    ld      b,ROM_BANK_TEXT_MSG
    call    rom_bank_push_set ; preserves de
    ld      a,d ; restore ID

    call    MessageRequestGetPointer ; a = message ID, returns hl = pointer

    LD_BC_HL
    call    MessageBoxPrint ; bc = pointer to string

    call    rom_bank_pop

    ret

;###############################################################################
