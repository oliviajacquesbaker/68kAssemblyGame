*-----------------------------------------------------------
* Title      : Programming 1 - 'Assignment 3: Assembly Game' - USER INPUT
* Written by : Olivia Jacques-Baker
* Date       : 10/16/2022
* Description: Handles user input events. All user input is handled through IRQ exceptions. This way lengthy draw calls do not have to be waited on to handle player input.
*              Mouse down events are used to check where the user is clicking, checking within the bounds of either the main menu buttons or the logo image depending on the game state.
*              If hard mode is enabled, then the mouse down in active play also checks the location of the logo to see if it is a valid time to be interacting with it.
*
*              Mouse up events are only used during active play - if the player had previously successfully clicked the logo, then releasing their mouse down key will trigger the logo slingshot.
*              This is done by calculating the distance between the mouse down position and the mouse up position and adding a (capped) permuation of this to the existing logo velocity. Adding instead
*              of replacing the velocity means the player doesn't have full control, adding difficulty.
*
*              Key down events are only used during the end menu, when the player is able to reset the game. Here, if they press a key, that key is also then flushed out so that it does not affect 
*              the end menu where the player can enter their name.
*-----------------------------------------------------------

;mouse IQR settings
enableMouseIRQCode  EQU     60
enableKeyIRQCode    EQU     62
readMouseCode       EQU     61
readSingleKeyCode   EQU     5
mouseStateOnlyCode  EQU     0
mouseDownOnlyCode   EQU     1
mouseUpOnlyCode     EQU     2
IRQLevel1Address    EQU     $64
IRQLevel2Address    EQU     $68
IRQLevel3Address    EQU     $6C
IRQ1MouseDownCombo  EQU     $0101
IRQ2MouseUpCombo    EQU     $0202
IRQ3KeyDownCombo    EQU     $0301

;main menu mouse settings
normalBtnX          EQU     188
hardBtnX            EQU     458
playBtnY            EQU     285
playBtnWidth        EQU     147
playBtnHeight       EQU     37


;reset input settings
ASCIIvaluesForR     EQU     $00005272
getKeyStateCode     EQU     19

;caps on user input velocity changes
maxDistForVelocity  EQU     $110



********
*The function called when there is a Mouse Down exception event
*Depending on which game state it is, makes calls to the appropriate mouse down functionality
********   
MOUSE_DOWN_IRQ:
        movem.l     allReg,-(sp)
        move.l      #readMouseCode,d0                   ;get the mouse position
        move.l      #mouseStateOnlyCode,d1
        trap        #15
        move.w      d1,d2                               ;save out X in d2
        lsr.l       #sizeOfByte,d1                      ;shift out X to leave only Y in d1
        lsr.l       #sizeOfByte,d1        
        cmp.b       #activePlayState,(gameState)        ;if we're in active play jump to suboutine to check logo press
        bne         SKIP_ACTIVE_DOWN
        jsr         ACTIVE_PLAY_MOUSE_DOWN          
SKIP_ACTIVE_DOWN:
        cmp.b       #mainMenuState,(gameState)          ;if we're in menu jump to subroutine to check button press
        bne         EXIT_MOUSE_DOWN_IRQ
        jsr         MAIN_MENU_MOUSE_DOWN        
EXIT_MOUSE_DOWN_IRQ:        
        movem.l     (sp)+,allReg
        rte                                             ;return from exception                
              
        
        
********
*The function called when there is a Mouse Up exception event
*Depending on which game state it is, makes calls to the appropriate mouse up functionality (only does something when in active play)
********        
MOUSE_UP_IRQ:
        movem.l     allReg,-(sp)
        cmp.b       #activePlayState,(gameState)         ;if we're not in active play this IRQ useless
        bne         EXIT_MOUSE_UP_IRQ
        jsr         ACTIVE_PLAY_MOUSE_UP
EXIT_MOUSE_UP_IRQ:        
        movem.l     (sp)+,allReg
        rte                                             ;return from exception




********
*Main Menu Mouse Down event: checks to see if the player clicked on one of the two valid buttons
********
MAIN_MENU_MOUSE_DOWN:
        cmp.l       #playBtnY,d1                        ;check to see if the click was within the vertical range of both buttons (they share vertical range)
        blt         END_MAIN_MENU_MOUSE_DOWN            ;if not, exit and don't bother checking horizontal cases
        cmp.l       #(playBtnY+playBtnHeight),d1
        bgt         END_MAIN_MENU_MOUSE_DOWN            
        cmp.l       #normalBtnX,d2                      ;if the X is less than the minimum X for the normal (left) btn, it's out of range of them both
        blt         END_MAIN_MENU_MOUSE_DOWN
        cmp.l       #(normalBtnX+playBtnWidth),d2       ;if it's within the range of the normal button..
        bgt         CHECK_HARD
        move.b      #0,(hardMode)                       ;make sure hard mode is turned off
        move.b      #activePlayState,(gameState)        ;and then set our game state to active play
        rts
CHECK_HARD:
        cmp.l       #hardBtnX,d2                        ;if it's within range of the hard button..
        blt         END_MAIN_MENU_MOUSE_DOWN
        cmp.l       #(hardBtnX+playBtnWidth),d2
        bgt         END_MAIN_MENU_MOUSE_DOWN
        move.b      #1,(hardMode)                       ;turn on hard mode flag
        move.b      #activePlayState,(gameState)        ;and set our game state to active play
END_MAIN_MENU_MOUSE_DOWN:
        rts



********
*Active Play Mouse Down event: check to see if the player clicked on the logo
********
ACTIVE_PLAY_MOUSE_DOWN:
        move.l      (logoXPosNoDecimal),d3
        cmp.l       d2,d3                               ;compare mouse X to start X of logo
        bge         END_ACTIVE_MOUSE_DOWN               ;exit interupt if not in range
        add.l       #(logoWidth),d3
        cmp.l       d2,d3                               ;compare mouse X to end X of logo
        ble         END_ACTIVE_MOUSE_DOWN               ;exit interupt if not in range
        move.l      (logoYPosNoDecimal),d3
        cmp.l       d1,d3                               ;compare mouse Y to start Y of logo
        bge         END_ACTIVE_MOUSE_DOWN               ;exit interupt if not in range
        add.l       #(logoHeight),d3
        cmp.l       d1,d3                               ;compare mouse Y to end Y of logo
        ble         END_ACTIVE_MOUSE_DOWN               ;exit interupt if not in range
        cmp.b       #1,(hardMode)                       ;if not in hard mode, don't need to check where the logo is
        bne         SET_FLAGS
        cmp.l       #(screenXMin+minDistanceToEdge),(logoXPosNoDecimal)                 ;check if logo is very close to the left 
        ble         SET_FLAGS    
        cmp.l       #(screenXMax-logoWidth-minDistanceToEdge),(logoXPosNoDecimal)       ;check if logo is very close to the right
        bge         SET_FLAGS   
        cmp.l       #(screenYMin+minDistanceToEdge),(logoYPosNoDecimal)                 ;check if logo is very close to the top
        ble         SET_FLAGS   
        cmp.l       #(screenYMax-logoHeight-minDistanceToEdge),(logoYPosNoDecimal)      ;check if logo is very close to the bottom
        bge         SET_FLAGS
        rts
SET_FLAGS:
        move.b      #1,(clickedTarget)                  ;if made it here, clicked on logo, so set flag + save off clicked position
        move.l      d2,(clickedXPos)
        move.l      d1,(clickedYPos)
        move.l      (currentColor),(prevColor)          ;save out current color and swap to highlight color
        move.l      #0,(currentColor)
END_ACTIVE_MOUSE_DOWN:
        rts



********
*Active Play Mouse Up event: if the player had previously clicked the logo properly, now update the logo's velocity based on the mouse movement
********
ACTIVE_PLAY_MOUSE_UP:
        cmp.b       #1,(clickedTarget)                  ;if we hadn't clicked on the logo before, ignore
        bne         END_ACTIVE_MOUSE_UP
        move.l      #readMouseCode,d0                   ;get the mouse position
        move.l      #mouseStateOnlyCode,d1
        trap        #15
        clr.l       d2
        move.w      d1,d2                               ;save out X in d2
        lsr.l       #sizeOfByte,d1                      ;shift out X to leave only Y in d1
        lsr.l       #sizeOfByte,d1                    
        cmp.w       #0,d2                               ;confirm we don't have negative values for x+y
        bge         SKIP_MOUSEX_NEG
        move.l      #0,d2                               ;if we do, just set it to zero (as that is the minimum of the window)
SKIP_MOUSEX_NEG:
        cmp.w       #0,d1
        bge         SKIP_MOUSEY_NEG
        move.l      #0,d1
SKIP_MOUSEY_NEG: 
        move.l      (clickedXPos),d3                    ;retrieve where the mouse had been clicked first
        move.l      (clickedYPos),d4
        sub.l       d3,d2                               ;get the difference in position from there to here
        sub.l       d4,d1
        cmp.l       #maxDistForVelocity,d2              ;limit the distance we got by the maximum distance variable
        ble         SKIP_MAX_XVEL_CAP
        move.l      #maxDistForVelocity,d2              ;setting it to this maximum when it goes over
SKIP_MAX_XVEL_CAP:
        cmp.l       #maxDistForVelocity,d1
        ble         SKIP_MAX_YVEL_CAP
        move.l      #maxDistForVelocity,d1
SKIP_MAX_YVEL_CAP:
        cmp.l       #-maxDistForVelocity,d2             ;in the case of negative position change, perform the same check but using the negative max distance
        bge         SKIP_MIN_XVEL_CAP
        move.l      #-maxDistForVelocity,d2
SKIP_MIN_XVEL_CAP:
        cmp.l       #-maxDistForVelocity,d1
        bge         SKIP_MIN_YVEL_CAP
        move.l      #-maxDistForVelocity,d1
SKIP_MIN_YVEL_CAP:        
        lsl.l       #speedMultiplier,d2                 ;multiply the differences to be on scale with our floating point velocity
        lsl.l       #speedMultiplier,d1
        move.l      (logoXVelocity),d3                  ;get our current velocity
        move.l      (logoYVelocity),d4
        cmp.l       #baseXVelocity,d3                   ;if current X velocity > base X, reset to base
        ble         SKIP_RESET_BIG_XVEL
        move.l      #baseXVelocity,d3
SKIP_RESET_BIG_XVEL:  
        cmp.l       #baseYVelocity,d4                   ;if current Y velocity > base Y, reset to base
        ble         SKIP_RESET_BIG_YVEL
        move.l      #baseYVelocity,d4
SKIP_RESET_BIG_YVEL:
        cmp.l       #-baseXVelocity,d3                  ;if current X velocity < -base X, reset to -base
        bge         SKIP_RESET_SMALL_XVEL 
        move.l      #-baseXVelocity,d3
SKIP_RESET_SMALL_XVEL:
        cmp.l       #-baseYVelocity,d4                  ;if current Y velocity < -base Y, reset to -base
        bge         SKIP_RESET_SMALL_YVEL  
        move.l      #-baseYVelocity,d4
SKIP_RESET_SMALL_YVEL:        
        add.l       d2,d3                               ;add new velocity components
        add.l       d1,d4
        move.l      d3,(logoXVelocity)                  ;set total to current velocity
        move.l      d4,(logoYVelocity)        
        move.b      #0,(clickedTarget)                  ;reset flag
        move.l      (prevColor),(currentColor)
END_ACTIVE_MOUSE_UP:
        rts





********
*Key Down event: check if the pressed key is one we care about for resetting the game
********
KEY_DOWN_IRQ:
        movem.l     allReg,-(sp)
        cmp.b       #endMenuState,(gameState)           ;only care about interupt if in end menu
        bne         END_KEY_DOWN_IRQ         
        move.l      #getKeyStateCode,d0                 ;check if the interrupt is for a key we care about
        move.l      #ASCIIvaluesForR,d1
        trap        #15
        cmp.l       #0,d1                               ;if either r or R was pressed, d1 > 0
        ble         END_KEY_DOWN_IRQ
        move.b      #activePlayState,(gameState)        ;now go play game   
        move.l       #readSingleKeyCode,d0              ;flush out that key input so it doesn't affect later reads
        trap         #15     
END_KEY_DOWN_IRQ:
        movem.l     (sp)+,allReg
        rte




;all variables for SUBROUTINE

hardMode             ds.b   1

clickedTarget        ds.b   1
clickedXPos          ds.l   1
clickedYPos          ds.l   1















*~Font name~Courier New~
*~Font size~10~
*~Tab type~1~
*~Tab size~4~
