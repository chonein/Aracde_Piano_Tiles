# this is the code for piano keys
# Author: Christian Honein
# Trying to replicate the phone game piano keys
# Addresses for MMIO
#    localparam SWITCHES_AD = 32'h11000000; 
#    localparam VGA_READ_AD = 32'h11000160;
           
#   localparam LEDS_AD      = 32'h11000020;
#   localparam SSEG_AD     = 32'h11000040; 
#   localparam VGA_ADDR_AD = 32'h11000120;
#   localparam VGA_COLOR_AD = 32'h11000140;
#   localparam SPEAKER_AD = 32'h11000180;
#   localparam RAND_AD = 32'h11000200;
# game 2 left most and 2 right most switches
# raise the appropritate switch when a key reaches the reference red line
# the switch should be lowered before the next key
# only one switch should be raised at a time
# only has ode to joy, new songs could be easily added and implemented


.data
# store piano keys before they are displayed
PIANO_KEYS_QUEUE_ARR:	.byte	0x00	# keys[0]
			.byte	0x00	# keys[1]
			.byte	0x00	# keys[2]
			.byte	0x00	# keys[3]
PREV_RAND_NUM:		.word	0xFFFFFFFF	# previous random number
ODE_TO_JOY_NOTES:	.byte	17	# in the form of piezo input
			.byte	17
			.byte	18
			.byte	20
			.byte	20
			.byte	18
			.byte	17
			.byte	15
			.byte	13
			.byte	13
			.byte	15
			.byte	17
			.byte	17
			.byte	15
			.byte	15
			.byte	17	#
			.byte	17
			.byte	18
			.byte	20
			.byte	20
			.byte	18
			.byte	17
			.byte	15
			.byte	13
			.byte	13
			.byte	15
			.byte	17
			.byte	15
			.byte	13
			.byte	13
			.byte	15	#
			.byte	15	
			.byte	17
			.byte	13
			.byte	15
			.byte	17
			.byte	18
			.byte	17
			.byte	13
			.byte	15
			.byte	17
			.byte	18
			.byte	17
			.byte	15
			.byte	13
			.byte	15
			.byte	8
			.byte	17	#
			.byte	17
			.byte	18
			.byte	20
			.byte	20
			.byte	18
			.byte	17
			.byte	15
			.byte	13
			.byte	13
			.byte	15
			.byte	17
			.byte	15
			.byte	13
			.byte	13
			.byte	-1	# signifies end of song
			.space	1	# to finish at mem address div/4

ODE_TO_JOY_TIMES:	.byte	16	# times in the form of key height
			.byte	16
			.byte	16
			.byte	16
			.byte	16
			.byte	16
			.byte	16
			.byte	16
			.byte	16
			.byte	16
			.byte	16
			.byte	16
			.byte	16
			.byte	8
			.byte	8
			.byte	16	#
			.byte	16
			.byte	16
			.byte	16
			.byte	16
			.byte	16
			.byte	16
			.byte	16
			.byte	16
			.byte	16
			.byte	16
			.byte	16
			.byte	16
			.byte	8
			.byte	8
			.byte	16	#
			.byte	16	
			.byte	16
			.byte	16
			.byte	16
			.byte	8
			.byte	8
			.byte	16
			.byte	16
			.byte	16
			.byte	8
			.byte	8
			.byte	16
			.byte	16
			.byte	16
			.byte	16
			.byte	16
			.byte	16	#
			.byte	16
			.byte	16
			.byte	16
			.byte	16
			.byte	16
			.byte	16
			.byte	16
			.byte	16
			.byte	16
			.byte	16
			.byte	16
			.byte	16
			.byte	8
			.byte	8
			.byte	-1	# signifies end of song
			.space	1	# to finish at mem address div/4

# Not all of these are used, some are just for reference
.eqv BG_COLOR, 0x7B	 # light blue (4/7 red, 6/7 green, 3/3 blue)
.eqv FG_COLOR, 0x00	 # foreground color: black
.eqv VG_ADDR, 0x11000120
.eqv VG_COLOR, 0x11000140
.eqv VG_READ_AD, 0x11000160 # VG_ADDR + 0x40
.eqv LEDS_AD, 0x11000020
.eqv SWITCHES_AD, 0x11000000
.eqv RED_COLOR, 0xE0	# pure red (7/7 red only)
.eqv GREEN_COLOR, 0x1A	# pure green (7/7 green only)

.text
main:	# remaining registers s0, s1, s10, s11
	li	s11, 0xFFFFFFFF			# all 1 register, used for mie
	li 	sp, 0x10000     		#initialize stack pointer
	li	s2, VG_ADDR     		#load MMIO addresses 
	li	s3, VG_COLOR
	la	s4, PIANO_KEYS_QUEUE_ARR	# address for keys array 
	sw	x0, 0(s4)			# reset piano keys queue arr to all 0
	li	s5, SWITCHES_AD
	
	# address of the current playing song
	# This can be changed if new songs are added
	la	s6, ODE_TO_JOY_NOTES	# notes in reg s6
	la	s7, ODE_TO_JOY_TIMES	# times in reg s7
	li 	s8, 0	# index in song times arr
	li 	s9, 0	# index in song notes arr
	
	li	s10, 0	# score
	sh	s10, 0x40(s5)	# output score initially
	
	# fill screen using default color
	li	a3, BG_COLOR
	call	draw_background  # must not modify s2, s3
	
	# putting red lines on sides
	# lines used for reference for player
	# if removed, don't affect functioning of game
	li a3, RED_COLOR
	# 1st side
	li a0, 0  # from col 0
	li a1, 39 # row 39 moved from row 40
	li a2, 19 # to col 19
	call draw_horizontal_line
	# 2nd side
	li a0, 60  # from col 0
	li a2, 79 # to col 19
	call draw_horizontal_line
	
	# interrupt stuff
	li 	s0, 0			# interrupt counter
	la	t0, ISR
	csrrw	t1, mtvec, t0 		#setup ISR address
	li	t0, 1
	csrrw	x0, mie, t0		#enable interrupts

loop:	
PAUSE:	andi	t0, s0, 1
	bnez	t0, PAUSE	# pauses the game untill interrupt triggered again
	call	fill_piano_keys_arr	# fills piano keys arr with upcoming note
	call	shift_down	# moves everything down
	call	validate	# validate if all piano keys below certain level are already pressed
	bnez	a4, LOSS
	call	eval_switches	# evalutate switch input and decide if loss or no
	bnez	a4, LOSS
	
	# if new note is pressed, shut up buzzer to prepare for next note
	beqz	a5, DEL_ST	# if no new piano press, don't change currently playing
	sb	x0, 0x180(s5)	# stop playing any notes
	
# delay between notes
DEL_ST:
 	li 	t0, -1
 	li 	t1, 937500	# 0.075 sec delay
DELAYa: addi	t0, t0, 1
	bne 	t0, t1, DELAYa # if t0 == t1 DELAYtarget
	
	beqz	a5, loop	# if no new piano press, don't change currently playing
	# after delay play next note if new note available
	add	t0,  s6, s9	# get addr of note to play
	lb	t0, 0(t0)	# get note to play from the song note arr
	addi	s10, s10, 1	# increase the score
	sb	t0, 0x180(s5)

	# This block outputs the score
	# score is in s10, base 2
	# convert s10 to BCD to output to 7 seg
	addi	t5, s10, 0
	mv	t2, x0		# initialize output to 0
	mv	t3, x0		# counter set to 0
	li	t4, 20		# 20 used for comparision
BCD_NX:	mv	a0, t5		# pass input as dividend
	call	DIVIDE_BY_10	# call divide by 10 subroutine
	mv	t5, a1		# set quotient to input
	sll	a0, a0, t3	# shit remainder counter times
	add	t2, t2, a0	# add shifted remainder to output
	addi	t3, t3, 4	# increment counter
	bltu	t3, t4, BCD_NX	# counter < 20 => BCD of Next digit
	sw	t2, 0x40(s5)	# output BCD to display
	
	# check if song end is reached
	addi	s9, s9, 1	# increment index in arr
	add	t0,  s6, s9	# get addr of upcoming note
	lb	t0, 0(t0)	# get upcoming note to play from the song note arr
	bltz	t0, WIN		# end of song 
	
	j loop

LOSS:	# display score for a little bit then reset game
	sb	x0, 0x180(s5)	# shut up the speaker
	li	a3, RED_COLOR	# draw red in display
	call 	draw_background  # must not modify s2, s3
	li 	t0, -1
 	li 	t1, 25000000	# 2 second delay
DELAYb: addi	t0, t0, 1
	bne 	t0, t1, DELAYb	# if t0 == t1 DELAYtarget
	j	main		# restart the game
	


WIN:	# display score for a little bit then reset game
	sb	x0, 0x180(s5)	# shut up the speaker
	li	a3, GREEN_COLOR	# draw green on display
	call 	draw_background	# must not modify s2, s3
	li 	t0, -1
 	li 	t1, 25000000	# 2 second delay
DELAYc: addi	t0, t0, 1
	bne 	t0, t1, DELAYc	# if t0 == t1 DELAYtarget
	j	main		# restart the game
	

# draws a horizontal line from (a0,a1) to (a2,a1) using color in a3
# Modifies (directly or indirectly): t0, t1, a0, a2
draw_horizontal_line:
	addi sp,sp,-4
	sw ra, 0(sp)
	addi a2,a2,1	#go from a0 to a2 inclusive
draw_horiz1:
	call draw_dot  # must not modify: a0, a1, a2, a3
	addi a0,a0,1
	bne a0,a2, draw_horiz1
	lw ra, 0(sp)
	addi sp,sp,4
	ret

## This function is unsed ##
# draws a vertical line from (a0,a1) to (a0,a2) using color in a3
# Modifies (directly or indirectly): t0, t1, a1, a2
draw_vertical_line:
	addi sp,sp,-4
	sw ra, 0(sp)
	addi a2,a2,1
draw_vert1:
	call draw_dot  # must not modify: a0, a1, a2, a3
	addi a1,a1,1
	bne a1,a2,draw_vert1
	lw ra, 0(sp)
	addi sp,sp,4
	ret

# Fills the 60x80 grid with one color using successive calls to draw_horizontal_line
# Modifies (directly or indirectly): t0, t1, t4, a0, a1, a2, a3
# takes in a3 as argument, background color
draw_background:
	addi sp,sp,-4
	sw ra, 0(sp)
	li a1, 0	#a1= row_counter
	li t4, 60 	#max rows
start:	li a0, 0
	li a2, 79 	#total number of columns
	call draw_horizontal_line  # must not modify: t4, a1, a3
	addi a1,a1, 1
	bne t4,a1, start	#branch to draw more rows
	lw ra, 0(sp)
	addi sp,sp,4
	ret

# draws a dot on the display at the given coordinates:
# 	(X,Y) = (a0,a1) with a color stored in a3
# 	(col, row) = (a0,a1)
# Modifies (directly or indirectly): t0, t1
draw_dot:
	andi t0,a0,0x7F	# select bottom 7 bits (col)
	andi t1,a1,0x3F	# select bottom 6 bits  (row)
	slli t1,t1,7	#  {a1[5:0],a0[6:0]} 
	or t0,t1,t0	# 13-bit address
	sw t0, 0(s2)	# write 13 address bits to register
	sw a3, 0(s3)	# write color data to frame buffer
	ret

# reads a dot on the display at the given coordinates:
# 	(X,Y) = (a0,a1) 
#   returns color to a3
# 	(col, row) = (a0,a1)
# Modifies (directly or indirectly): t0, t1
read_dot:
	andi t0,a0,0x7F	# select bottom 7 bits (col)
	andi t1,a1,0x3F	# select bottom 6 bits  (row)
	slli t1,t1,7	#  {a1[5:0],a0[6:0]} 
	or t0,t1,t0	# 13-bit address
	sw t0, 0(s2)	# write 13 address bits to register
	lw a3, 0x40(s2)	# read color from fram buffer
	ret

# shifts everything on the display one row down:
# top row filled with background color
# no inputs
# Modifies (directly or indirectly): t0, t1, a0, a1, a2, a3, t2, t3, t4
shift_down:
	li	t2, 60		# store num of cols in t2
	li	a0, 20		# set a0 (col arg) to 0
	li	a1, 58		# set a1 (row arg) to 58
ROWS:	blt	a1, x0, ROW_0	# row arg < 0 -> fill top row
COLS:	bge	a0, t2, NX_COL	# col arg >= 80 -> go to next col
	addi	sp, sp, -4
	sw	ra, 0(sp)	# save ra before func call
	call	read_dot	# read_dot func, ret color to a3
	lw	ra, 0(sp)
	addi	sp, sp, 4	# reset ra and sp	
	addi	a1, a1, 1	# increment row arg (to row below)
	addi	sp, sp, -4
	sw	ra, 0(sp)	# save ra before func call
	call	draw_dot	# draws dot on row a1
	lw	ra, 0(sp)
	addi	sp, sp, 4	# reset ra and sp
	addi	a1, a1, -1	# reset a1 to correct row
	addi	a0, a0, 1	# go to next col
	j	COLS
NX_COL:	li	a0, 20		# reset to col 0
	addi	a1, a1, -1	# go one row above
	j	ROWS		# check rows cond after changing a1
ROW_0:	li	a0, 20		# col arg from = 20
	li	a2, 29		# col arg to = 29
	li	a1, 0		# row 0
	addi	t2, s4, 4	# memory access limit for PIANO_KEYS_QUEUE_ARRAY
	addi	t3, s4, 0
NX_KEY:	bge	t3, t2, SD_END	# if t3 reaches memory limit -> sd_end
	lbu	t4, 0(t3)	# read PIANO_KEYS_QUEUE_ARRAY addr t3
	beq	t4, x0, A3_BG	# if queue is 0 set A3 to background color
	li	a3, 0		# otherwise set a3 to black
	addi	t4, t4, -1	# decrement val read from array by 1
	sb	t4, 0(t3)
	j	DRW_HR		# draw horizental with color a3 from a0 to a2 at row 0
A3_BG:	li	a3, BG_COLOR	# set a3 to background color
DRW_HR:	addi	sp, sp, -8	# push a0 and a2 to stack before func call
	sw	a0, 4(sp)
	sw	a2, 0(sp)
	addi	sp, sp, -4
	sw	ra, 0(sp)	# save ra before func call
	call	draw_horizontal_line
	lw	ra, 0(sp)
	addi	sp, sp, 4	# reset ra and sp
	addi	t3, t3, 1	# increment to next key in piano keys array
	lw	a2, 0(sp)
	lw	a0, 4(sp)	# pop a0 and a2 from stack
	addi	sp, sp, 8
	addi	a0, a0, 10	# increment col from by 10 (key width is 10)
	addi	a2, a2, 10	# increment col to by 10
	j	NX_KEY
SD_END:	ret

# validates that no piano keys were not pressed:
# Modifies (directly or indirectly): t0, t1, a0, a1, a3, t2
# returns: a4, (flag, if the player lost (didn't press piano key, a4 = 1 else 0)
validate:
	li	a1, 40		# set a1 to detection row: for now it is 40
	li	a0, 20		# column to start checking from
	li	a4, 0		# initialize return vlue to 0
	li	t2, 60		# colomn checking limit
COL_LM: bge	a0, t2, VA_RET	# if checked all columns go to return
	addi	sp, sp, -4
	sw	ra, 0(sp)	# save ra before func call
	call	read_dot
	lw	ra, 0(sp)
	addi	sp, sp, 4	# reset ra and sp
	beq	a3, x0, ROW_1	# check the row before the current row if cur row is black
KEY_NX:	addi	a0, a0, 10	# go to next key
	j	COL_LM		# check if column limit reached
ROW_1:	addi	a1, a1, -1	# move row arg to one row above
	addi	sp, sp, -4
	sw	ra, 0(sp)	# save ra before func call
	call 	read_dot	# read color of row above
	lw	ra, 0(sp)
	addi	sp, sp, 4	# reset ra and sp
	addi	a1, a1, 1	# reset a1 to original row
	bne	a3, x0, LOST	# if black detected not twice in a row, go to LOSt
	j	KEY_NX		# check next key
LOST:	addi	a4, a4, 1	# set a4 to 1
VA_RET:	ret


# fills piano key arr to add key to queue
# Modifies (directly or indirectly): t0, t2, t3, t4, t5, (s8: not temporarily)
fill_piano_keys_arr:
	addi	t2, s4, 4	# set t2 to piani keys arr memory limit
	addi	t3, s4, 0	# set t3 to value of s4 (adr of piano keys arr)
FP_NX:	bge	t3, t2, FILL	# loop through piano keys arr
	lb	t4, 0(t3)	# read addr t3 and store in t4
	bnez	t4, FP_RET	# if piano keys arr has some val != 0 ret
	addi	t3, t3, 1	# check next element in piano keys arr
	j	FP_NX		# go to cond
FILL:	lw	t2, 4(s4)	# load previous random number from memory
	lw	t5, 0xC0(s3)	# read from random generator 0x11000200
	srli	t5, t5, 30	# get 2 MSB bits
	beq	t5, t2, FILL	# if random number is repeated, get new one
	add	t3, s4, t5	# t3 address fo piano keys arr which we will change
	sw	t5, 4(s4)	# set random num to current t5
	add	t0, s7, s8	# get index of current addr of time in note times arr
	lb	t0, 0(t0)	# read current note time
	bltz	t0, FP_RET	# if end of song, return
	addi	s8, s8, 1	# ADD TO FLOWCHART, increase index in times array
	sb	t0, 0(t3)	# write the time to the random index of piano keys arr
FP_RET:	ret

#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!! a1 was changed from 40 to 39
# takes in the switches as input, and gives output depending on button pressed
# Modifies (directly or indirectly): t6, t5, a0, a1, a2, a3, a4
# returns: a4, (flag, if the player lost (didn't press piano key, a4 = 1 else 0)
#	   a5 (flag to play a new key)
eval_switches:
	li	a4, 0		# intitializes lostFlag to 0
	li	a5, 0		# initializes newKey played to 0
	li	a1, 39		# set the row arg to 39 for later
	lhu	t6, 0(s5)	# read from switches
	srli	t5, t6, 14	# get 2 MSB switches
	slli	t5, t5, 2	# shift to left twice
	andi	t6, t6, 3	# get 2 LSB
	add	t6, t5, t6	# t6 = {2MSB of switches, 2LSB of switches}
	beqz	t6, ES_REW	# if input is 0 return
	li	t5, 16		# set reg t5 to 16 to compare with switches
	li	a0, 10		# set a0, col arg to 60
ES_NX:	srli	t5, t5, 1	# check next switch
	beqz	t5, ES_REL	# if more than one switch is on return loss
	addi	a0, a0, 10	# go to 10 columns to left, next key
	bne	t6, t5, ES_NX	# does switch raised match with t5
	addi	sp, sp, -4
	sw	ra, 0(sp)	# store ra before function call
	call	read_dot	# read dot function call
	lw	ra, 0(sp)	
	addi	sp, sp, 4	# reset ra
	bnez	a3, ES_GRY	# if black is not detected, check grey
	addi	a5, a5, 1	# black detected
	addi	a2, a0, 9	# to column for draw horiz line
ES_ROW:	addi	a1, a1, -1	# find where the black ends
	addi	sp, sp, -4
	sw	ra, 0(sp)	# store ra before function call
	call	read_dot	# read dot function call
	lw	ra, 0(sp)	
	addi	sp, sp, 4	# reset ra
	beqz	a3, ES_ROW	# if cur row is black check one before
ES_HOR:	addi	a1, a1, 1	# move a1 to first black row/next row
	addi	sp, sp, -4
	sw	ra, 0(sp)	# store ra before function call
	call	read_dot	# read dot function call to make sure not to draw on non black
	lw	ra, 0(sp)	
	addi	sp, sp, 4	# reset ra
	bnez	a3, ES_REW	# is conversion done
	li	a3, 0x92	# store grey in a3
	addi	sp, sp, -8
	sw	a0, 4(sp)	# store a0 and a2 before modification in function
	sw	a2, 0(sp)
	addi	sp, sp, -4
	sw	ra, 0(sp)	# save ra before func call
	call	draw_horizontal_line
	lw	ra, 0(sp)
	addi	sp, sp, 4	# reset ra and sp
	lw	a2, 0(sp)
	lw	a0, 4(sp)	# pop a0 and a2 from stack
	addi	sp, sp, 8
	j	ES_HOR		# convert next hor line to grey
ES_GRY:	li	t5, 0x92	# store grey in t5
	beq	a3, t5, ES_REW	# if color read is grey return without loss
ES_REL:	addi	a4, a4, 1	# return a loss
ES_REW:	ret

ISR:	nop			# added to solve unidentified problem (probably hardware problem
        addi	s0, s0, 1	#increment interrupt count
	sb	x0, 0x180(s5)	# shut up the speaker
	csrrw	x0, mie, s11 	#enable interrupts
	mret

# function divides a0 by 10, 
# Modifies t0 and a1 and a0
# input argument: a0: dividend
# return: a1: quotient, a0: remainder
DIVIDE_BY_10: 	li	t1, 10			# set 10 as divisor
		li	a1, 0			# loop counter: quotient
DIVISION_COND:	blt	a0, t1, DIVISION_DONE	# continue subtraction till a0 < t1
		sub	a0, a0, t1		# dividend = dividend - divisor
		addi	a1, a1, 1		# increment counter/quotient by 1
		j	DIVISION_COND
DIVISION_DONE:	ret				# returns a1: quotient, a0: remainder
