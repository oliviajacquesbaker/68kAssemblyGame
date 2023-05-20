*-----------------------------------------------------------
* Title      : Programming 1 - 'Assignment 2: Bitmap Subroutine' SUBROUTINE FILE
* Written by : Olivia Jacques-Baker, based on code provided by Utsab Das.
* Date       : 10/16/2022
* Description: A modified version of the provided code sample 'RandomNumbers.' Modifications include basic rearrangement/renaming to match my own conventions, removing
*              unnecessary functionality, adding in an acceptable range of output random numbers, and ensuring that the output is an integer within that range.
*
*              Otherwise, the functionality remains the same as originally provided: there is a seed function that takes the time that the program starts/is seeded as a base value, saving
*              it to use as a base for randomizations later so that every time the player plays the game the randomization follows a different pattern.
*
*              The actual 'get random number' function is constrained to get a random byte, specifically one that is an integer between minNumber and maxNumber, inclusive. 
*              The base random-ness is done by looping over adding a random val (coming from the seed originally, then itself later on) to itself, and modifying this process only when this addition
*              causes an overflow. Then, after N loops of this, the bottom byte of this random var is used as the random 'float' which is then multiplied to the range of allowed values, which then has
*              the minimum added to it to keep it in range, and then +1 and shifting out the 'decimal bits' in order to turn it into an integer.
*-----------------------------------------------------------

;random number settings
maxNumber           EQU       5
minNumber           EQU       1
numberOfLoops       EQU       18


********
*Seed Random Number: Set initial randomization based on time of seed so that randomization sequences vary from play to play
********
SEED_RANDOM_NUM:
        movem.l      allReg,-(sp)            ;save off registers
        clr.l        d6
        move.b       #getTimeCode,d0         ;get the current time to use as random seed
        TRAP         #15
        move.l       d1,(randomVal)          ;save our seed to be used in future calls 
        movem.l      (sp)+,allReg            ;restore registers and return
        rts


********
*Get Random Byte into D6: Get a random integer between minNumber and maxNumber, inclusive, into d6
********
GET_RAND_BYTE_D6:
        movem.l      d0,-(sp)                ;save off registers (individually since d6 will be returned)
        movem.l      d1,-(sp)
        movem.l      d2,-(sp)            
        move.l       randomVal,d0
       	moveq	     #$AF-$100,d1
       	moveq	     #numberOfLoops,d2                  
ADJUST_RAND:	
	add.l	     d0,d0
	bcc	     LOOP_RAND               ;if there was overflow, modify
	eor.b	     d1,d0
LOOP_RAND:
	dbf	     d2,ADJUST_RAND          ;if d2 > 0, loop again and d2--
	
	move.l	     d0,randomVal            ;set our generated number to be new randomVal for next time
	clr.l	     d6
	move.b	     d0,d6                   ;take the bottom byte of randomVal and use as 2 decimal places
	
	move.l       #maxNumber,d0           ;get our range of allowed values
        sub.l        #minNumber,d0 
        add.l        #1,d0
        mulu         d0,d6                   ;multiply range by random number
        add.l        #minNumber,d6           ;and add minimum to put us within range
        lsr.l        #sizeOfByte,d6          ;now shift out the floating point to leave just the final random int
        add.l        #1,d6                   ;adjust for integer randomness rather than decimal	
    
        movem.l      (sp)+,d2                ;restore registers and return
        movem.l      (sp)+,d1
        movem.l      (sp)+,d0            
        rts
        



;all variables for SUBROUTINE
randomVal       ds.l    1
tempRandomLong  ds.l    1









*~Font name~Courier New~
*~Font size~10~
*~Tab type~1~
*~Tab size~8~
