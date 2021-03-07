
INCLUDE "defines.asm"


SECTION "Header", ROM0[$100]

	; This is your ROM's entry point
	; You have 4 bytes of code to do... something
	sub $11 ; This helps check if we're on CGB more efficiently
	jr EntryPoint

	; Make sure to allocate some space for the header, so no important
	; code gets put there and later overwritten by RGBFIX.
	; RGBFIX is designed to operate over a zero-filled header, so make
	; sure to put zeros regardless of the padding value. (This feature
	; was introduced in RGBDS 0.4.0, but the -MG etc flags were also
	; introduced in that version.)
	ds $150 - @, 0

EntryPoint:
	ldh [hConsoleType], a

Reset::
	di ; Disable interrupts while we set up

	; Kill sound
	xor a
	ldh [rNR52], a

	; Wait for VBlank and turn LCD off
.waitVBlank
	ldh a, [rLY]
	cp SCRN_Y
	jr c, .waitVBlank
	xor a
	ldh [rLCDC], a
	; Goal now: set up the minimum required to turn the LCD on again
	; A big chunk of it is to make sure the VBlank handler doesn't crash

	ld sp, wStackBottom

	ld a, BANK(OAMDMA)
	; No need to write bank number to HRAM, interrupts aren't active
	ld [rROMB0], a
	ld hl, OAMDMA
	lb bc, OAMDMA.end - OAMDMA, LOW(hOAMDMA)
.copyOAMDMA
	ld a, [hli]
	ldh [c], a
	inc c
	dec b
	jr nz, .copyOAMDMA

	; CGB palettes maybe, DMG ones always

	ld a, %11100100
	ld [hBGP],a
	ld [hOBP0],a
	ld [hOBP1],a

	; You will also need to reset your handlers' variables below
	; I recommend reading through, understanding, and customizing this file
	; in its entirety anyways. This whole file is the "global" game init,
	; so it's strongly tied to your own game.
	; I don't recommend clearing large amounts of RAM, nor to init things
	; here that can be initialized later.
	
	xor a
.zeroWRAM
    ld hl,$C000 ; start of WRAM
    ld bc, $2000 - STACK_SIZE ;8KB of RAM, dont erase stack
	rst Memset

	; Clear OAM, so it doesn't display garbage
	; This will get committed to hardware OAM after the end of the first
	; frame, but the hardware doesn't display it, so that's fine.
	ld hl, wShadowOAM
	ld c, NB_SPRITES * 4
	xor a
	rst MemsetSmall

.copySprites
    ld hl, $8000;start of VRAM
    ld de, SpriteTiles
    ld c, SpriteTilesEnd - SpriteTiles
	rst MemcpySmall

SetUpSprites:
    ld hl, wShadowOAM
    ld b,13 ;13 metasprites
    xor a ; a is literally only used as a shortcut for 0 here
	;and c isn't even used at all
.setUpMetaSpriteLoop
    lb de,3,0; 3 sprites per metasprite. e counts sprite ids, starting with 0

.setUpSpriteLoop
    inc l;skip y coord
    inc l;skip x coord

    ld [hl],e ;set tile number
    inc e;advance 2 tiles
    inc e
    inc l

    ld [hl+], a ;load 0. in front of bg, not flipped, palette 0

    dec d
    jr nz, .setUpSpriteLoop

	dec b
	jr nz,.setUpMetaSpriteLoop


	ld b,b
SetUpDvdLogoLoc:
    ld hl,wDvdLogoLoc
	ld de,$03D4; just get some data from the the middle of the rom. That'll be random enough.
	lb bc,1,13 ;2 13 metasprites. b is just a shortcut for the velocities, which will all be set to 1.
.loadRandomData
	ld a, [de]
	and %01111111;mask bit 7 so it cant be more than 127
	add 16;get it onto the screen
	ld [hl+],a ; y pos
	inc e
 
	rra 
	sbc a
	ccf
	adc 0
	ld [hl+], a ;y-velocity

	ld a, [de]; x pos
	and %01111111
	add 16;get it onto the screen
	ld [hl+],a 
	inc e

	rra 
	sbc a
	ccf
	adc 0
	ld [hl+],a; x-velocity

	dec c
	jr nz,.loadRandomData


    call SetMetaspriteCoords


	

	; Reset variables necessary for the VBlank handler to function correctly
	; But only those for now
	xor a
	ldh [hVBlankFlag], a
	ldh [hCanSoftReset], a
	ldh [hOAMHigh], a
	dec a ; ld a, $FF
	ldh [hHeldKeys], a

	
	; Load the correct ROM bank for later
	; Important to do it before enabling interrupts
	ld a, BANK(Intro)
	ldh [hCurROMBank], a
	ld [rROMB0], a

	; Select wanted interrupts here
	; You can also enable them later if you want
	ld a, IEF_VBLANK
	ldh [rIE], a
	xor a
	ei ; Only takes effect after the following instruction
	ldh [rIF], a ; Clears "accumulated" interrupts

	; Init shadow regs
	; xor a
	ldh [hSCY], a
	ldh [hSCX], a
	;
	ld a, %10000110 ;screen on, 8x16 sprites, everything else off
	ldh [hLCDC], a
	; And turn the LCD on!
	ldh [rLCDC], a


	; `Intro`'s bank has already been loaded earlier
	jp Intro

SECTION "OAM DMA routine", ROMX

; OAM DMA prevents access to most memory, but never HRAM.
; This routine starts an OAM DMA transfer, then waits for it to complete.
; It gets copied to HRAM and is called there from the VBlank handler
OAMDMA:
	ldh [rDMA], a
	ld a, NB_SPRITES
.wait
	dec a
	jr nz, .wait
	ret
.end

SECTION "Global vars", HRAM

; 0 if CGB (including DMG mode and GBA), non-zero for other models
hConsoleType:: db

; Copy of the currently-loaded ROM bank, so the handlers can restore it
; Make sure to always write to it before writing to ROMB0
; (Mind that if using ROMB1, you will run into problems)
hCurROMBank:: db


SECTION "OAM DMA", HRAM

hOAMDMA::
	ds OAMDMA.end - OAMDMA


SECTION UNION "Shadow OAM", WRAM0,ALIGN[8]

wShadowOAM::
	ds NB_SPRITES * 4


; This ensures that the stack is at the very end of WRAM
SECTION "Stack", WRAM0[$E000 - STACK_SIZE]

	ds STACK_SIZE
wStackBottom:

