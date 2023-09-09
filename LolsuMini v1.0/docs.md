# Overview
- Files included: Kernel_LolsuMini.asm, Game_Template.asm, Diagramm.pdf, Component_List.md, docs.md, compile.sh, write_ic.sh, LICENSE.md
- Date: 09.09.2023
- Author: Leo Harter
- Version: 1.0
- License: GNU General Public License

# Diagramm
Diagramm.pdf shows the architecture of the LolsuMini. Anyone can easily build their own LolsuMini using the Schematic.
In addition a component list is included for easy purchase of the necessary parts.

# Scripts
The two included scripts are used for compiling the .asm files and writing the machine code the the EEPROM.
They are specifically made for use with vasm, an XGecu Programmer and the parts used in Diagramm.pdf.
Altering any of these variables will not work with the scripts.

# Naming Conventions
- External Devices      ALL_CAPS (e.g. TWO_WORDS)
- Constant (Finals)     ALL_CAPS (e.g. TWO_WORDS)
- Other Variables       Title_Case (e.g. Two_Words)
- Subroutines           Pascal Case (e.g. TwoWords)
I recommend prefixing variables and subroutines unambiguously specific to a class
Personally I usually use 2-3 Letters Caps (e.g. Player.asm: Move => PLR_Move, GameManager.asm: DisplayScore => GM_DisplayScore)

# Variables
## Versatile Adapter Inteface / VIA (W65C22, 6522)
Var Name        Addr    Description
—————————————————————————————————————
VIA_PB          $6000   Port B (Either Output Register B, ORB; or Input Register B, IRB)
VIA_PA          $6001   Port A (Either Output Register A, ORA; or Input Register A, IRA)
VIA_DDRB        $6002   Data Direction Register B
VIA_DDRA        $6003   Data Direction Register A
VIA_SR          $600A   Shift Register
VIA_ACR         $600B   Auxiliary Control Register
VIA_PCR         $600C   Peripheral Control Register
VIA_IFR         $600D   Interrupt Flag Register
VIA_IER         $600E   Interrupt Enable Register

## Gamepad
Var Name        Addr    Description
—————————————————————————————————————
GP_DATA         $6001
GP_A            1 << 7
GP_B            1 << 6
GP_START        1 << 5
GP_SELECT       1 << 4
GP_RIGHT        1 << 3
GP_DOWN         1 << 2
GP_UP           1 << 1
GP_LEFT         1 << 0

## Kernel
Var Name        Addr    Description
—————————————————————————————————————
Timer           $00
Sprite_Memory   $0200   Sprite memory goes from $0200 to $02FF for 8 byte per Sprite and 32 Sprites
Sprite_X        $0200   X Position of the sprite, 0-128, $FF here means no sprite and will try to erase anything at the Old location
Sprite_Y        $0201   Y Position of the sprite, 0-64
Sprite_X_Old    $0202   X Position in the last frame
Sprite_Y_Old    $0203   Y Position in the last frame
Sprite_Free     $0204   May be used by the developer for easily managing various sprite-specific variables (e.g. health) in the same place
Sprite_Free1    $0205   For more complicated sprites (e.g. player) this could be used as a reference to another location
Sprite_Visual   $0206   2 Bytes referencing the location of the 8 bytes pixel data
Sprite_Visual1  $0207

# Subroutines
## API
Sub Name        Description
—————————————————————————————
StoreSR         Shifts A out to the LCD Display
LCD_Cmd         Switches the LCD Display to command mode (Modifies A)
LCD_Data        Switches the LCD Display to data mode (Modifies A)
LCD_Sel         Enables the LCD Display (Modifies A)
LCD_Dis         Disables the LCD Display (Modifies A)
LCD_Init        Initializes the LCD Display (Modifies A, X)
LCD_Page        Sets the current page of the LCD Display based on A (Modifies A, $01)
LCD_PageClear   Clears the current page on the LCD Display (Modifies A, X, $01)
LCD_Clear       Clears the entire screen of the LCD Display (Modifies A, X, Y, $01)
LCD_Column      Sets the current column of the LCD Display based on A (Modifies A, $01)
LCD_Byte        Draws the byte in A to the screen at column X and page Y (Modifies A, $01, $02, $03)

# Obstructed Names
- All Variables listed above
- All Subroutines listed above
- Anything starting with "Kernel_"
- "d_DisplaySetup"

# Future
The continuation of this project should include:
- A better optimized kernel
- A smaller kernel (preferably <512B)
- Block drawing
    - A one time 8x8 draw without continued position management like with sprites
    - Takes visuals at $0E/$0F, X and Y, to draw the sprite
    - Requires page alignment?

# Notes
The W65C02 could be replaced by a regular 6502 on the condition that Increment A (INA) calls are removed and an alternative implemented
