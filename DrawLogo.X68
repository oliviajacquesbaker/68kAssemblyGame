*-----------------------------------------------------------
* Title      : Programming 1 - 'Assignment 3: Assembly Game' - DRAW LOGO
* Written by : Olivia Jacques-Baker
* Date       : 10/14/2022
* Description: Display a full non-paleted 32bit bitmap file, ignoring alpha values. The parameters for this subroutine include an integer representing bmp file choice from a selection of colors,
*              and the x+y coordinates of the top left of the desired space on the display screen for the chunk to be drawn. All these parameters are passed into the subroutine via the stack.
*              The integer representing bmp fie is used as the index to a table of possible bmp files, shifting the index number by the size of a long (an address) and adding that to the start
*              of the table's address in order to access the correct bitmap. This is used in order to have multiple colored versions of the same basic logo bitmap.
*              The subroutine looks at the header information for the bitmap file before drawing. From the header, it pulls out the exact location of the pixel data.
*               
*              The actual drawing of pixels happens within a loop; the first half of the loop draws a pixel for each X in a row, then after that half it moves to the next row and starts back up at the
*              start of the loop to draw that new row pixel by pixel as well. When it completes the final row - which will be the upmost row, as the subroutine draws bottom to top - it will halt.
*
*              This file also contains a utility function that can be used to make easier calls to the above subroutine, utelized by other files.
*-----------------------------------------------------------

topLeftOfDisplay_X_WithOffset      EQU     64
topLeftOfDisplay_Y_WithOffset      EQU     68
imageNumber_WithOffset             EQU     72

logoHeaderInfoOffset        EQU     10

drawPixelCode               EQU     82
setPenColorCode             EQU     80


********
*Display Bitmap Logo: Draw the full logo. Expects the index of which bitmap to draw and the X+Y locations of where to draw it, passed via the stack.
******** 
DISPLAY_BITMAP_LOGO:           
        movem.l     allReg,-(sp)                        ;save off all registers
        ;for the duration of this subroutine, d0 and d1 are used for calculations + trap calls
        ;and all of the parameters passed in via the stack here remain in their initially assigned registers
        ;with the exception of d7+d2, which get updated as we move across the display screen to draw the full chunk
        lea         imageTable,a1
        move.l      imageNumber_WithOffset(sp),d0
        lsl.l       #2,d0
        move.l      (a1,d0),a0
        move.l      a0,a2
                   
        move.l      #0,d3                                   ;top left X of chunk should always be 0
        move.l      #0,d4                                   ;top left Y of chunk should always be 0
        move.l      #logoWidth,d5
        move.l      #logoHeight,d6
        move.l      topLeftOfDisplay_X_WithOffset(sp),d7                                   
        move.l      topLeftOfDisplay_Y_WithOffset(sp),d2        
        add.l       d6,d2                                   ;add the height to the starting display y so we can draw the image from bottom up
        
        add.l       #logoHeaderInfoOffset,a0                ;skip to where header contains info about pixel data
        move.l      (a0),d1                                 ;retrieve pixel offset number  
        rol.w       #8,d1                                   ;swap endian-ness
        swap.w      d1
        rol.w       #8,d1                    
        
        move.l      a2,a0                                   ;the offset to pixel data we got earlier and put in d1 counts from start of all bmp data, so reset to start
        add.l       d1,a0                                   ;then move forward using the offset to reach the pixel data                
DRAW_ROW_LOGO:                             
        move.l      (a0)+,d1                                ;get the color of this pixel as BGR
        lsr.l        #8,d1                                  ;get rid of the alpha component
        move.l      #setPenColorCode, d0                    ;set the pen color for the pixel
        trap        #15
        move.l      d7,d1
        move.l      #drawPixelCode,d0                       ;draw the pixel 
        trap        #15                             
        addi.l      #1,d7                                   ;move forward one display X to next pixel location
        
        move.l      topLeftOfDisplay_X_WithOffset(sp),d1    ;put start display X in d1, then add the width to it
        add.l       d5,d1
        cmp.l       d1,d7                                   ;check if that value is our current X, indicating end of this row     
        bne         DRAW_ROW_LOGO                           ;if not, loop back to draw another pixel in this row
        
        move.l      topLeftOfDisplay_X_WithOffset(sp),d7    ;reset display X to be start of row        
        subi.l      #1,d2                                   ;move up one display Y to next row
        cmp.l       topLeftOfDisplay_Y_WithOffset(sp),d2    ;check if we've made it up to the starting Y      
        bne         DRAW_ROW_LOGO                           ;loop to draw the next row  

        movem.l     (sp)+,allReg                            ;then restore registers and exit subroutine
        rts



********
*Draw Logo: a utility function called by other files to more easily organize a call to the above base subroutine
********
DRAW_LOGO:
        movem.l     allReg,-(sp)                          ;save off all registers
        move.l      (logoXPosNoDecimal),d0
        move.l      (logoYPosNoDecimal),d1
        sub.l       #threeParamsOffset,sp                 ;prepare to push all subroutine params onto stack
	    move.l      d0,topLeftOfDisplay_X(sp)             ;push all subroutine param onto stack
	    move.l      d1,topLeftOfDisplay_Y(sp)        
	    move.l      (currentColor),imageNumber(sp)
        jsr         DISPLAY_BITMAP_LOGO                   ;call subroutine        
        add.l       #threeParamsOffset,sp                 ;restore stack pointer
        movem.l     (sp)+,allReg                          ;then restore registers and exit subroutine
        rts
 


;all variables for SUBROUTINE

bitmapWidthLogo         dc.l    105
bitmapHeightLogo        dc.l    55

logo_white          INCBIN  "DVDLOGO\logo_white.bmp"
logo_yellow         INCBIN  "DVDLOGO\logo_yellow.bmp"
logo_green          INCBIN  "DVDLOGO\logo_green.bmp"
logo_red            INCBIN  "DVDLOGO\logo_red.bmp"
logo_blue           INCBIN  "DVDLOGO\logo_blue.bmp"
logo_pink           INCBIN  "DVDLOGO\logo_pink.bmp"

imageTable          dc.l    logo_white,logo_yellow,logo_green,logo_red,logo_blue,logo_pink














*~Font name~Courier New~
*~Font size~10~
*~Tab type~1~
*~Tab size~4~
