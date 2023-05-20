*-----------------------------------------------------------
* Title      : Programming 1 - 'Assignment 3: Assembly Game' - TIMER
* Written by : Olivia Jacques-Baker
* Date       : 10/16/2022
* Description: Handles the game timer. When the timer is initialized, it saves the time at that very moment. Then, each time the timer is updated, it subtracts that original saved time from the current
*              one to get how many hundredths of a second have passed since the start of the game. The accuracy of this is shortened to only see how many full seconds have passed since the start,
*              which is then subtracted from the total alloted game time. This time is divided first by 60 to get how many full minutes are left, and then by 10 to get how many ones vs tens of seconds
*              are left. Each of these individual digits is drawn using the seven segment display.
*
*              Drawing the colon is handled as a separate function drawing two placed rectangles, and is also done only when the timer is intialized.
*
*              When there are zero seconds left aka the entire alloted game time has passed, the update timer subroutine calls the End Game subroutine.
*-----------------------------------------------------------

;timer settings
fullTimerSeconds    EQU     120
secondsPerMin       EQU     60
timerAccuracyLevel  EQU     100

centerXMinutes      EQU     140
centerXColon        EQU     160
centerXSeconds1     EQU     180
centerXSeconds2     EQU     210
centerYTimer        EQU     456

colonWidth          EQU     5

timerTextX          EQU     30
timerTextY          EQU     447



********
*Initialize Timer: get the time from the start of the game and draw the label for the timer
********
INITIALIZE_TIMER:
        movem.l     allReg,-(sp)              ;save off registers     	
        move.b      #getTimeCode,d0           ;get the current time in d1
        TRAP        #15
        move.l       d1,(startOfGame)         ;save as start of game time

        move.l      #fillColor,d1             ;set fill color to be white
        move.l      #setFillColorCode,d0
        trap        #15
        jsr         DRAW_COLON    
        move.l       #activePlayFontFill,d1   ;set fill color to be black
        move.l       #setFillColorCode,d0
        trap         #15            
        move.l       #setFontCode,d0          ;set font to be bigger
        move.l       #penColor,d1
        move.l       #fontStyleSet,d2
        trap         #15
       
        lea          timerText,a1             ;draw 'time: ' text
        move.l       #drawTextCode,d0
        move.l       #timerTextX,d1
        move.l       #timerTextY,d2
        trap         #15
        
        movem.l     (sp)+,allReg              ;restore registers and return
        rts



********
*Update Timer: Get the current time, and compare it with the time at the start of the game to get how many seconds have passed. 
*Subtract that number from the total number of game time seconds and draw to the timer.
********
UPDATE_TIMER:
     	movem.l     allReg,-(sp)            ;save off registers     	
        move.b      #getTimeCode,d0         ;get the current time in d1
        TRAP        #15
        sub.l       (startOfGame),d1        ;get time since start of game
        divu        #timerAccuracyLevel,d1  ;time is in hundreths of a second, bump out those decimals
        andi.l      #$0000FFFF,d1           ;clear out fractional hundreths of a second
        
        move.l      #fullTimerSeconds,d0    ;get time left in game based on time passed
        sub.l       d1,d0
        move.l      d0,d7                   ;save to check if time is up later              
        divu        #secondsPerMin,d0       ;get minutes in bottom half of d0, seconds in top half
        clr.l       d6
        move.w      d0,d6                   ;move minutes into d6
                                            ;draw minutes
        sub.l       #threeParamsOffset,sp   ;prepare to push subroutine params onto stack
        move.l      d6,numberToDisplay(sp) 
        move.l      #centerXMinutes,centerPointX(sp)
        move.l      #centerYTimer,centerPointY(sp)
        jsr         DRAW_NUMBER              ;call subroutine
        add.l       #threeParamsOffset,sp    ;restore stack pointer
        
        lsr.l       #sizeOfByte,d0           ;scoot out the minutes so we just have seconds in d0
        lsr.l       #sizeOfByte,d0
        divu        #10,d0                   ;get tens vs ones digit of seconds
        clr.l       d6
        move.w      d0,d6                   ;move tens of seconds into d6
                                            ;draw tens of seconds
        sub.l       #threeParamsOffset,sp   ;prepare to push subroutine params onto stack
        move.l      d6,numberToDisplay(sp) 
        move.l      #centerXSeconds1,centerPointX(sp)
        move.l      #centerYTimer,centerPointY(sp)
        jsr         DRAW_NUMBER              ;call subroutine
        add.l       #threeParamsOffset,sp    ;restore stack pointer        
        lsr.l       #sizeOfByte,d0           ;scoot out tens of seconds so d1 is only ones of seconds
        lsr.l       #sizeOfByte,d0                                    
                                            ;draw tens of seconds
        sub.l       #threeParamsOffset,sp   ;prepare to push subroutine params onto stack
        move.l      d0,numberToDisplay(sp) 
        move.l      #centerXSeconds2,centerPointX(sp)
        move.l      #centerYTimer,centerPointY(sp)
        jsr         DRAW_NUMBER              ;call subroutine
        add.l       #threeParamsOffset,sp    ;restore stack pointer
        
        cmp.l       #0,d7                   ;check that saved diff in time to see if time is up
        bgt         END_UPDATE_TIMER
        jsr         END_GAME  
END_UPDATE_TIMER:
        movem.l     (sp)+,allReg            ;restore registers and return
        rts
        


********
*Draw the colon that separates minutes and seconds
********
DRAW_COLON:
        move.l      #(centerXColon-colonWidth/2),d1      ;get upper colon dimensions/position
        move.l      #(centerYTimer-2*colonWidth),d2
        move.l      #(centerXColon+colonWidth/2),d3
        move.l      #(centerYTimer-colonWidth),d4        
        move.l      #drawRectCode,d0                     ;draw the rectangle
        trap        #15
        move.l      #(centerXColon-colonWidth/2),d1      ;get lower colon dimensions/position
        move.l      #(centerYTimer+colonWidth),d2
        move.l      #(centerXColon+colonWidth/2),d3
        move.l      #(centerYTimer+2*colonWidth),d4        
        move.l      #drawRectCode,d0                     ;draw the rectangle
        trap        #15
        rts




;all variables for SUBROUTINE

startOfGame          ds.l   1
currentTimer         ds.l   1
timerText            dc.b   'Time:',0



















*~Font name~Courier New~
*~Font size~10~
*~Tab type~1~
*~Tab size~4~
