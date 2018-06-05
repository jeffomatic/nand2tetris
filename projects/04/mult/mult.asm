// This file is part of www.nand2tetris.org
// and the book "The Elements of Computing Systems"
// by Nisan and Schocken, MIT Press.
// File name: projects/04/Mult.asm

// Multiplies R0 and R1 and stores the result in R2.
// (R0, R1, R2 refer to RAM[0], RAM[1], and RAM[2], respectively.)

// Put your code here.
// r2 = 0;
// while (r0 > 0) {
//   r2 = r2 + r1
//   r0--;
// }

(START)
@R2
M=0

@R0 // Optimization: this is the last line of the loop too
(LOOP)
// if R0 == 0 goto END
D=M
@END
D;JEQ

// R2 += R1
@R1
D=M
@R2
M=D+M

// R0 -= 1
@R0
M=M-1

// Continue
@LOOP
0;JMP

(END)
