// This file is part of www.nand2tetris.org
// and the book "The Elements of Computing Systems"
// by Nisan and Schocken, MIT Press.
// File name: projects/04/Fill.asm

// Runs an infinite loop that listens to the keyboard input.
// When a key is pressed (any key), the program blackens the screen,
// i.e. writes "black" in every pixel;
// the screen should remain fully black as long as the key is pressed. 
// When no key is pressed, the program clears the screen, i.e. writes
// "white" in every pixel;
// the screen should remain fully clear as long as no key is pressed.

// Put your code here.

// Each row has 32 words, and there are 256 rows
// First row starts at 16384
// Word after last row is 16384+(32*256) = 24576

(start)
  // *row = 16384
  @16384
  D=A
  @row
  M=D

(rowLoop)
  // if (ram[24576] & 0xFFFF) goto fillOn
  D=-1
  @24576
  D=D&M
  @fillOn
  D;JNE

  // else
  (fillOff)
    // rowPixels = 0
    @rowPixels
    M=0

    // goto fillRow
    @fillRow
    0;JMP

  (fillOn)
    // rowPixels = 0xFFFF
    @rowPixels
    M=-1

  (fillRow)
    // D = rowPixels
    @rowPixels
    D=M

    // *row = D
    @row
    A=M
    M=D

    // row = row + 1
    @row
    M=M+1

    // if (24576 - row) == 0 goto start
    D=M
    @24576
    D=A-D
    @start
    D;JEQ

    // continue row loop
    @rowLoop
    D;JMP
