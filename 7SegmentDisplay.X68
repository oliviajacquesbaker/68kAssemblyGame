*-----------------------------------------------------------
* Title      : Programming 1 - 'Assignment 3: Assembly Game' - 7 SEGMENT DISPLAY
* Written by : Olivia Jacques-Baker
* Date       : 09/26/2022
* Description: Display any number 0-9 in seven segment display fashion. Uses several tables of information to accomplish this: there is a table of bitmasks, each value in this table will turn 'on' and 'off'
*              the lower 7 bytes of a 'display this segment' variable according to what the input number is via a logical AND. A second table is used to contain all the function pointers for each draw
*              function for the 7 segments. Each of these functions just sets up their respective input params and then calls the same 'draw rectangle according to params' function. Those input params are also
*              given via a table, which is a table of offset values that are added to the center point of the number in order to know where the boundaries of that particular rect are.
*              
*              Concerning the actual use of tables: to get the specific value from a table needed, first te start of the table is loaded in. Then, a variable signifying which number element in the table we 
*              need is loaded in. That index variable is multiplied by the size of the elements of that table. Then that resultant is added to the starting address of the table, putting it right at the start
*              of that index's contents.
*-----------------------------------------------------------

numberToDisplay_WithOffset      EQU     64
centerPointX_WithOffset         EQU     68
centerPointY_WithOffset         EQU     72
addressOfJumpOffset             EQU     8
totalNumberOfSegments           EQU     7

numberWidth         EQU     30
numberHeight        EQU     40
    
setPenColorCode     EQU     80
setFillColorCode    EQU     81
setPenWidthCode     EQU     93
drawRectCode        EQU     87

penWidth            EQU     1
penColor            EQU     $FFFFFF
fillColor           EQU     $FFFFFF

topOffset           EQU     4
rightOffset         EQU     8
bottomOffset        EQU     12    


********
*Draw a number passed in on the stack. The center point of the number should also be passed in via the stack in X and Y coordinates. 
********
DRAW_NUMBER:
        movem.l     allReg,-(sp)                        ;save off all registers
        move.l      numberToDisplay_WithOffset(sp),d6
        
        move.l      centerPointX_WithOffset(sp),d0      ;redraw background behind the number first
        move.l      centerPointY_WithOffset(sp),d1
        sub.l       #(numberWidth/2),d0                 ;moving by half dimensions since starting at center point
        sub.l       #(numberHeight/2),d1
        move.l      #numberWidth,d2
        move.l      #numberHeight,d3
        jsr         DRAW_BACKGROUND

        move.l      #penColor,d1                ;set pen color to be white
        move.l      #setPenColorCode,d0
        trap        #15        
        move.l      #fillColor,d1               ;set fill color to be white
        move.l      #setFillColorCode,d0
        trap        #15

        lea         bitmask,a0                  ;use out number as an address offset to get the bitmask for that number
        clr.l       d7
        move.b      (a0,d6),d7       
        lea         segmentFunctions,a5         ;load in the function table that holds the various segment functions
        move.l      #0,d5
LOOP_THROUGH_SEGMENTS:
        move.l      d5,d6                       ;using the bitmask, check if this segment (starting from G and moving towards A) should be colored in for this number
        move.l      #1,d0       
        and.b       d7,d0
        cmp.b       #1,d0
        bne         CHECK_SEGMENT_LOOP          ;if not, just skip ahead to where we check if we've looped through all segment possibilities
        lsl.l       #shiftForLong,d6            ;otherwise, we get which loop we're on, multiply by the size of a long, and use the function table to call to this segment's draw function
        move.l      (a5,d6),a6
        jsr         (a6)
CHECK_SEGMENT_LOOP:
        add.l       #1,d5                       ;add one to our loop counter
        lsr.l       #1,d7                       ;shift our bitmask to the next bit
        cmp.l       #totalNumberOfSegments,d5   ;if we haven't looped through 7 yet, do it again
        ble         LOOP_THROUGH_SEGMENTS
END_DRAW:
        movem.l     (sp)+,allReg                 ;restore registers and exit subroutine
        rts
        
        
        
********
*Draw segment G using G position table
********
DRAW_G: 
        lea         Gpositions,a1                ;prepare table for subroutine to reference
        jsr         DRAW_NUMBER_SEGMENT
        rts
 

********
*Draw segment F using F position table
********   
DRAW_F:
        lea         Fpositions,a1                ;prepare table for subroutine to reference
        jsr         DRAW_NUMBER_SEGMENT
        rts
  

********
*Draw segment E using E position table
********      
DRAW_E:
        lea         Epositions,a1                ;prepare table for subroutine to reference
        jsr         DRAW_NUMBER_SEGMENT
        rts
  

********
*Draw segment D using D position table
********      
DRAW_D:
        lea         Dpositions,a1                ;prepare table for subroutine to reference
        jsr         DRAW_NUMBER_SEGMENT
        rts
    

********
*Draw segment C using C position table
********    
DRAW_C:
        lea         Cpositions,a1                ;prepare table for subroutine to reference
        jsr         DRAW_NUMBER_SEGMENT
        rts
   

********
*Draw segment B using B position table
********     
DRAW_B:        
        lea         Bpositions,a1                ;prepare table for subroutine to reference
        jsr         DRAW_NUMBER_SEGMENT
        rts
      

********
*Draw segment A using A position table
********  
DRAW_A:
        lea         Apositions,a1               ;prepare table for subroutine to reference
        jsr         DRAW_NUMBER_SEGMENT
        rts



********
*Draw a rectangle. The position + size information for the rectangle will come from a table of values passed in via register a1
*Starts with the center position passed in on the stack and adds the offsets from the table.
********
DRAW_NUMBER_SEGMENT:
        move.l      (centerPointX_WithOffset+addressOfJumpOffset)(sp),d1    ;get our center position - offset comes from knowing this subroutine is called two subroutines deep
        move.l      (centerPointX_WithOffset+addressOfJumpOffset)(sp),d3
        move.l      (centerPointY_WithOffset+addressOfJumpOffset)(sp),d2
        move.l      (centerPointY_WithOffset+addressOfJumpOffset)(sp),d4
        add.w      (a1)+,d1                                                 ;add our position offsets set for this letter
        add.w      (a1)+,d2
        add.w      (a1)+,d3
        add.w      (a1),d4
        move.l      #drawRectCode,d0                                        ;draw the rectangle
        trap        #15
        rts


;variables for 7 segment display
bitmask         dc.b        $7E, $30, $6D, $79, $33, $5B, $5F, $70, $7F, $7B
segmentFunctions dc.l       DRAW_G,DRAW_F,DRAW_E,DRAW_D,DRAW_C,DRAW_B,DRAW_A

Apositions      dc.w        -4,-14,4,-10
Bpositions      dc.w        4,0,8,-12
Cpositions      dc.w        4,0,8,12
Dpositions      dc.w        -4,10,4,14
Epositions      dc.w        -8,0,-4,12
Fpositions      dc.w        -8,0,-4,-12
Gpositions      dc.w        -4,-2,4,2


































*~Font name~Courier New~
*~Font size~10~
*~Tab type~1~
*~Tab size~4~
