; File: Game_Template.asm
; Author: Leo Harter
; Date: 09.09.2023
; Version: 1.0
; License: GNU General Public License
;
; This is where you can actually write your game
; There is some example code included for better orientation
; For full documentation see docs.md
    
    .include "Kernel_LolsuMini.asm"

; Variables go here, available memory is $20-$FF, $0300-$1FFF
Last_Input      = $20   ; The Gamepad Input in the last frame, useful for checking if a button was just pressed

; Code goes here
    .org $E000
; Reset
RES:
    ; This code is executed when reset is pressed
    
    ; Sprite draw example
    ; This will draw sprite 1 (offset = $08 * x) as a sprite with visuals at location $FA00 at X 64 ($40) and Y 56 ($38)
    LDA #$00
    STA Sprite_Visual + $08
    LDA #$FA
    STA Sprite_Visual1 + $08
    LDA #$38
    STA Sprite_Y + $08
    LDA #$40
    STA Sprite_X + $08
    
InfLoop:
    JMP InfLoop

; Non Maskable Interrupt
NMI:
    ; This code is executed every frame (48 times per second)

    ; Gamepad button down example (Checks if a button is pressed down)
    LDA GP_DATA
    AND #GP_BUTTON      ; Possible values are: A, B, START, SELECT, UP, DOWN, LEFT, RIGHT
    BEQ ButtonDownEnd
    ; If execution reaches this, that means the button is pressed down, put your button logic right here
ButtonDownEnd:

    ; Gamepad button pressed example (Checks if a button was just pressed, fires once)
    LDA Last_Input
    EOR #$FF
    AND GP_DATA
    AND #GP_BUTTON
    BEQ ButtonPressEnd
    ; If execution reaches this, that means the button was just pushed down, put your one-time logic right here
ButtonPressEnd:
    
    
NMIEnd:
    ; Update last Last_Input
    LDA GP_DATA
    STA Last_Input

    RTI
    
IRQ:
    ; This code shouldn't ever be executed on the LolsuMini
    RTI

; Sprites go here
    .org $FA00
    .db %00000000, %00000000, %00000000, %00000000, %00000000, %00000000, %00000000, %00000000  ; Sprite 0, $FA00
    .db %00000000, %00000000, %00000000, %00000000, %00000000, %00000000, %00000000, %00000000  ; Sprite 1, $FA08
    .db %00000000, %00000000, %00000000, %00000000, %00000000, %00000000, %00000000, %00000000  ; Sprite 2, $FA10
    ; ... You have until $FC00 for sprites, you may also push this whole section earlier or later in order to have more or less space for sprites
