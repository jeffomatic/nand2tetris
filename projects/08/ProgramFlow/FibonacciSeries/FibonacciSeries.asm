@ARG
A=M+1
D=M
@SP
A=M
M=D
@SP
M=M+1
@4
D=A
@SP
M=M-1
@SP
A=M
D=D-M
A=D+M
D=A-D
M=D
@0
D=A
@SP
A=M
M=D
@SP
M=M+1
@THAT
A=M
D=A
@SP
M=M-1
@SP
A=M
D=D-M
A=D+M
D=A-D
M=D
@1
D=A
@SP
A=M
M=D
@SP
M=M+1
@THAT
A=M+1
D=A
@SP
M=M-1
@SP
A=M
D=D-M
A=D+M
D=A-D
M=D
@ARG
A=M
D=M
@SP
A=M
M=D
@SP
M=M+1
@2
D=A
@SP
A=M
M=D
@SP
M=M+1
@SP
A=M-1
D=M
A=A-1
M=M-D
@SP
M=M-1
@ARG
A=M
D=A
@SP
M=M-1
@SP
A=M
D=D-M
A=D+M
D=A-D
M=D
(__label__MAIN_LOOP_START)
@ARG
A=M
D=M
@SP
A=M
M=D
@SP
M=M+1
@SP
M=M-1
@SP
A=M
D=M
@__label__COMPUTE_ELEMENT
D;JNE
@__label__END_PROGRAM
0;JMP
(__label__COMPUTE_ELEMENT)
@THAT
A=M
D=M
@SP
A=M
M=D
@SP
M=M+1
@THAT
A=M+1
D=M
@SP
A=M
M=D
@SP
M=M+1
@SP
A=M-1
D=M
A=A-1
M=M+D
@SP
M=M-1
@THAT
A=M+1
A=A+1
D=A
@SP
M=M-1
@SP
A=M
D=D-M
A=D+M
D=A-D
M=D
@4
D=M
@SP
A=M
M=D
@SP
M=M+1
@1
D=A
@SP
A=M
M=D
@SP
M=M+1
@SP
A=M-1
D=M
A=A-1
M=M+D
@SP
M=M-1
@4
D=A
@SP
M=M-1
@SP
A=M
D=D-M
A=D+M
D=A-D
M=D
@ARG
A=M
D=M
@SP
A=M
M=D
@SP
M=M+1
@1
D=A
@SP
A=M
M=D
@SP
M=M+1
@SP
A=M-1
D=M
A=A-1
M=M-D
@SP
M=M-1
@ARG
A=M
D=A
@SP
M=M-1
@SP
A=M
D=D-M
A=D+M
D=A-D
M=D
@__label__MAIN_LOOP_START
0;JMP
(__label__END_PROGRAM)
