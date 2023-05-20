*-----------------------------------------------------------
* Title      : Programming 1 - 'Assignment 3: Assembly Game' - MAIN GAME FILE
* Written by : Olivia Jacques-Baker
* Date       : 09/27/2022
* Description: The main game loop. Makes calls to the other programs, and manages the general game loop. The game loop branches out into three possible subloops: one for the main menu, one for 
*              active play, and one for the end menu. Each of these sub loops has a set of initialization functions called for that game state before it starts looping over the general management
*              functions for that particular game state. Once that game state is exited, that branching loop returns back to the main game loop, where it finds the new game state and branches out
*              to that new loop. 
*
*              This file also contains a large number of general purpose equates, intialization and reset functionality, and the subroutine called to swap the front and back buffers. See external files
*              for specifics on any of the functions called here that go beyond those things.
*
*              NOTE: This game relies on the use of IRQ events to handle user input. The initialization of the game should change your simulator settings to allow this.
*              However, if you find that clicking and etc has no effect whatsoever, please check: After you've pressed 'execute' and gotten the popups, go into the simulator options
*              And make sure 'enable exceptions' is checked. This was approved by you 10/15/22 - thank you!! and also best wishes please get well soon :')
*-----------------------------------------------------------

allReg              REG     d0-d7/a0-a6
allRegOffset        EQU     60

;screen resolution + buffering settings
displayWidth                EQU     800
displayHeight               EQU     480
setOutputResolutionCode     EQU     33
setDrawingModeCode          EQU     92
doubleBufferingCode         EQU     17
singleBufferingCode         EQU     16
repaintScreenCode           EQU     94
hardwareSimCode             EQU     32
enableExceptionsCode        EQU     $05

;game bounds + actor sizes info
logoWidth           EQU     105
logoHeight          EQU     55
backgroundWidth     EQU     800
backgroundHeight    EQU     480
screenXMin          EQU     23
screenXMax          EQU     779
screenYMin          EQU     19
screenYMax          EQU     410
minDistanceToEdge   EQU     10
minDistanceToScore  EQU     3
scoreLocationX      EQU     740
scoreLocationY      EQU     456


;stack offsets for drawing bitmaps
topLeftOfBitmapChunk_X      EQU     0
topLeftOfBitmapChunk_Y      EQU     4
widthOfBitmapChunk          EQU     8
heightOfBitmapChunk         EQU     12
topLeftOfDisplay_X      EQU     0
topLeftOfDisplay_Y      EQU     4
imageNumber             EQU     8

;stack offset for drawing numbers
numberToDisplay     EQU     0
centerPointX        EQU     4
centerPointY        EQU     8

;standard sizing equates
sizeOfWord          EQU     16
sizeOfByte          EQU     8
floatingPointBits   EQU     8
shiftForLong        EQU     2

;stack sizing for various param numbers
oneParamOffset      EQU     4
twoParamsOffset     EQU     8
threeParamsOffset   EQU     12
fourParamsOffset    EQU     16

;stack sizing for various param numbers + the allReg offset
oneParamOffsetWithRegs      EQU       64  
twoParamOffsetWithRegs      EQU       68
threeParamOffsetWithRegs    EQU       72
fourParamOffsetWithRegs     EQU       76

;general utitlity settings
getTimeCode         EQU     8
mainMenuState       EQU     0
activePlayState     EQU     1
endMenuState        EQU     2


START:  ORG         $1000

        jsr         INITIALIZE_GAME                     ;set initial var states, screen resolution, etc        
        jsr         SET_BG_TYPE_MENU                    ;tell the BG draw file that when we make this first call we want it to be on the menu bitmap
        move.l      #0,d0                               ;draw the main menu background
        move.l      #0,d1
        move.l      #backgroundWidth,d2
        move.l      #backgroundHeight,d3
        jsr         DRAW_BACKGROUND
        jsr         SWAP_BUFFERS                        ;swap buffers to show player + allow back buffer to get a preload on the next game state                                             
        
GAME_LOOP:
        cmp.b       #mainMenuState,(gameState)          ;if game state = 0, we're in the main menu
        bne         SKIP_MAIN_MENU
        jsr         GAME_STATE_0
SKIP_MAIN_MENU:  
        cmp.b       #activePlayState,(gameState)        ;if game state = 1, we're in active gameplay
        bne         SKIP_ACTIVE_PLAY
        jsr         GAME_STATE_1
SKIP_ACTIVE_PLAY:   
        cmp.b       #endMenuState,(gameState)           ;if game state = 2, we're in the end menu
        bne         SKIP_END_MENU
        jsr         GAME_STATE_2
SKIP_END_MENU:  
        bra         GAME_LOOP                           ;F in the chat for this sinner of an unconditional branch but this is our main game loop so forever and on it goes....

        SIMHALT                                         ;halt simulator


        ;include the files containing external functionality / subroutines
        INCLUDE     "ControlLogo.X68"
        INCLUDE     "Scores.X68"
        INCLUDE     "Timer.X68"
        INCLUDE     "UserInput.X68"
        INCLUDE     "RandomNumbersModified.X68"
        INCLUDE     "7SegmentDisplay.X68"
        INCLUDE     "DrawBackground.X68"
        INCLUDE     "DrawLogo.X68"


********
*Main Menu game state loop
********
GAME_STATE_0:                                           
        jsr         SET_BG_TYPE_ACTIVE_PLAY             ;set bg type for next draw call
        jsr         DRAW_CENTER_SCREEN                  ;draw the active play background on back buffer in prep for playing game
GAME_STATE_0_LOOP:
        cmp.b       #mainMenuState,(gameState)          ;if game state changes, break out of main menu loop
        beq         GAME_STATE_0_LOOP
        jsr         SWAP_BUFFERS                        ;show off that TV screen - we've broken the loop so we're moving on to the next scene which will need it
        rts
     
   
********
*Active Play game state loop
********        
GAME_STATE_1:                                           
        jsr         INITIALIZE_TIMER                    ;timer and score elements need to be reset each new play to set up labels and initial conditions
        jsr         INITIALIZE_ACTIVE_SCORE
        jsr         RESET_GAME                          ;more general variables reset here, logo position and etc
GAME_STATE_1_LOOP:
        jsr         UPDATE_LOGO                         ;updates position/velocity of logo
        jsr         REDRAW_BG                           ;redraw the portion of the BG that the logo had been before but isn't on now
     	jsr         DRAW_LOGO                           ;draw logo on top - redraw BG goes over the edge on each frame that logo bounces, so logo must be drawn second
        jsr         DRAW_SCORE                          ;keep score up to date in case player scored this frame
        jsr         UPDATE_TIMER                        ;update timer + timer display
        jsr         SWAP_BUFFERS
        cmp.b       #activePlayState,(gameState)        ;if game state changes, break out of active play loop
        beq         GAME_STATE_1_LOOP
        rts
     
   
********
*End Menu game state loop
********
GAME_STATE_2:                                           
        jsr         INITIALIZE_END_MENU                 ;get information about past saved scores and draw initial scores
        jsr         SWAP_BUFFERS                        ;show initial scores
        jsr         CHECK_FOR_PREPARE_GAME              ;if the player lost, start drawing the background for a replay
GAME_STATE_2_LOOP:        
        jsr         MANAGE_END_MENU                     ;if the player won, check for name input, + if so, start drawing the bg for a replay afterwards
        cmp.b       #endMenuState,(gameState)
        beq         GAME_STATE_2_LOOP                   ;if game state changes, break out of end menu loop
        jsr         WRITE_TO_SCORE_FILE                 ;before we leave end menu, save out the updated file
        rts
        

********
*End Game: called when time runs out
********        
END_GAME:
        move.b      #endMenuState,(gameState)           ;swap to end menus + out of active play
        rts


********
*Reset Game: set all general variables not handled by external files to their defaults
********
RESET_GAME:
        movem.l     allReg,-(sp)
        jsr         SET_BG_TYPE_ACTIVE_PLAY             ;let BG draw file know any upcoming calls to it will need the active play bitmap
        move.l      #startLogoXPos,(logoXPos)           ;initialize position and velocity for the logo
        move.l      #startLogoYPos,(logoYPos)
        move.l      #baseXVelocity,(logoXVelocity)
        move.l      #baseYVelocity,(logoYVelocity)
        move.l      (logoXPos),d0                      ;get the non decimal portion of our position components
        move.l      (logoYPos),d1
        asr.l       #8,d0
        asr.l       #8,d1
        move.l      d0,(logoXPosNoDecimal)             ;and update the variables that store that info for easy lookup later
        move.l      d1,(logoYPosNoDecimal) 
        move.l      d0,(logoXPosPrevNoDec)             ;and initialize prev values so no null compare on first frame
        move.l      d1,(logoYPosPrevNoDec)
        move.l      #3,(currentColor)                  ;set initial color (red my beloved) and score
        move.l      #0,(score)
        jsr         SEED_RANDOM_NUM                    ;seed the rng so it's different on each replay
        movem.l     (sp)+,allReg
        rts


********
*Initialize Game: set up general game settings that don't change throughout the lifetime of the program
********
INITIALIZE_GAME:
        movem.l     allReg,-(sp)
        move.b      #setOutputResolutionCode,d0         ;set the screen resolution
        move.l      #displayWidth,d1            
        swap.w      d1                              
        move.w      #displayHeight,d1
        trap        #15
        
        move.b	    #setDrawingModeCode,d0              ;set double buffering mode
      	move.b	    #doubleBufferingCode,d1
      	trap	    #15
      	
      	move.l      #hardwareSimCode,d0                 ;enable excpetion processing (IRQs)
      	move.b      #enableExceptionsCode,d1
      	trap        #15
      	move.l      #MOUSE_DOWN_IRQ,IRQLevel1Address    ;set where IRQ1 interupts should go
        move.l      #MOUSE_UP_IRQ,IRQLevel2Address      ;set where IRQ2 interupts should go
        move.l      #KEY_DOWN_IRQ,IRQLevel3Address      ;set where IRQ3 interupts should go
        move.l      #enableMouseIRQCode,d0              ;enable IRQ at level 1 to happen when mouse down
        move.l      #IRQ1MouseDownCombo,d1
        trap        #15
        move.l      #enableMouseIRQCode,d0              ;enable IRQ at level 2 to happen when mouse up
        move.l      #IRQ2MouseUpCombo,d1
        trap        #15
        move.l      #enableKeyIRQCode,d0                ;enable IRQ at level 3 to happen when key down
        move.l      #IRQ3KeyDownCombo,d1
        trap        #15
        
        move.l      #getTimeCode,d0                     ;set an initial value of lastTime so not null on first compare
        trap        #15
        move.l      d1,(lastTime)
        move.b      #0,(gameState)                      ;initially gameState is main menu
        move.b      #0,(hardMode)                       ;defaults to normal mode
      	movem.l     (sp)+,allReg
        rts


********
*Swap Buffers: exchange front and back buffers
********
SWAP_BUFFERS:
	    move.b      #repaintScreenCode,d0
        trap        #15
	    rts  

       

*variables that don't quite belong in any of the external files
currentColor         ds.l   1
prevColor            ds.l   1
score                ds.l   1
gameState            ds.b   1                         



    END    START        ; last line of source
















*~Font name~Courier New~
*~Font size~10~
*~Tab type~1~
*~Tab size~4~
