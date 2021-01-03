# Hello!

Hello, this project is intended to be a collection of open source festive 
decoration. As of January 2021, the only one here is a dripping icicle.

(The same code could probably used for lots of other blinkenlights effects.)

# Icicle effect
Our local shops had sold out of dripping icicle decorations, so I decided
to develop my own, in assembler, because I'm an idiot.

I chose the ATTiny13 as it was the cheapest 8pin DIP micro-controller that
my favourite supplier could provide.

When I examined commerical units they all had an 8 pin SOT device, and 
twelve LEDs, so obviously charlieplexed. At first glance some of them
seemed to grade the intensity of the light along the length of the drip,
but this turned out to be a trick of the moulding.

Something that irritated me about the commercial offerings was that they
tended to stay in synchronisation. (The dirt-cheap on chip RC oscilators
somehow being accurate to parts per ten, or maybe hundred, thousand.)  
I avoided this by putting a simple PRNG in the code, and seeding each
unit seperately.

I needed to make some characteristics of the drip animation variable,
obvious candidates were
* speed of the drip
* length of the drip
* brightness of the drip
* interval between drips.
Although I started implementing varying length and brightness, I dropped 
that because I wanted to be certain that each unit would attract the 
"right" amount of attention, being dim one moment and blinding the next 
would be distracting for some people.
I made speed variable by altering the time between frames of animation
and made the interval variable by altering the number of frames between
each drip.

An advantage of having an interval between drips is that it isn't, at a glance,
obvious how many units are on display, particularly if it's a dark night, and 
they aren't laid out in a regular pattern.
It takes me roughly an hour to wire-wrap each of these, so making them seem
a little more numerous is appealing!

Unlike the commerical units that I saw, my code does vary the brightness of
pixels along the length of a drip.

I've now added functionality to save the LFSR state from time to time, 
this won't actually offer many variations, but will prevent a unit from 
starting in the same position each time. 

## Construction

Each unit was constructed by wire-wrapping and soldering LEDs to four bus 
wires attached to the micro controller, I didn't bother with current 
limitting resistors, at the time of writing my icicles have survived a week.

The outer shell was composed of transparent PVC tubing with an internal 
diameter of (IIRC) 12mm.  This was badly curled when it came from the 
supplier, but hanging it next to some hot water pipes over night sorted that.

The top of the tube was sealed with hot melt glue, capturing the supply and
support cables.


## Parts List (Per unit)
* Flexible wire circa 22 AWG, several colours
* Strip board (four or five strips, by nine-ish holes)
* ATTiny13 (DIP version)
* LEDs, I used the blue, white and purple 5mm's from a bulk pack I bought.
* Decoupling capacitors from the junk box.
* cable to power and support the decoration. I used waterproof telecoms cable because we had half a mile of it in the shed: This might have been a mistake.

Also, you'll need a power supply, I used a wall-wart from a well known 
vendor of educational SBCs, and chopped the micro USB plug off the end.



# Motivation
This project is part of my new year's resolution to write thirty lines a day 
intended for other people to read.  (Not necessarily to be published that 
same day.)


