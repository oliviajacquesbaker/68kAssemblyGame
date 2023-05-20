*-----------------------------------------------------------
* Title      : Programming 1 - 'Assignment 3: Assembly Game' - DRAW BACKGROUND BITMAP
* Written by : Olivia Jacques-Baker
* Date       : 10/06/2022
* Description: Handles all definitions for subroutines that require drawing a portion of the background bitmap(s). The bulk of the effort is the DISPLAY_BITMAP_BACKGROUND subroutine, which
*              displays a chunk of a non-paleted 32bit bitmap file, ignoring alpha values and optimized to work for background images, so the top left corner of the
*              bitmap being displayed will also correspond to the top left corner of where on the screen it will be displayed to.
*
*              The parameters for this subroutine include the x+y coordinates of the top left of the desired bitmap chunk, and the width and height of the desired bitmap chunk, all passed via the stack.
*              The decision of which bitmap to draw is between one of the two bitmaps loaded in at the bottom of this file; before calling to any of the draw functions here, the caller can also make a
*              call to set the bitmap between these two. Then, when drawing, the correct bitmap address will be fetched based on which variable is set - it defaults to the active play background bitmap.
*
*              Before drawing the bitmap chunk, the subroutine looks at the header information for the bitmap file. From the header, it pulls out the exact location of the pixel data. This is used to 
*              skip forward in memory to reach the correct location to start pulling pixel color info from.
*               
*              The subroutine also calculates any necessary offsets in the pixel data according to input params (i.e. if not the full height of the bitmap will be drawn) before beginning to draw.
*              The vertical offset is added via a loop to replicate the 'add this offset for each pixel in the image width' idea, since mulu.l is not an operation and the subroutine cannot simply multiply here.
*              The actual drawing of pixels also happens within a loop; the first half of the loop draws a pixel for each X in a row, then after that half it moves to the next row and starts back up at the
*              start of the loop to draw that new row pixel by pixel as well. In between rows, any necessary offsets are calculated (i.e. if only part of the row is being drawn based on chunk size or chunk
*              top x+y offsets. When it completes the final row - which will be the upmost row, as the subroutine draws bottom to top - it will halt.
*
*              On top of this main draw subroutine, there is also functionality to redraw only a select portion of the background bitmap based on logo movement. That subroutine takes the previous logo
*              position information and compares it with the current in order to only draw the fewest number of pixels possible to hide the old position of the bitmap... the rest of the 'old logo' will be 
*              covered when the 'new logo' is drawn. If the logo ever moves so fast that it is in an entirely different position, then this subroutine will redraw only the pixels necessary to hide the 
*              old logo regardless of how far the new logo has moved.
*
*              This file also contains several utility subroutines that are shortcuts to call 'draw just the screen of the background,' 'specify which bitmap to use,' and 'make a general call to the draw bmp'               
*-----------------------------------------------------------

topLeftOfChunk_X_WithOffset      EQU     64
topLeftOfChunk_Y_WithOffset      EQU     68
widthOfChunk_WithOffset          EQU     72
heightOfChunk_WithOffset         EQU     76

bgHeaderInfoOffset          EQU     10

drawPixelCode               EQU     82
setPenColorCode             EQU     80


********
*Draw Background: makes a call to draw a chunk of the background... bitmap depends on setting for menu vs active play
*Expects top left X and Y to be in d0 and d1, and chunk width and height to be in d2 and 3
********        
DRAW_BACKGROUND:
        sub.l       #fourParamsOffset,sp                ;prepare to push all subroutine params onto stack
	    move.l      d0,topLeftOfBitmapChunk_X(sp)       ;push all subroutine param onto stack
	    move.l      d1,topLeftOfBitmapChunk_Y(sp) 
	    move.l      d2,widthOfBitmapChunk(sp)
	    move.l      d3,heightOfBitmapChunk(sp)        
        jsr         DISPLAY_BITMAP_BACKGROUND           ;call subroutine        
        add.l       #fourParamsOffset,sp                ;restore stack pointer
        rts
        


*******
*Display Bitmap Background: the base subroutine that all other 'draw background' subroutines eventually call, drawing the bitmap pixel by pixel based on input params on the stack
*Input params should be top left X+Y of the bitmap chunk and Width+Height of the bitmap chunk, in that order on the stack.
*******
DISPLAY_BITMAP_BACKGROUND:   
        
        movem.l     allReg,-(sp)                        ;save off all registers        
        ;for the duration of this subroutine, d0 and d1 are used for calculations + trap calls
        ;and all of the parameters passed in via the stack here remain in their initially assigned registers
        ;with the exception of d7+d2, which get updated as we move across the display screen to draw the full chunk
        ;d7 and d2 a top left corner to draw, X and Y respectively        
        jsr         FETCH_BACKGROUND_FILE                   ;then retrieve the parameters from the stack
        move.l      topLeftOfChunk_X_WithOffset(sp),d3
        move.l      topLeftOfChunk_Y_WithOffset(sp),d4
        move.l      widthOfChunk_WithOffset(sp),d5
        move.l      heightOfChunk_WithOffset(sp),d6
        move.l      d3,d7                                   ;for the background, the top left corner to start drawing at will be the same coords as the top left of chunk
        move.l      d4,d2 
    
        add.l       d6,d2                                   ;add the height to the starting display y so we can draw the image from bottom up
        add.l       #bgHeaderInfoOffset,a0                  ;skip to where header contains info about pixel data
        move.l      (a0),d1                                 ;retrieve pixel offset number  
        rol.w       #8,d1                                   ;swap endian-ness
        swap.w      d1
        rol.w       #8,d1                    
        
        jsr         FETCH_BACKGROUND_FILE                   ;the offset to pixel data we got earlier and put in d1 counts from start of all bmp data, so reset to start
        add.l       d1,a0                                   ;then move forward using the offset to reach the pixel data

        move.l      (bitmapHeightBG),d0                     ;the pixel values start at the bottom of the picture, so if the chunk Y does not reach the full height
        sub.l       d6,d0                                   ;subtract the chunk height
        sub.l       d4,d0                                   ;subtract the chunk Y offset
        lsl.l       #2,d0                                   ;multiply by 4 (BGRA for each pixel skipped)
        move.l      (bitmapWidthBG),d1    
MOVE_Y_LOOP:
        add.l       d0,a0                                   ;since we can't multiply longs, just have to add this offset number once for each pixel in the image width (equivilant of multiplying by image width)
        sub.l       #1,d1
        bne         MOVE_Y_LOOP
        
        move.l      d3,d0                                   ;get number of pixels to skip at start of row (start X of chunk)
        lsl.l       #2,d0                                   ;multiply by 4 (BGRA for each pixel remaining)
        add.l       d0,a0                                   ;and move our pixel pointer forward that amount
DRAW_ROW:                             
        move.l      (a0)+,d1                                ;get the color of this pixel as BGR
        lsr.l       #8,d1                                   ;get rid of the alpha component
        
        move.l      #setPenColorCode, d0                    ;set the pen color for the pixel
        trap        #15
        
        move.l      d7,d1
        move.l      #drawPixelCode,d0                       ;draw the pixel 
        trap        #15                             
        addi.l      #1,d7                                   ;move forward one display X to next pixel location
        
        move.l      d3,d1                                   ;put start display X in d1, then add the width to it
        add.l       d5,d1
        cmp.l       d1,d7                                   ;check if that value is our current X, indicating end of this row     
        bne         DRAW_ROW                                ;if not, loop back to draw another pixel in this row
        
        move.l      d7,d0                                   ;subtract the display X offset from our current X to get the current X in the context of the image width
        sub.l       d3,d0
        add.l       d3,d0                                   ;add in the chunk X offset - it's already taken care of in another section, so don't want to take care of it a second time
        sub.l       (bitmapWidthBG),d0                      ;subtract the width of bitmap from current X
        neg.l       d0                                      ;then negate to get how many pixels are to the left on this row
        lsl.l       #2,d0                                   ;multiply by 4 (BGRA for each pixel remaining)
        add.l       d0,a0                                   ;and offset our location in the pixel data by this amount so we are at the start of the next row
        
        move.l      d3,d7                                   ;reset display X to be start of row
        move.l      d3,d0                                   ;get number of pixels to skip at start of row (start X of chunk)
        lsl.l       #2,d0                                   ;multiply by 4 (BGRA for each pixel remaining)
        add.l       d0,a0                                   ;and move our pixel pointer forward that amount
        
        subi.l      #1,d2                                   ;move up one display Y to next row
        cmp.l       d4,d2                                   ;check if we've made it up to the starting Y      
        bne         DRAW_ROW                                ;loop to draw the next row  

        movem.l     (sp)+,allReg                            ;then restore registers and exit subroutine
        rts
        
        
        
*********
*Redraw Background: figures out how to redraw only the parts of the BG that need to be redrawn
*based on previous vs current logo position. makes calls to the above basic subroutine.
*********       
        
REDRAW_BG:   
        movem.l     allReg,-(sp)                        ;save off all registers     
        move.l      (logoXPosNoDecimal),d6              ;get the difference between this position and the last one
        move.l      (logoYPosNoDecimal),d7
        sub.l       (logoXPosPrevNoDec),d6
        bge         SKIP_NEG_X                          ;and make sure that difference is absolute (non negative)
        neg.l       d6       
SKIP_NEG_X:
        sub.l       (logoYPosPrevNoDec),d7
        bge         SKIP_NEG_Y
        neg.l       d7       
SKIP_NEG_Y:
        cmp.l       #logoWidth,d6                       ;if the distance moved is less than the dimensions of the logo, we calculate it special rather than redrawing over the whole space
        blt         SKIP_RESTRAIN_DISTX
        move.l      #logoHeight,d7                      ;if so, though, make sure to max d7 so we don't skip on next comparison(gauruntee fall through to draw full logo)
SKIP_RESTRAIN_DISTX:
        cmp.l       #logoHeight,d7
        blt         REDRAW_BOTTOM
        move.l      (logoXPosPrevNoDec),d0              ;redraw the full space where the logo had been
        move.l      (logoYPosPrevNoDec),d1
        move.l      #logoWidth,d2
        move.l      #logoHeight,d3
        jsr         DRAW_BACKGROUND
        bra         END_REDRAW_BG                       ;im so sry utsab.... i couldn't figure out how to get rid of this one wo just copy pasting the return instructions themselves :(
        
REDRAW_BOTTOM:
        cmp.l       #0,d7                               ;if there was no movement vertically at all, skip down to redrawing horizontal movement elements
        beq         REDRAW_LEFT
        cmp.w       #1,(movedWithPositiveY)             ;check motion indicator, not velocity, bc velocity couldve changed if we bounced this frame
        beq         REDRAW_TOP
        
        move.l      (logoXPosPrevNoDec),d0              ;use the previous position
        move.l      (logoYPosPrevNoDec),d1
        add.l       #logoHeight,d1                      ;add the height since we want to the bottom but calls are from the top left
        sub.l       d7,d1                               ;subtract the dist moved (and what will be the height of the bitmap being redrawn) so that we're back at that top left needed to call
        move.l      #logoWidth,d2                       ;we're drawing the entire width..
        move.l      d7,d3                               ;but only the fraction of the height equivilant to how far we moved
        jsr         DRAW_BACKGROUND        
REDRAW_TOP:
        cmp.w       #0,(movedWithPositiveY)             ;check motion indicator, not velocity, bc velocity could've changed if we bounced this frame
        beq         REDRAW_LEFT
        
        move.l      (logoXPosPrevNoDec),d0              ;use the previous position as a base
        move.l      (logoYPosPrevNoDec),d1
        move.l      #logoWidth,d2                       ;we're drawing the entire width...
        move.l      d7,d3                               ;but only the fraction of the height equivilant to how far we moved
        jsr         DRAW_BACKGROUND
REDRAW_LEFT:
        cmp.l       #0,d6                               ;if there was no horizontal movement, just skip to the end of this subroutine
        beq         END_REDRAW_BG
        cmp.w       #0,(movedWithPositiveX)             ;check with motion indicator rather than velocity bc velocity couldve changed if we bounced this frame
        beq         REDRAW_RIGHT
        
        move.l      (logoXPosPrevNoDec),d0              ;start with the previous position
        move.l      (logoYPosPrevNoDec),d1
        move.l      d6,d2                               ;the width is only equal to the horizontal amount we moved
        move.l      #logoHeight,d3                      ;but we draw the full height
        jsr         DRAW_BACKGROUND
REDRAW_RIGHT:
        cmp.w       #1,(movedWithPositiveX)             ;use motion indicator not velocity since velocity couldve changed if we bounced this frame
        beq         END_REDRAW_BG
        
        move.l      (logoXPosPrevNoDec),d0              ;start with the previous position
        add.l       #logoWidth,d0                       ;add the width since we draw from the top left and we want to be drawing on the right side
        sub.l       d6,d0                               ;but subtract the width of the chunk we'll be redrawing so we're actually on the left edge of the right side of redraw
        move.l      (logoYPosPrevNoDec),d1
        move.l      d6,d2                               ;width will only be equal to the horizontal movement amount
        move.l      #logoHeight,d3                      ;but we draw the full height
        jsr         DRAW_BACKGROUND      
END_REDRAW_BG:
        movem.l     (sp)+,allReg                        ;then restore registers and exit subroutine
        rts



********
*Draw Center Screen: draws only the center of the screen, since the frame doesn't change between main menu and active play
********         
DRAW_CENTER_SCREEN:
        move.l      #(screenXMin-5),d0                  ;use collision information to determine where the edges of the screen are and draw only within those                  
        move.l      #(screenYMin-5),d1
        move.l      #(screenXMax-ScreenXMin+10),d2
        move.l      #(screenYMax-ScreenYMin+10),d3
        jsr         DRAW_BACKGROUND
        
        
        
********
*Fetch Background File: load the correct bitmap into a0
********        
FETCH_BACKGROUND_FILE:
        lea         backgroundImage,a0                 ;based on whether the menu bitmap flag is up or not, load in the menu or active play bitmap into a0
        cmp.w       #1,(callTypeMenu)
        bne         SKIP_LOAD_MENU_BG
        lea         mainMenuImage,a0
SKIP_LOAD_MENU_BG:
        rts
        
        
        
********
*Set BG Type to Menu
********        
SET_BG_TYPE_MENU:
        move.w      #1,(callTypeMenu)
        rts
        
        
        
********
*Set BG Type to Active Play
********        
SET_BG_TYPE_ACTIVE_PLAY:
        move.w      #0,(callTypeMenu)
        rts

        

;all variables for SUBROUTINE

bitmapWidthBG       dc.l    800
bitmapHeightBG      dc.l    480
callTypeMenu        dc.w    0           ;normally just draws the active play image, but when this is flagged, draws the main menu image

backgroundImage     INCBIN  'DVDscreen.bmp'
mainMenuImage       INCBIN  'mainMenu.bmp'


















*~Font name~Courier New~
*~Font size~10~
*~Tab type~1~
*~Tab size~4~
