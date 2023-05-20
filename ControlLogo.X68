*-----------------------------------------------------------
* Title      : Programming 1 - 'Assignment 3: Assembly Game' - LOGO CONTROL 
* Written by : Olivia Jacques-Baker
* Date       : 10/15/2022
* Description: Contains the single subroutine used to update the logo information, including velocity and position. If the velocity on any given frame is larger than the base velocity in either the X or Y
*              component, a negative acceleration is applied to slow the logo down to this base velocity. This is done with the formula of Velocity_current = Velocity_initial + Acceleration*Time. So the 
*              current time is retrieved, and the time of the previous frame is subtracted, and the aforementioned formula is used. Since it decelerates to a base X and Y velocity rather than decelerating
*              to zero or to a base combined velocity, this also means that the logo will always fight to return to its intended/uninterrupted behavior and path. This is a counter to the player being in
*              complete control and keeps the game from being too easy.
*   
*              Position is calculated by adding the X and Y velocities to the previous position. Then collision is handled by checking if the new X,Y position of the logo goes past any of the screen
*              boundaries. If it does, the logo snaps to the edge (so that it does not spill over the edge) and velocity is negated in that direction. A bounce is flagged, so if they manage two bounces
*              in one frame (AKA the player hit a perfect corner shot) then the score gets an additional point. If it only bounces once, there will be a follow-up check to see if perhaps the logo got
*              extremly close to the direction (aka horizontal if it bounced veritcal), and if so, award a point despite a non perfect bounce. This gives leniancy and helps the game feel more natural.
*
*              The color of the logo changes randomly on each bounce, also. At the end of the collision checks, if the 'bounce' flag was ever set, there is a call to the RNG to get a random int between
*              1-5, inclusive. That is then the index of the logo bitmap that is passed to the bitmap drawer for the logo later.
*
*              This file also handles fixed point math. The velocity and position values of the logo hav 8 decimal bits each. The only exception to this are the variables specifically named varNameNoDecimal
*              or similar; these variables are meant to be used as easy lookup of the on screen position of the logo as opposed to the tracked mathematical/precise position.
*-----------------------------------------------------------

;physics settings
startLogoXPos       EQU     15800
startLogoYPos       EQU     15800
baseXVelocity       EQU     800
baseYVelocity       EQU     800
speedMultiplier     EQU     5
acceleration        EQU     -50


********
*Update Logo information. Applies acceleration to speed the logo down if it's currently above its base X or Y velocity and applies velocity to position. 
*Also handles collision between the logo and the screen boundary and recorrects position and velocity if a collision occurs.
********        
UPDATE_LOGO:   
        move.l      #getTimeCode,d0                                 ;get current time
        trap        #15
        move.l      d1,d7
        sub.l       (lastTime),d1                                   ;get difference between last time and now
        move.l      d7,(lastTime)                                   ;save off current time as new last time
        muls        #acceleration,d1                                ;multiply by acceleration (v = vInitial + a*t)
        move.l      d1,d2
        neg.l       d2                                              ;grab the negative version to add when velocity is negative
        
        cmp.l       #baseXVelocity,(logoXVelocity)                   ;if current X velocity > base X, reset to base
        ble         SKIP_ACCEL_BIG_XVEL
        add.l       d1,(logoXVelocity)
SKIP_ACCEL_BIG_XVEL:  
        cmp.l       #baseYVelocity,(logoYVelocity)                   ;if current Y velocity > base Y, reset to base
        ble         SKIP_ACCEL_BIG_YVEL
        add.l       d1,(logoYVelocity)
SKIP_ACCEL_BIG_YVEL:
        cmp.l       #-baseXVelocity,(logoXVelocity)                  ;if current X velocity < -base X, reset to -base
        bge         SKIP_ACCEL_SMALL_XVEL 
        add.l       d2,(logoXVelocity)
SKIP_ACCEL_SMALL_XVEL:
        cmp.l       #-baseYVelocity,(logoYVelocity)                  ;if current Y velocity < -base Y, reset to -base
        bge         SKIP_ACCEL_SMALL_YVEL  
        add.l       d2,(logoYVelocity)
SKIP_ACCEL_SMALL_YVEL:
MOVE_LOGO:
        move.l      (logoXPosNoDecimal),(logoXPosPrevNoDec)         ;save off current position to use in background redraw subroutine
        move.l      (logoYPosNoDecimal),(logoYPosPrevNoDec)
        move.w      #1,(movedWithPositiveX)                         ;reset our motion indicators (necessary since if on a bounce, we change velocity before our
        move.w      #1,(movedWithPositiveY)                         ;                             redraw bg function can tell what direction we came from)

        move.l      (logoXVelocity),d2                              ;add our velocity components to their respective position components
        move.l      (logoYVelocity),d3
        add.l       d2,(logoXPos)
        add.l       d3,(logoYPos)
        cmp.l       #0,d2                                           ;set the motion indicators to be accurate to the motion we just applied
        bge         MOVED_WITH_POS_X
        move.w      #0,(movedWithPositiveX)
MOVED_WITH_POS_X:
        cmp.l       #0,d3
        bge         MOVED_WITH_POS_Y
        move.w      #0,(movedWithPositiveY)
MOVED_WITH_POS_Y:
        move.l      (logoXPos),d0                                   ;get the non decimal portion of our position components
        move.l      (logoYPos),d1
        asr.l       #floatingPointBits,d0
        asr.l       #floatingPointBits,d1
        move.l      d0,(logoXPosNoDecimal)                          ;and update the variables that store that info for easy lookup later
        move.l      d1,(logoYPosNoDecimal)
        move.b      #0,(bounced)                                    ;reset bounced and scored flags for this frame
        move.b      #0,(scored)
CMP_LEFT_SCREEN:
        cmp.l       #screenXMin,(logoXPosNoDecimal)                 ;check if logo has gone too far left 
        bgt         CMP_RIGHT_SCREEN
        cmp.l       #0,(logoXVelocity)                              ;skip if already negated on previous frame
        bgt         FLAG_BOUNCE_LEFT
        neg.l       (logoXVelocity)                                 ;if so, negate horizontal velocity 
        move.l      #screenXMin,(logoXPosNoDecimal)                 ;and snap it to the edge so it's not going over
        move.l      (logoXPosNoDecimal),d0
        lsl.l       #floatingPointBits,d0
        move.l      d0,(logoXPos)      
FLAG_BOUNCE_LEFT:
        move.b      #1,(bounced)                                    ;even if velocity was negated on a prev frame, still need to know that it was on/over the edge in case of a score/color change        
CMP_RIGHT_SCREEN:
        cmp.l       #(screenXMax-logoWidth),(logoXPosNoDecimal)     ;check if logo has gone too far right
        blt         CMP_TOP_SCREEN
        cmp.l       #0,(logoXVelocity)                              ;skip if already negated on previous frame
        blt         FLAG_BOUNCE_RIGHT
        neg.l       (logoXVelocity)                                 ;if so, negate horizontal velocity
        move.l      #(screenXMax-logoWidth),(logoXPosNoDecimal)     ;and snap it to the edge so it's not going over
        move.l      (logoXPosNoDecimal),d0
        lsl.l       #floatingPointBits,d0
        move.l      d0,(logoXPos)
FLAG_BOUNCE_RIGHT:
        move.b      #1,(bounced)                                    ;even if velocity was negated on a prev frame, still need to know that it was on/over the edge in case of a score/color change        
CMP_TOP_SCREEN:
        cmp.l       #screenYMin,(logoYPosNoDecimal)                 ;check if logo has gone too far up
        bgt         CMP_BOTTOM_SCREEN
        cmp.l       #0,(logoYVelocity)                              ;skip if already negated on previous frame
        bgt         CHECK_SCORE_TOP
        neg.l       (logoYVelocity)                                 ;if so, negate vertical velocity 
        move.l      #screenYMin,(logoYPosNoDecimal)                 ;and snap it to the edge so it's not going over
        move.l      (logoYPosNoDecimal),d0
        lsl.l       #floatingPointBits,d0
        move.l      d0,(logoYPos)
CHECK_SCORE_TOP:
        cmp.b       #1,(bounced)                                    ;if we already counted a bounce horizontally, this means we scored!
        bne         FLAG_BOUNCE_TOP
        add.l       #1,(score)
        move.b      #1,(scored)
FLAG_BOUNCE_TOP:
        move.b      #1,(bounced)                                    ;even if velocity was negated on a prev frame, still need to know that it was on/over the edge in case of a score/color change        
CMP_BOTTOM_SCREEN:
        cmp.l       #(screenYMax-logoHeight),(logoYPosNoDecimal)    ;check if logo has gone too far down
        blt         END_UPDATE_LOGO
        cmp.l       #0,(logoYVelocity)                              ;skip if already negated on previous frame
        ble         CHECK_SCORE_BOTTOM
        neg.l       (logoYVelocity)                                 ;if so, negate vertical velocity 
        move.l      #(screenYMax-logoHeight),(logoYPosNoDecimal)    ;and snap it to the edge so it's not going over
        move.l      (logoYPosNoDecimal),d0              
        lsl.l       #floatingPointBits,d0
        move.l      d0,(logoYPos)
CHECK_SCORE_BOTTOM:
        cmp.b       #1,(bounced)                                    ;if we already counted a bounce horizontally, this means we scored!
        bne         FLAG_BOUNCE_BOTTOM
        add.l       #1,(score)
        move.b      #1,(scored)
FLAG_BOUNCE_BOTTOM:
        move.b      #1,(bounced)                                    ;even if velocity was negated on a prev frame, still need to know that it was on/over the edge in case of a score/color change
END_UPDATE_LOGO:  
        cmp.b       #1,(bounced)                                    ;if we boucned on this frame, change the color of the logo
        bne         RETURN_UPDATE_LOGO
GET_RAND_COLOR:
        jsr         GET_RAND_BYTE_D6                                ;use RNG to get a random int between 1-5 inclusive
        move.l      (currentColor),d5
        cmp.l       d6,d5                                           ;keep getting a random number until we have one that isn't equal to the current color
        beq         GET_RAND_COLOR
        move.l      d6,(currentColor)                               ;set as new color
        
        cmp.b       #1,(scored)                                     ;if we bounced but didn't score, check if we got reaaallly close to scoring for a bit of leniancy on the scoring system
        beq         RETURN_UPDATE_LOGO
        cmp.l       #(screenXMin+minDistanceToScore),(logoXPosNoDecimal)            ;if not close to left side, possible we're close to right side...
        ble         SKIP_COMP_OTHER_SIDE
        cmp.l       #(screenXMax-logoWidth-minDistanceToScore),(logoXPosNoDecimal)  ;if not close to right side, not possible to score even with leniancy, just return
        ble         RETURN_UPDATE_LOGO
SKIP_COMP_OTHER_SIDE:
        cmp.l       #(screenYMin+minDistanceToScore),(logoYPosNoDecimal)            ;if not close to top side, possible we're close to bottom side...
        ble         GIVE_SCORE_LENIANCY
        cmp.l       #(screenYMax-logoHeight-minDistanceToScore),(logoYPosNoDecimal)  ;if not close to bottom side, not possible to score even with leniancy, just return
        ble         RETURN_UPDATE_LOGO
GIVE_SCORE_LENIANCY:
        add.l       #1,(score)                                                      ;if the player got extremly close, just give them the point anyway (improves game feel)
        rts     
RETURN_UPDATE_LOGO:              
        rts




;all variables for SUBROUTINE

logoXPos             ds.l   1
logoYPos             ds.l   1
logoXPosNoDecimal    ds.l   1
logoYPosNoDecimal    ds.l   1
logoXPosPrevNoDec    ds.l   1
logoYPosPrevNoDec    ds.l   1

bounced              ds.b   1
scored               ds.b   1

logoXVelocity        ds.l   1
logoYVelocity        ds.l   1
movedWithPositiveX   ds.w   1
movedWithPositiveY   ds.w   1

lastTime             ds.l   1

















*~Font name~Courier New~
*~Font size~10~
*~Tab type~1~
*~Tab size~4~
