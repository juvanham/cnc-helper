# cnc-helper
ruby gem to create gcode for a cnc router/milling machine

Since I don't have much background in CNC milling, but know my way around in programming, I decided to create building blocks 
for electrical parts that I found on ebay, to create control panels.

My approach is not yet the most optimal for speed, but at this moment it just works and by create SVG files as output I can see
how the final result fits together, to avoid putting parts over each other.

The popular 3040 milling machine is sold as an engraver, this means that one has to deal with imperfections. As a solution to this,
I start for each component from a fixed position to drill holes around the outline. E.g. a circle, before milling away a cylinder for
a switch. By starting for each of these holes from the same position, I hope to reduce the inaccuraties from a bending tool or 
uncontrolled motion that the steppers cannot supress.
