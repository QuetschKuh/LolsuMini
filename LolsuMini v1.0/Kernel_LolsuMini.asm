; File: Kernel_LolsuMini.asm
; Author: Leo Harter
; Date: 09.09.2023
; Version: 1.0
; License: GNU General Public License
;
; This is the kernel of the LolsuMini. It should be included with every game.
; Only modify this if you know what you are doing and are fine with the consequences.

; Memory Map:
; $00-$0D used by kernel
; $0E, $0F used for visual sprite reference in assisted sprite drawing (not implemented yet)
; $10-$1F used by kernel for temporary sprite storage
; $20-$FF free to use
; $0100-$01FF used by processor
; $0200-$02FF sprite memory
;
; Sprite Memory ($0200-$02FF):
; 32 sprites, 8 bytes per sprite: X, Y, Old X, Old Y, Free, Free, Reference to visuals
;
; Game Code is from $E000-$FBFF
; The game developer should just use .include Kernel_LolsuMini.asm at the top of their file
; Having Kernel_LolsuMini.md open on the side may be beneficial to avoid naming conflicts and better remember Kernel methods / API calls
; It is recommended to use the last 256-512 bytes ($FA00/$FB00-$FBFF) for sprite visuals, allowing for up to 16-32 sprites. The Kernel sets no restrictions on this however
;
; Kernel Code by that logic is from $FC00-$FFFF

;;;;;;;;;;;;;;;;;
;;; Variables ;;;
;;;;;;;;;;;;;;;;;
; Versatile Adapter Inteface / VIA (W65C22, 6522)
VIA_PB      = $6000   ; Port B (Either Output Register B, ORB; or Input Register B, IRB)
VIA_PA      = $6001   ; Port A (Either Output Register A, ORA; or Input Register A, IRA)
VIA_DDRB    = $6002   ; Data Direction Register B
VIA_DDRA    = $6003   ; Data Direction Register A
VIA_SR      = $600A   ; Shift Register
VIA_ACR     = $600B   ; Auxiliary Control Register
VIA_PCR     = $600C   ; Peripheral Control Register
VIA_IFR     = $600D   ; Interrupt Flag Register
VIA_IER     = $600E   ; Interrupt Enable Register

; Gamepad
GP_DATA     = $6001
GP_A        = 1 << 7
GP_B        = 1 << 6
GP_START    = 1 << 5
GP_SELECT   = 1 << 4
GP_RIGHT    = 1 << 3
GP_DOWN     = 1 << 2
GP_UP       = 1 << 1
GP_LEFT     = 1 << 0

; Kernel
Timer           = $00
Sprite_Memory   = $0200 ; Sprite memory goes from $0200 to $02FF for 8 byte per Sprite and 32 Sprites
Sprite_X        = $0200 ; X Position of the sprite, 0-128, $FF here means no sprite and will try to erase anything at the Old location
Sprite_Y        = $0201 ; Y Position of the sprite, 0-64
Sprite_X_Old    = $0202 ; X Position in the last frame
Sprite_Y_Old    = $0203 ; Y Position in the last frame
Sprite_Free     = $0204 ; May be used by the developer for easily managing various sprite-specific variables (e.g. health) in the same place
Sprite_Free1    = $0205 ; For more complicated sprites (e.g. player) this could be used as a reference to another location
Sprite_Visual   = $0206 ; 2 Bytes referencing the location of the 8 bytes pixel data
Sprite_Visual1  = $0207


;;;;;;;;;;;
;;; API ;;;
;;;;;;;;;;;
    .org $FC00
    .dw NMI
    .dw RES
    .dw IRQ
    
; Store into shift register and wait for shit out
; The JSR, NOP, and RTS add enough delay to have it shift out completely before the next store operation (18 cycles)
StoreSR:
    STA VIA_SR
    NOP
    RTS

; Switches to command mode for the LCD Display
; Modifies A
LCD_Cmd:
    LDA VIA_PB
    AND #%01111111
    STA VIA_PB
    RTS

; Switches to data mode for the LCD Display
; Modifies A
LCD_Data:
    LDA VIA_PB
    ORA #%10000000
    STA VIA_PB
    RTS

; Turns the LCD Chip Select (PB6) to low = enabled
; Modifies A
LCD_Sel:
    LDA VIA_PB
    AND #%10111111
    STA VIA_PB
    RTS

; Turns the LCD Chip Select (PB6) to high = disabled
; Modifies A
LCD_Dis:
    LDA VIA_PB
    ORA #%01000000
    STA VIA_PB
    RTS

; Initializes the LCD Display
; Modifies A and X
LCD_Init:
    JSR LCD_Sel     ; Make sure my guy is selected
    JSR LCD_Cmd     ; Set command mode

    LDX #$00        ; Load setup bytes through SR to the display
LCD_InitLoop:
    LDA d_DisplaySetup, X   ; Load setup byte
    JSR StoreSR             ; Store
    INX
    CPX #$0F
    BNE LCD_InitLoop        ; Loop if not all bytes have been shwooped
    RTS
    
; Sets the LCD page based on the value ($00-$08) loaded in the accumulator
; Modifies A
; Uses $01
LCD_Page:
    STA $01
    JSR LCD_Cmd
    LDA $01
    CLC
    ADC #$B0
    JSR StoreSR
    RTS
    
; Clears the current page
LCD_PageClear:
    JSR LCD_Cmd
    LDA #$00
    JSR LCD_Column
    JSR LCD_Data
    LDA #$00
    LDX #$00
LCD_PageClearLoop:
    JSR StoreSR
    INX
    CPX #$88
    BNE LCD_PageClearLoop
    RTS
    
; Clears the entire screen ending on page 7
LCD_Clear:
    JSR LCD_Cmd
    LDY #$00
LCD_ClearLoop:
    TYA
    JSR LCD_Page
    JSR LCD_PageClear
    INY
    CPY #$08
    BNE LCD_ClearLoop
    RTS

; Sets the LCD column based on the value in the accumulator
LCD_Column:
    STA $01
    JSR LCD_Cmd
    LDA $01
    LSR A           ; Shift right by 4
    LSR A
    LSR A
    LSR A
    ORA #%00010000  ; Upper bit command nybble
    JSR StoreSR
    LDA $01         
    AND #%00001111  ; Lower bit command nybble
    JSR StoreSR
    RTS
    
; Draws byte A to the screen at column X and page Y
; Occupies registers $02 and $03
DrawByte:
    STA $02
    STX $03
    TYA
    JSR LCD_Page
    LDA $03
    JSR LCD_Column
    JSR LCD_Data
    LDA $02
    JSR StoreSR
    RTS
    
;;;;;;;;;;;;;;
;;; Kernel ;;;
;;;;;;;;;;;;;;
d_DisplaySetup:
    .db $E2, $40, $A0, $C8, $A6, $A2, $2F, $F8, $00, $27, $81, $10, $AC, $00, $AF   ; Reset, Start line 0, ADC normal, Com reverse, Display normal, Bias 1/9, Booster regulator follower on, booster 4x, contrast, no indicator, display on

Kernel_RES:
    ; Setup VIA (65c22)
    LDA #%01111111  ; Disable interrupts
    STA VIA_IER
    
    LDA #$00        ; All in
    STA VIA_DDRA    ; Store direction A
    LDA #$FF        ; All out
    STA VIA_DDRB    ; Store direction B
    
    ; Setup ACR and PCR for SR
    LDA #$00        ; Reset shift register
    STA VIA_SR
    LDA #%01011000  ; Continuous interrupt, Timed interrupt, Shift out under control of PHI2, Latching disabled
    STA VIA_ACR     ; Store in ACR
    LDA #$00        ; Pulse output cb2
    STA VIA_PCR
    
    JSR LCD_Init    ; Initialize display
    JSR LCD_Clear   ; Clear screen
    
    ; Clear sprite memory (just in case)
    LDA #$00
    LDX #$00
Kernel_RESLoop:
    STA Sprite_X, X
    INX
    BNE Kernel_RESLoop
    
    LDA VIA_PB
    ORA #%00100000  ; Enable NMIs
    STA VIA_PB
    JMP ($FC02)     ; Jump to game code

; Since we want different behaviour after the sprite clear depending on if the sprite was just deleted or not we turn this into a subroutine
Kernel_SpriteClear:                 ; We start by clearing one page, if it is unaligned well have to clear another one later
    LDA Sprite_Y_Old, X             ; Set page (first shift Y pos to page scale)
    LSR A
    LSR A
    LSR A
    JSR LCD_Page
    LDA Sprite_X_Old, X             ; Set column
    JSR LCD_Column
    JSR LCD_Data                    ; Switch to data
    LDA #$00                        ; Load no pixels
    LDY #$00
Kernel_SpriteClearLoop:      ; Send 8 times
    JSR StoreSR
    INY
    CPY #$08
    BNE Kernel_SpriteClearLoop
    LDA Sprite_Y_Old, X             ; Check if sprite is unaligned
    AND #%00000111                  ; If it isn't aligned to one page we just additionally clear the next one
    BEQ Kernel_SpriteClearDone
Kernel_SpriteClearUnaligned:        ; Sprite is unaligned, clear 8 bytes on two seperate pages
    LDA Sprite_Y_Old, X
    LSR A
    LSR A
    LSR A
    INA                             ; Instruction only available on 65c02, use CLC ADC #$01 on old 6502
    JSR LCD_Page
    LDA Sprite_X_Old, X             ; Set column
    JSR LCD_Column
    JSR LCD_Data                    ; Switch to data
    LDA #$00                        ; Load no pixels
    LDY #$00
Kernel_SpriteClearUnalignedLoop:      ; Send 8 times
    JSR StoreSR
    INY
    CPY #$08
    BNE Kernel_SpriteClearUnalignedLoop
Kernel_SpriteClearDone:
    RTS
    
; Non-Maskable-Interrupt. Called 48 times per second (48Hz, ~21ms/call -> ~20800 ticks/call)
Kernel_NMI:
    INC Timer

; Draw sprites (X: Memory Offset/Sprite Counter, Y: Byte transmission counter, $05/$06: Visual reference)
Kernel_Sprites:
    LDX #$00
Kernel_SpriteLoop:
    
; Check if the sprite needs to be rendered or was recently deleted
Kernel_SpriteCheck:             ; We start with checking if the sprite exists
    LDA Sprite_X, X
    CMP #$FF
    BNE Kernel_SpriteCheckPos   ; Continue rendering sprite if X not $FF (= No Sprite here)
    CMP Sprite_X_Old, X
    BNE Kernel_SpriteCheckClear ; Little hack because branches limited in range, anyway
    JMP Kernel_SpriteDone       ; Skip render if old X also $FF (= Sprite has already been erased)
Kernel_SpriteCheckClear:
    JSR Kernel_SpriteClear      ; Clear sprite otherwise and skip rerendering
    JMP Kernel_SpriteDone
Kernel_SpriteCheckPos:          ; Now we check if the sprite has moved and therefore has to be rerendered
    LDA Sprite_X, X
    CMP Sprite_X_Old, X
    BNE Kernel_SpriteCheckDone
    LDA Sprite_Y, X
    CMP Sprite_Y_Old, X
    BNE Kernel_SpriteCheckDone  ; Another hack because the code is too long
    JMP Kernel_SpriteDone
Kernel_SpriteCheckDone:

; The fact that we're here now means that the sprite exists and has moved, meaning the old sprite should be deleted and rendered at the new location
    LDA Sprite_X_Old, X         ; Skip sprite clear if sprite is new
    CMP #$FF
    BEQ Kernel_SpriteDraw
    JSR Kernel_SpriteClear
    
; The sprite at the old position has been cleared, we may move on 
Kernel_SpriteDraw:
    LDA Sprite_Visual, X            ; Save reference to visuals to zeropage at $05,$06
    STA $05
    LDA Sprite_Visual + 1, X
    STA $06
    LDA Sprite_Y, X                 ; Check alignment
    AND #%00000111  
    BNE Kernel_SpriteDrawUnaligned
Kernel_SpriteDrawAligned:           ; The sprite is perfectly aligned on one page, we only need to draw on that page
    LDA Sprite_Y, X                 ; Set page (first shift Y pos to page scale)
    LSR A
    LSR A
    LSR A
    JSR LCD_Page
    LDA Sprite_X, X                 ; Set column
    JSR LCD_Column
    JSR LCD_Data                    ; Switch to data
    LDY #$00                        ; 
Kernel_SpriteDrawAlignedLoop:
    LDA ($05), Y
    JSR StoreSR
    INY
    CPY #$08
    BNE Kernel_SpriteDrawAlignedLoop
    JMP Kernel_SpriteDone

Kernel_SpriteDrawUnaligned:         ; The sprite isn't aligned, we need to split the sprite and draw it on two seperate pages
    LDA Sprite_Y, X     ; Store amount to shift
    AND #%00000111
    STA $07
    LDA #$08
    SEC
    SBC $07
    STA $07
    STX $08             ; Save X
    LDY #$00
Kernel_SpriteDrawUnalignedProcess:  ; Do 8 times (for every byte in the sprite)
    LDA ($05), Y        ; Copy sprite byte to upper page
    STA $18, Y
    LDA #$00            ; Clear byte of lower page
    STA $10, Y
    LDX #$00
Kernel_SpriteDrawUnalignedShift:
    CLC
    LDA $18, Y          ; Shift byte of upper page down by 1
    ROR A
    STA $18, Y          ; Shift bit into byte of lower page
    LDA $10, Y
    ROR A
    STA $10, Y
    INX                 ; Loop unless all bytes have been shifted
    CPX $07
    BNE Kernel_SpriteDrawUnalignedShift
    INY                 ; Repeat 8 times
    CPY #$08
    BNE Kernel_SpriteDrawUnalignedProcess
    LDX $08             ; Recover X
Kernel_SpriteDrawUnalignedDraw:     ; We may now actually draw the sprite
    LDA Sprite_Y, X     ; Select page
    LSR A
    LSR A
    LSR A
    STA $07             ; Store for next phase
    JSR LCD_Page
    LDA Sprite_X, X     ; Select column
    JSR LCD_Column
    JSR LCD_Data
    LDY #$00
Kernel_SpriteDrawUnalignedLoop0:    ; Draw upper page
    LDA $10, Y
    JSR StoreSR
    INY
    CPY #$08
    BNE Kernel_SpriteDrawUnalignedLoop0
    LDA $07             ; Prepare lower page
    INA                 ; common 65c02 instruction set w
    JSR LCD_Page
    LDA Sprite_X, X
    JSR LCD_Column
    JSR LCD_Data
    LDY #$00
Kernel_SpriteDrawUnalignedLoop1:    ; Draw lower page
    LDA $18, Y
    JSR StoreSR
    INY
    CPY #$08
    BNE Kernel_SpriteDrawUnalignedLoop1
    
; We're done with all the rendering, now clean up and do some finishing logic
Kernel_SpriteDone:
    LDA Sprite_X, X
    STA Sprite_X_Old, X
    LDA Sprite_Y, X
    STA Sprite_Y_Old, X
    TXA
    CLC
    ADC #$08
    TAX
    BEQ Kernel_SpritesDone
    JMP Kernel_SpriteLoop
    
Kernel_SpritesDone:
    ; All sprites drawn
    
Kernel_NMIEnd:
    JMP ($FC00)
    RTI
    
; Interrupt Request
Kernel_IRQ:
    ; Kernel IRQ Handling
    JMP ($FC04)
    RTI
    
;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; Three Reset Vectors ;;; $FFFA-$FFFF
;;;;;;;;;;;;;;;;;;;;;;;;;;;
    .org $FFFA
    .dw Kernel_NMI      ; NMI
    .dw Kernel_RES      ; Reset
    .dw Kernel_IRQ      ; IRQ
