@17
D=A
@SP
A=M
M=D
@SP
M=M+1
@17
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
D=M-D
@10a
D;JEQ
D=0
@10done
0;JMP
(10a)
D=-1
(10done)
@SP
M=M-1
A=M-1
M=D
@17
D=A
@SP
A=M
M=D
@SP
M=M+1
@16
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
D=M-D
@13a
D;JEQ
D=0
@13done
0;JMP
(13a)
D=-1
(13done)
@SP
M=M-1
A=M-1
M=D
@16
D=A
@SP
A=M
M=D
@SP
M=M+1
@17
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
D=M-D
@16a
D;JEQ
D=0
@16done
0;JMP
(16a)
D=-1
(16done)
@SP
M=M-1
A=M-1
M=D
@892
D=A
@SP
A=M
M=D
@SP
M=M+1
@891
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
D=M-D
@19a
D;JLT
D=0
@19done
0;JMP
(19a)
D=-1
(19done)
@SP
M=M-1
A=M-1
M=D
@891
D=A
@SP
A=M
M=D
@SP
M=M+1
@892
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
D=M-D
@22a
D;JLT
D=0
@22done
0;JMP
(22a)
D=-1
(22done)
@SP
M=M-1
A=M-1
M=D
@891
D=A
@SP
A=M
M=D
@SP
M=M+1
@891
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
D=M-D
@25a
D;JLT
D=0
@25done
0;JMP
(25a)
D=-1
(25done)
@SP
M=M-1
A=M-1
M=D
@32767
D=A
@SP
A=M
M=D
@SP
M=M+1
@32766
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
D=M-D
@28a
D;JGT
D=0
@28done
0;JMP
(28a)
D=-1
(28done)
@SP
M=M-1
A=M-1
M=D
@32766
D=A
@SP
A=M
M=D
@SP
M=M+1
@32767
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
D=M-D
@31a
D;JGT
D=0
@31done
0;JMP
(31a)
D=-1
(31done)
@SP
M=M-1
A=M-1
M=D
@32766
D=A
@SP
A=M
M=D
@SP
M=M+1
@32766
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
D=M-D
@34a
D;JGT
D=0
@34done
0;JMP
(34a)
D=-1
(34done)
@SP
M=M-1
A=M-1
M=D
@57
D=A
@SP
A=M
M=D
@SP
M=M+1
@31
D=A
@SP
A=M
M=D
@SP
M=M+1
@53
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
@112
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
@SP
A=M-1
M=-M
@SP
A=M-1
D=M
A=A-1
M=M&D
@SP
M=M-1
@82
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
M=M|D
@SP
M=M-1
@SP
A=M-1
M=!M
