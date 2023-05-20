*-----------------------------------------------------------
* Title      : Programming 1 - 'Assignment 3: Assembly Game' - SCORE UTILITY AND DISPLAY
* Written by : Olivia Jacques-Baker
* Date       : 10/16/2022
* Description: This file manages all score utility and display functionality. This includes loading and saving high scores, displaying score information, and receiving input from the player to update
*              the high score file with later.
*
*              Initialization functions handle things that only have to happen once. The intialize active score subroutine sets up the label for the score, and the initialize end menu reads in the past
*              saved scores and determines if the player is in the top five. This is done by looping through the data of the text file with a very specific format - three bytes for the name, a colon, a space,
*              the score in two digit format, a null terminator, and then a carriage return and newline character. By looping through with an understanding of what goes where, it knows which characters 
*              represent the score in that record. It can then use the utility function string to int to convert the bytes from ASCII characters to actual integers by subtracting the base hex 30 off the code
*              and then simply combining the ones and tens digit appropriately. This integer can then be compared to the player's final score - if the player's score is at least as good as this score,
*              it is written in to the memory for the new high score sheet. If not, or if there is space after the player's score has been recorded, then the old high score is simply copied over into the new
*              list. If the player's score is copied over, it is done with a default '...' name and after converting the score from an int to ASCII codes in the reverse process as described before.
*
*              The player is shown all the loaded past high scores, and then one of two different prompts: either they placed in the top five, and are prompted to give a 3 letter name, or they did not, and
*              are just prompted to press 'R' to replay. If they are prompted to give a name, then there is a subroutine that watches for when they have, and once they have a flag is raised so that subroutine
*              knows to go back into the new high score data and replace the default name with the given one. If the player does not give a 3 character name, it is either shortened to the first 3 chars they gave
*              or the missing chars are filled in with '.' Then the new scores are loaded and re-shown on the screen to show that their name was updated, and they are also given a prompt to restart.
*           
*              The second the player gets a prompt to restart, there is also a subroutine that begins redrawing the active play screen background. This way, when the player presses R to replay, the process
*              has already begun so they wait less time.
*-----------------------------------------------------------

;score settings
closeAllFilesCode       EQU     50
openNewFileCode         EQU     52
openExistingFileCode    EQU     51 
readFileCode            EQU     53
writeFileCode           EQU     54
readKeyboardCode        EQU     2
drawTextCode            EQU     95
displayTextCode         EQU     14
setFontCode             EQU     21
clearScreenCode         EQU     $FF00
fontStyleSet            EQU     $01120000
fontStyleSetSmaller     EQU     $01090000
setTextCursor           EQU     11
expectedFileSize        EQU     $30
expectedLineSize        EQU     $0A
scoreDisplayX           EQU     50
scoreDisplayY           EQU     50
fontFillColor           EQU     0
numberOfTopScores       EQU     5
jumpToScoreNum          EQU     5
playerNameSize          EQU     3
playerScoreSize         EQU     2
activeScoreX            EQU     580
activeScoreY            EQU     447
activePlayFontFill      EQU     $2D3034
failsafeName            EQU     $002E2E2E
scoreNumberOffset       EQU     20


********
*Convert String to Integer: Utility function. Converts string in d0 to an int returned in d0 
********
CONVERT_STRING_TO_INT:
       movem.l      d1,-(sp)                        ;save off registers (individually since d0 will be returned)
       sub.l        #$3030,d0                       ;shave off those ascii codes
       move.l       d0,d1
       lsr.l        #sizeOfByte,d1                  ;get ones digit out of d1
       muls         #10,d1                          ;get tens digit to actually represent tens
       andi.l       #$000000FF,d0                   ;get tens digit out of d0
       add.l        d1,d0                           ;add tens and ones together
       movem.l      (sp)+,d1                        ;restore registers and return
       rts
       


********
*Convert Integer to String: Utility function. Converts an int in d0 to a string returned in d1 (tens) and d0 (ones) 
********
CONVERT_INT_TO_STRING:
       divu         #10,d0
       clr.l        d1
       move.w       d0,d1                           ;move tens into d1
       add.l        #$30,d1                         ;and convert to ascii
       lsr.l        #sizeOfByte,d0                  ;shift out tens so d0 only has ones
       lsr.l        #sizeOfByte,d0
       add.l        #$30,d0                         ;and convert to ascii
       rts



*********
*Draws the score on the active play screen
*********
DRAW_SCORE:
        ;movem.l      allReg,-(sp)                       ;save off registers      
        move.l      (score),d1
        divu        #10,d1                              ;separate tens and ones digits
        clr.l       d2  
        move.w      d1,d2                               ;save off tens digit in d2
        lsr.l       #sizeOfByte,d1
        lsr.l       #sizeOfByte,d1                      ;and ones into d1
        
        sub.l       #threeParamsOffset,sp               ;prepare to push subroutine params onto stack
        move.l      d2,numberToDisplay(sp) 
        move.l      #(scoreLocationX-scoreNumberOffset),centerPointX(sp)
        move.l      #(scoreLocationY),centerPointY(sp)
        jsr         DRAW_NUMBER                         ;call subroutine to draw tens digit
        add.l       #threeParamsOffset,sp               ;restore stack pointer
        
        sub.l       #threeParamsOffset,sp               ;prepare to push subroutine params onto stack
        move.l      d1,numberToDisplay(sp) 
        move.l      #(scoreLocationX+scoreNumberOffset),centerPointX(sp)
        move.l      #(scoreLocationY),centerPointY(sp)
        jsr         DRAW_NUMBER                         ;call subroutine to draw ones digit
        add.l       #threeParamsOffset,sp               ;restore stack pointer
        ;movem.l     (sp)+,allReg                        ;restore registers and return
        rts



********
*Initialize the score elements for active play; namely the label 'score' that is placed next to the actual active score
********
INITIALIZE_ACTIVE_SCORE:
        movem.l      allReg,-(sp)                    ;save off registers      
        move.l       #activePlayFontFill,d1          ;set fill color to be black
        move.l       #setFillColorCode,d0
        trap         #15    
        
        move.l       #setFontCode,d0                 ;set font to be bigger
        move.l       #penColor,d1
        move.l       #fontStyleSet,d2
        trap         #15
       
        lea          activeScore,a1                  ;load in the text we want and draw it at the set location
        move.l       #drawTextCode,d0
        move.l       #activeScoreX,d1
        move.l       #activeScoreY,d2
        trap         #15
        movem.l     (sp)+,allReg                     ;restore registers and return
        rts



********    
*Initialize End Menu: Complete initial read of saved scores, comparison of player score, and displays scores
********      
INITIALIZE_END_MENU:
       move.w      #0,(playerWonFlag)               ;reset all flags
       move.w      #0,(needsUpdateFlag)
       move.w      #0,(gaveNameFlag)
       jsr         READ_SCORE_FILE                  ;read in the last saved scores, update them if need be, and then show them to the player
       jsr         UPDATE_SCORES
       jsr         DISPLAY_SCORES
       rts


********
*Check for Prepare Game: check to see if the game can be prepared for a replay now
********
CHECK_FOR_PREPARE_GAME:
       cmp.w       #1,(playerWonFlag)                   ;if player didn't place in the high scores, won't need later update... so just prepare now
       beq         SKIP_PREPARE
       jsr         PREPARE_NEXT_GAME_BG
SKIP_PREPARE:
       rts
    

********
*Manage End Menu: watch for whether the player gives a name. If they do, update the scores list to reflect that name, and then start preparing for a replay
********    
MANAGE_END_MENU:
       cmp.w       #1,(needsUpdateFlag)                 ;only go through these if marked for update (if player entered a name)
       bne         END_MANAGE_END_MENU
       jsr         UPDATE_PLAYER_NAME                   ;update the name in memory to write out later
       jsr         DISPLAY_SCORES                       ;display scores now with new name
       jsr         SWAP_BUFFERS
       jsr         PREPARE_NEXT_GAME_BG
END_MANAGE_END_MENU:
       rts
    
   

********
*Prepare the game BG for if the player replays it
********   
PREPARE_NEXT_GAME_BG:
       movem.l      allReg,-(sp)                     ;save off registers
       move.l       #setTextCursor,d0                ;move cursor to be sort of centered
       move.l       (resetDisplayFeed),d1
       trap         #15
       
       move.l      #0,d0                             ;prepare the game screen on back buffer for when player replays
       move.l      #0,d1                             ;drawing the full thing since even the frame is erased for the end menu screen
       move.l      #backgroundWidth,d2
       move.l      #backgroundHeight,d3
       jsr         DRAW_BACKGROUND
       movem.l     (sp)+,allReg                     ;restore registers and return
       rts
 
    
********
*Update player name in memory to reflect what they gave as an answer
********
UPDATE_PLAYER_NAME:
       movem.l      allReg,-(sp)                     ;save off registers
       move.l       (playerNameMem),a0               ;pull up where we had saved was the 'placeholder' spot for the player's name within the high score list
       lea          playerNameInput,a1
       move.l       #playerNameSize,d0               ;then loop through and byte by byte copy over the first three letters of the name they gave
UPDATE_PLAYER_NAME_LOOP:
       move.b       (a1)+,(a0)+
       sub.l        #1,d0
       bne          UPDATE_PLAYER_NAME_LOOP       
       movem.l     (sp)+,allReg                     ;restore registers and return
       rts
       

********
*Read Score File: read in the saved out scores from a text file into memory
********
READ_SCORE_FILE:
       movem.l      allReg,-(sp)                     ;save off registers
       lea          scoresFileName,a1                ;open up the highscore.txt file. file ID will be put in d1
       move.l       #openExistingFileCode,d0
       trap         #15       
       lea          oldFileContent,a1               ;specify where we want the text file content to be saved within our memory
       move.l       #expectedFileSize,d2            ;and how much of it we want to save
       move.l       #readFileCode,d0                ;and then read it in
       trap         #15
       
       move.l       #closeAllFilesCode,d0           ;close the file
       trap         #15
       movem.l     (sp)+,allReg                     ;restore registers and return
       rts


********
*Write Score File: overwrite the previous text file with an updated version
********
WRITE_TO_SCORE_FILE:
       movem.l      allReg,-(sp)                     ;save off registers
       lea          scoresFileName,a1               ;open up the highscore.txt file as a new file, overwriting the old one
       move.l       #openNewFileCode,d0
       trap         #15
       lea          newFileContent,a1               ;specify which spot of memory we want to copy into the new file
       move.l       #expectedFileSize,d2            ;and how much of it we want to copy
       move.l       #writeFileCode,d0               ;then write it out
       trap         #15

       move.l       #closeAllFilesCode,d0           ;close the file
       trap         #15
       movem.l      (sp)+,allReg                    ;restore registers and return
       rts


********
*Update Scores: Prepare the data to overwrite the old high score text file, comparing the player's score to the saved ones
********
UPDATE_SCORES:
       movem.l      allReg,-(sp)                     ;save off registers
       move.l       #numberOfTopScores,d7           ;set up number of times to loop
       move.w       #0,(playerWonFlag)              ;reset player win flag
       lea          oldFileContent,a0               ;load up original scores + space for new ones
       lea          newFileContent,a2
       move.l       (score),d4       
LOOP_OLD_SCORES:
       move.l       a0,a1
       add.l        #jumpToScoreNum,a1              ;access the score in this row
       move.w       (a1),d0
       jsr          CONVERT_STRING_TO_INT
       cmp.w        d0,d4                           ;compare player score to this one
       blt          TRANSFER_SCORE_RECORD           ;if not as good, don't record player score
       cmp.w        #0,(playerWonFlag)              ;if already recorded player score, skip
       bne          TRANSFER_SCORE_RECORD           
       move.l       a2,(playerNameMem)              ;store where in memory the default player name is being put
       lea          playerName,a3
       move.l       #playerNameSize,d5              ;prepare loop over player name
PLAYER_NAME_LOOP:
       move.b       (a3)+,(a2)+                     ;copy over name data
       sub.l        #1,d5
       bne          PLAYER_NAME_LOOP
       
       add.l        #playerNameSize,a0              ;catch up in the old data stream
       move.b       (a0)+,(a2)+                     ;copy over the inbetween goodies (colon and space)
       move.b       (a0)+,(a2)+
       move.l       (score),d0
       jsr          CONVERT_INT_TO_STRING
       move.b       d1,(a2)+                        ;copy player score (comes back in d0 and d1)
       move.b       d0,(a2)+
       add.l        #playerScoreSize,a0             ;catch up in the old data stream
       move.b       (a0)+,(a2)+                     ;copy over null terminator
       move.b       (a0)+,(a2)+                     ;copy over the carriage return 
       move.b       (a0)+,(a2)+                     ;and line break
       
       move.w       #1,(playerWonFlag)
       sub.l        #expectedLineSize,a0            ;move back so we don't skip the one we compared with
 
       sub.l        #1,d7                           ;if this was the fifth one, don't copy last old score
       beq          END_UPDATE_SCORES
TRANSFER_SCORE_RECORD:
       move.l       #expectedLineSize,d6            ;prepare transfer loop
TRANSFER_SCORE_LOOP:
       move.b       (a0)+,(a2)+                     ;copy this byte over
       sub.l        #1,d6                           ;loop if not done with this line
       bne          TRANSFER_SCORE_LOOP
       
       sub.l        #1,d7                           ;loop if haven't copied 5 scores yet
       bne          LOOP_OLD_SCORES
       
END_UPDATE_SCORES:
       movem.l      (sp)+,allReg                    ;restore registers and return
       rts


********
*Display Scores: display the scores on screen for the player to read, as well as any prompts for the player to replay or to input player information
********
DISPLAY_SCORES:
       movem.l      allReg,-(sp)                     ;save off registers       
       move.l       #setTextCursor,d0                ;clear screen
       move.l       #clearScreenCode,d1
       trap         #15
       
       move.l       #fontFillColor,d1                ;set fill color to be black
       move.l       #setFillColorCode,d0
       trap         #15       
       move.l       #setFontCode,d0                 ;set font to be bigger
       move.l       #penColor,d1
       move.l       #fontStyleSet,d2
       trap         #15       
       move.l       (titleDisplayFeed),d1           ;grab variables for high score title
       lea          scoreTitle,a1
       jsr          SET_CURSOR_AND_DISPLAY_TEXT      
       
       move.l       #numberOfTopScores,d7           ;set up number of times to loop
       lea          newFileContent,a1               ;load in start of score info 
       move.l       (scoreDisplayFeed),d3  
DISPLAY_SCORE_LINE:
       move.l       d3,d1                           ;move our current feed value into correct variable for subroutine
       jsr          SET_CURSOR_AND_DISPLAY_TEXT
       
       add.l        #expectedLineSize,a1            ;move forward in the score text
       add.l        #$0001,d3                       ;move cursor down one line
       sub.l        #1,d7                           ;subtract one from our loop 
       bne          DISPLAY_SCORE_LINE              ;loop again if not zero
       
       move.l       #setFontCode,d0                 ;set font to be smaller
       move.l       #penColor,d1
       move.l       #fontStyleSetSmaller,d2
       trap         #15
       
       cmp.w        #0,(playerWonFlag)              ;jump to correct tagline display branch based on whether player placed among top five scores
       bne          DISPLAY_WINNING_TAGLINE
DISPLAY_LOSING_TAGLINE:
       move.l       (taglineDisplayFeedLose),d1     ;grab variables for losing restart prompt
       lea          loseText,a1
       jsr          SET_CURSOR_AND_DISPLAY_TEXT       
       movem.l      (sp)+,allReg                    ;restore registers and return (break early)
       rts              
DISPLAY_WINNING_TAGLINE:
       cmp.w        #0,(gaveNameFlag)               ;if the player already gave their name, then we want to just display the restart prompt
       bne          SKIP_PLAYER_NAME_UPDATE
       move.l       (taglineDisplayFeedWin),d1      ;grab variables for winning name entry prompt
       lea          winText,a1
       jsr          SET_CURSOR_AND_DISPLAY_TEXT       
       
       jsr          SWAP_BUFFERS                    ;let player see they are being prompted   
       clr.l        d1   
       lea          playerNameInput,a1              ;read in player input 
       move.l       #readKeyboardCode,d0
       trap         #15      
       cmp.w        #playerNameSize,d1              ;if the player didn't input at least 3 characters...
       bge          SKIP_NAME_FAILSAFE
       add.w        d1,a1                           ;...then as a failsafe, add in the backup string pre-prepared that is '...' + null terminator
       move.l       #failsafeName,d1
       move.l       #playerNameSize+1,d0
LOOP_FAILSAFE_NAME:
       move.b       d1,(a1)+                        ;done via a loop of moving bytes rather than moving the full long bc moving the full long caused an address error...
       lsr.l        #sizeOfByte,d1
       sub.l        #1,d0
       bne          LOOP_FAILSAFE_NAME
SKIP_NAME_FAILSAFE:
       move.w       #1,(needsUpdateFlag)            ;set flags that show the screen needs to be updated w new name 
       move.w       #1,(gaveNameFlag)               ;+ that player gave name so don't prompt again
SKIP_PLAYER_NAME_UPDATE:       
       move.l       (taglineDisplayFeedWin2),d1     ;grab variables for winning restart prompt
       lea          winText2,a1
       jsr          SET_CURSOR_AND_DISPLAY_TEXT
       movem.l      (sp)+,allReg                    ;restore registers and return
       rts


********
*Set cursor position and which text to display: a utility function
*Expects display feed in d1, text to display in a1
********
SET_CURSOR_AND_DISPLAY_TEXT:  
       move.l       #setTextCursor,d0               ;move cursor to start at given feed location
       trap         #15                 
       move.l       #displayTextCode,d0             ;write text to screen at cursor position
       trap         #15
       rts




;variables for SUBROUTINE
scoreTitle      dc.b    'HIGH SCORES',0
loseText        dc.b    'Not a winner this time.. try again by pressing "R"!',0
winText         dc.b    'You placed among the best! Enter your 3 LETTER name for the record:  ',0
winText2        dc.b    'Now if only you could get your name up there again... press "R" to play again!',0
activeScore     dc.b    ' Score:',0

scoresFileName  dc.b    'highscore.txt',0
oldFileContent  ds.b    expectedFileSize
newFileContent  ds.b    expectedFileSize

scoreDisplayFeed    dc.l    $1406
titleDisplayFeed    dc.l    $1204
taglineDisplayFeedLose  dc.l    $1619
taglineDisplayFeedWin   dc.l    $0A19
taglineDisplayFeedWin2   dc.l    $0819
resetDisplayFeed    dc.l    $0000

playerWonFlag   dc.w    0
needsUpdateFlag dc.w    0     
gaveNameFlag    dc.w    0          
playerName      dc.b    '...',0
playerNameMem   ds.l    1
playerNameInput ds.b    80              ;max string easy68k will take is 80 chars









*~Font name~Courier New~
*~Font size~10~
*~Tab type~1~
*~Tab size~4~
