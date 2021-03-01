
SECTION "Intro", ROMX

Intro::
; Remove this line
; Put your code here!


    ld a,HIGH(wShadowOAM)
    ldh [hOAMHigh],a


    ld hl, wDvdLogoLoc
    ld b,13 ;13 metasprites
.MoveMetaSprite
    ld a, [hl+]
    add a, [hl]; Add Y-Velocity to Y-Position
    dec l
    ld [hl+], a
    
    
    cp 144 + 16 - 16 ; is it at the past the vertical edge of the screen?
    call nc, InvHL
    cp 16
    call c, InvHL

    inc l

    ;now we do the same for the X component

    ld a, [hl+]
    add a, [hl]
    dec l
    ld [hl+], a
    

    cp 160 + 8 - 8 * 3 ; is it past the horizontal edge of the screen?
    call nc, InvHL ;skip the velocity invert if it's not
    cp 8
    call c, InvHL

    inc l 
    
    dec b
    jr nz,.MoveMetaSprite

    call SetMetaspriteCoords


	rst WaitVBlank
	jr Intro


SECTION "Move Metasprite", ROM0
SetMetaspriteCoords::
    ld hl, wShadowOAM
    ld de, wDvdLogoLoc
    ld b,13 ;13 metasprites
.setMetasprites

    ld a, [de]; load y coord
    inc e
    inc e
    ld c, a; y -> c
    ld a, [de]; load x coord
    inc e
    inc de

    ld [hl], c;store y in shadow OAM
    inc l
    ld [hl+], a
    inc l
    inc hl; since the shadow OAM is aligned and each sprite is 4 bytes long, only every 4th inc needs to inc hl rather than just l.

    add a,8 ;the next sprite should be 8 px further down

    ld [hl], c     
    inc l
    ld [hl+], a    ; do this 2 more times for the other sprites
    inc l
    inc hl

    add a,8 

    ld [hl], c
    inc l
    ld [hl+], a
    inc l
    inc hl

    dec b
    jr nz,.setMetasprites

    ret

SECTION "InvHL",ROM0

InvHL::;hl gets inverted, a is destroyed
    ld a, [hl]
    cpl 
    inc a
    ld [hl],a
    ret

SECTION "Sprites", ROM0

SpriteTiles::
INCBIN "dvdvideo.bin"
SpriteTilesEnd::


SECTION "DvdLogoLoc", WRAM0,ALIGN[2]
wDvdLogoLoc::
    ds 4*13;struct of arrays. 4 bytes, y then y-velocity then x then x-velocity, times 13 metasprite structs


