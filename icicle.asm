;Simple animated icicle display usint ATTiny13
;Copyright(C) Rob Rescorla (rob@redaso.co.uk) January 2021

;This program is free software; you can redistribute it and/or
;modify it under the terms of the GNU General Public License
;as published by the Free Software Foundation; either version 2
;of the License, or (at your option) any later version.

;This program is distributed in the hope that it will be useful,
;but WITHOUT ANY WARRANTY; without even the implied warranty of
;MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;GNU General Public License for more details.

;You should have received a copy of the GNU General Public License
;along with this program; if not, write to the Free Software
;Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.


.include "/usr/share/avra/tn13def.inc"

;Theory of operation.
;twelve LEDs are attached in charliplexed configuration,
;A timer interrupt hander scans an image onto the LEDs, three at a time,
;PWM is accomplished by repeatedly outputing each group before moving on
;to the next.
;Once the entire output process has been accomplished a number of times,
;a non-interrupt process performs an update on the image.



;Notes
;1) This builds, works and delivers the desired effect: It gets checked in
;2) It's a mess.
;one datasheet indicated (typo?) that EOR had to have on operand in r0-r3.


;the number of scans that have been performed in this frame of the animation
.def scan_count=r1

;the number of scans per frame 
.def frame_time=r10  

.def lfsr_low=r0; one src of eor must be r0-r3, FFS! <-- PAINFULL LESSON
.def lfsr_high=r8
.def pause=r9
.def slope=r18
;scroll variables
.def real_work=r21 ;//brightness being moved 
.def read_bright=r6
.def new_bright=r17
.def read_slot=r19
.def write_base=r28
;scanner variables (interrupt mode)
.def width_reqd=r14
.def ddr_scratch=r20 ;bitfield of bits to set in DDR
.def turn_on=r16 ;one-hot count of which bit being considered
.def lighting = r24 ; one-hot count of which output will be driven high
.def lit_time = r25
.def read_base=r26

;Reset
rjmp start
;ext_int0
nop
;pcint0
nop
;tim0_ovr
nop
;ee_rdy
nop
;ana_comp
nop
;tim0_compa
rjmp scanner

start:
ldi r16, low(RAMEND)
out SPL,r16

ldi r16,8
mov frame_time,r16  ;set initial frame length
clr lighting  ;zilch lighting bit
ldi lit_time,1; irritating, resetting lit_time
ldi write_base,0x60;Y now points to base of RAM
;get the LFSR seed form eeprom
ldi read_slot,0x10
rcall eeprom_read

ldi real_work,8
mov lfsr_low,read_slot
more_lfsr_low:
clr r16
lsr read_slot
brcc serno_dim1
ldi r16,8
serno_dim1:
st Y+,r16
dec real_work
brne more_lfsr_low

ldi read_slot,0x11
rcall eeprom_read
ldi real_work,4
mov lfsr_high,read_slot
more_lfsr_high:
clr r16
lsr read_slot
brcc serno_dim2
ldi r16,8
serno_dim2:
st Y+,r16
dec real_work
brne more_lfsr_high
sbiw write_base,12

ldi r16,10
out OCR0A,r16 ;limit timer 0 to a count of 10

ldi r16,0x2
out TCCR0A,r16 ;timer does not flip IO bits, just resets on timeout
ldi r16,0x3
out TCCR0B,r16 ;prescale of 256
ldi r16,3
mov pause,r16 ;set initial pause before rendering 
ldi r16,4

out TIMSK0,r16 ;enable interrupt


clr turn_on
bset 6 
;about to switch interrupts on, stop using r16!
clr scan_count
sei
new_ice:
;generate a new icicle image by injecting diminishing brighnesses in to the
;top of the slide
;Did want to try changing the brightness and length between images, but
;ran out of time.
ldi new_bright,32;The seed brightness.
ldi slope,8  ;The pixel reduction
wait:
sleep  ;Not sure that the sleep mode is set correctly.
;not sure how much current the core draws, must check.
cp scan_count,frame_time
brne wait  ;if the image hasn't been on display for a whole frame yet... 
clr scan_count  ;reset the count
brts do_shift  ;icicle in play, so just do it.
dec pause    ;pause is the time (in frames) between drips,
brne wait 
mov real_work,lfsr_low 
andi real_work,0x7   ;begining of a new icicle, update frame time from LFSR.
mov frame_time,real_work
ldi real_work,0x4  
add frame_time,real_work
do_shift:
;reset the frame count, reset the live flag, point to starting slot of eeprom
bclr 6 ;clear the T bit

;Now we have the loop that shifts and generates  pixels.
;Because the display is wired as convenient, rather than logically, there
;is a map in eeprom of how values get moved in RAM in order to move to 
;adjacent pixles on the display.
;entry fifteen is a start location.
ldi read_slot,0xf

;First LED is calculated, rather than moved to.
mov real_work,new_bright
;We got through a lot of adams here lsr r5,r17  
lsr real_work
lsr real_work

scroll_loop:
  rcall eeprom_read

  cpi read_slot,0xf
  breq tail_end

  add write_base,read_slot ;add offset to index

  ld read_bright,Y  ;first cycle we have the begining of the chase, later it's next
  st Y,real_work
  cpi real_work,0
  breq nope 
  bset 6 
nope:
  sub write_base,read_slot ;restore the index
  mov real_work,read_bright    
  rjmp scroll_loop

tail_end: ;have finished the shift
  ;calculate the brighness of the first pixel of next shift
  sub new_bright,slope  
  brge no_under
    clr new_bright
  no_under:
  brts wait ;icicle in play, so wait for current frame time 
  ;otherwise display is dark, and will be re-lit next time
  ;consider saving updated seed to eeprom... this is a little bit cheeky.
  ;I don't want to save to eeprom on every drip because it would wear out.
  ;At the moment the average drip time is about three seconds, so saving once
  ;every 2^12 would be about once every three and a half hours...
  ;limiting the seed/serial number to twelve bits would mean that it fits on
  ;the display.  If we save the LFSR state when the last 12 bits match the seed
  ;then we save it in one of sixteen states.
  ;That's good enough to prevent it starting in the same position each time it's
  ;turned on.
  ;Note that the seed injects extra entropy at start time as it's keeping the
  ;display busy.
  ldi read_slot,0x10
  rcall eeprom_read
  cpse read_slot,lfsr_low
  rjmp no_save
  ldi read_slot,0x11
  rcall eeprom_read
  eor read_slot,lfsr_high
  andi read_slot,0x0f
  brne no_save
  in real_work,SREG
  cli
  save_wait:
  sbic EECR,EEPE
  rjmp save_wait
  clr read_slot
  out EECR,read_slot
  ldi read_slot,0x11
  out EEARL,read_slot
  out EEDR,lfsr_high
  sbi EECR,EEMPE
  sbi EECR,EEPE
  sei
  out SREG,real_work
;tempting to neglect the SREG preservation, but may as well.
no_save:
  ;update pause from LFSR
  mov real_work,lfsr_low
  andi real_work,0xf
  mov pause,real_work   ;real work not used at the moment since
		;no icicle in play
  inc pause


  rjmp new_ice


eeprom_read:
  sbic EECR,EEPE 
  rjmp eeprom_read
;lookup next slot from indication in r19
  out EEARL,read_slot
  sbi EECR,EERE
  in read_slot,EEDR  ;find the next slot of interest
  ret



;Scanner, details
; The device has this pinout
; PB5/RST 1 V 8 VCC
;     PB3 2   7 PB2/SCLK
;     PB4 3   6 PB1/MISO
;     GND 4   5 PB0/MOSI 

;arbitrarily pin PB 1-4 were selected as outputs.
;The LEDs can be numbered thus
;Cathode    PB1 PB2 PB3 PB4
;Anode PB1  ***  0   1   2
;      PB2   3  ***  4   5
;      PB3   6   7  ***  8 
;      PB4   9   10  11 ***
;
;a complete scan sees each pin driven high one at a time, in the time that it
;is high it selects the "Anode" row of the above table, the remaining pins
;are set to *low impedence* low output for a time indicated by the brightness.
;The brightness is found by looking the LED number up in an array stored at 0x60
;the timer0 interrupt causes a scan process, 
;register names
;lighting: one-hot indication of which pin is driven high
;turn_on: one-hot indication of which pin is being considered for low drive
;ddr_scratch: bitfield of bits to be set to output/low impedence state
;read_base: Indirect register X, used to read brightness from RAM.
;lit_time:  time (in timer0 periods) that LEDS on this row have been lit during
;	     this scan, used for PWM.
;scan_count: number of complete scans performed to render this frame.
;width_reqd: the width of relighting required for this LED.
scanner:
andi lighting,0x1e
brne no_int_set ;if all bits have been considered of that scan 
  ldi read_base,0x60;reset pointer
  ldi lighting,2 ;reset lighting bit
  inc scan_count ;increment frame count
no_int_set:
;loop through all the bits, determining if 
ldi turn_on,2   
clr ddr_scratch    
next_bit:
  cp turn_on,lighting ;This way we skip that bit but don't bodge the index! 
  breq set_out;always set anode selection to output
    LD width_reqd,X+   ;otherwise we read the next byte of RAM
    cp width_reqd,lit_time 
    brlt no_light  ;if LED has been lit long enough, skip DDR setting
  set_out: 
    or ddr_scratch,turn_on  ;update ddr map
  no_light:
    lsl turn_on
    andi turn_on,0x1e 
  brne next_bit ;condsider if next bit should be output.

out ddrb,ddr_scratch
out portb,lighting
inc lit_time ;these LEDS have been lit a while longer...
cpi lit_time,8
brne finished_int
  ldi lit_time,1;
  lsl lighting,lighting ;consider next anode row
  adiw read_base,3 ;we don't need to repeat this row!
  ;now update the LFSR
  ;Listing (off the top of my head) four playoffs in PRNG design.
  ;1) Memory space, for example slot shuffling generators
  ;     We've plenty of memory, but the code size is quite large
  ;2) Code complexity
  ;     This is in assembler, and I'm on a time budget
  ;3) Runtime efficiency
  ;   I've got loads of spare cycles
  ;4) correlation
  ;   Humans are surprisingly good at spotting patterns.
  ; Ordinarily an LFSR would be bad, however, I can afford to
  ; recompute it many times between samples.
  ;  by doing it in interrupt there's some scrambelling on how
  ;  often it gets sampled...
  ;TODO, look at doing ADC on an undriven pin, and see
  ;how many bits seem uncorrelated with the output.
  ;PRNGs typically play off in three ways 
  ;reusing ddr_scratch...
  lsl lfsr_low
  rol lfsr_high
  brcc finished_int
  ldi ddr_scratch,0x25
  eor ddr_scratch,lfsr_low
  mov lfsr_low,ddr_scratch
  
finished_int:
subi read_base,3;reset to the begining of this row in memory
reti

;for (in)convenience, the LEDs on my icicles were wired as follows.
;LED  :2  9  5 10  8 11  3  0  7  4  6  1
;-----------------------------------------
;Bit 1:A  K              K  A        K  A
;Bit 2:      A  K        A  K  K  A
;Bit 3:            A  K        A  K  A  K
;Bit 4:K  A  K  A  K  A

.eseg
.db 7
.db 0xf
.db 9
.db 0
.db 6
.db 10
.db 1
.db 4
.db 11
.db 5
.db 8
.db 3
.db 0 
.db 0 
.db 0 
;starting position
.db 2
;lfsr seed/serial number
.db 20
.db 0



;C.E.T. Oakwood and Rocket

