package main

import (
	"bufio"
	"fmt"
	"log"
	"os"
	"strconv"
	"strings"
	"unicode"
)

var destTable, compTable, jumpTable map[string]string
var basicSymbols map[string]int

func init() {
	compTable = map[string]string{
		"0":   "0101010",
		"1":   "0111111",
		"-1":  "0111010",
		"D":   "0001100",
		"A":   "0110000",
		"M":   "1110000",
		"!D":  "0001101",
		"!A":  "0110001",
		"!M":  "1110001",
		"-D":  "0001111",
		"-A":  "0110011",
		"-M":  "1110011",
		"D+1": "0011111",
		"A+1": "0110111",
		"M+1": "1110111",
		"D-1": "0001110",
		"A-1": "0110010",
		"M-1": "1110010",
		"D+A": "0000010",
		"D+M": "1000010",
		"D-A": "0010011",
		"D-M": "1010011",
		"A-D": "0000111",
		"M-D": "1000111",
		"D&A": "0000000",
		"D&M": "1000000",
		"D|A": "0010101",
		"D|M": "1010101",
	}

	destTable = map[string]string{
		"":    "000",
		"M":   "001",
		"D":   "010",
		"MD":  "011",
		"A":   "100",
		"AM":  "101",
		"AD":  "110",
		"AMD": "111",
	}

	jumpTable = map[string]string{
		"":    "000",
		"JGT": "001",
		"JEQ": "010",
		"JGE": "011",
		"JLT": "100",
		"JNE": "101",
		"JLE": "110",
		"JMP": "111",
	}

	basicSymbols = map[string]int{
		"SP":     0,
		"LCL":    1,
		"ARG":    2,
		"THIS":   3,
		"THAT":   4,
		"R0":     0,
		"R1":     1,
		"R2":     2,
		"R3":     3,
		"R4":     4,
		"R5":     5,
		"R6":     6,
		"R7":     7,
		"R8":     8,
		"R9":     9,
		"R10":    10,
		"R11":    11,
		"R12":    12,
		"R13":    13,
		"R14":    14,
		"R15":    15,
		"SCREEN": 16384,
		"KBD":    24576,
	}
}

type instruction struct {
	s       string
	lineNum int
}

type symbolTable struct {
	addrs    map[string]int
	nextAddr int
}

func newSymbolTable() *symbolTable {
	addrs := map[string]int{}
	for k, v := range basicSymbols {
		addrs[k] = v
	}

	return &symbolTable{addrs: addrs, nextAddr: 16}
}

func main() {
	if len(os.Args) != 2 {
		log.Fatalf("usage: %s [inputfile]", os.Args[0])
	}

	path := os.Args[1]

	f, err := os.Open(path)
	if err != nil {
		log.Fatal(err)
	}
	defer f.Close()

	instructions, symbols, err := firstPass(bufio.NewScanner(f))
	if err != nil {
		log.Fatalf("error %s:%s", path, err)
	}

	for _, ins := range instructions {
		if ins.s[0] == '@' { // a-instruction
			s, err := translateAInstruction(ins.s, symbols)
			if err != nil {
				log.Fatalf("error %s:%d: %s", path, ins.lineNum, err)
			}

			fmt.Println(s)
		} else { // c-instruction
			s, err := translateCInstruction(ins.s)
			if err != nil {
				log.Fatalf("error %s:%d: %s", path, ins.lineNum, err)
			}

			fmt.Println(s)
		}
	}
}

func firstPass(s *bufio.Scanner) ([]instruction, *symbolTable, error) {
	instructions := []instruction{}
	symbols := newSymbolTable()
	lineNum := -1

	for s.Scan() {
		line := strings.TrimSpace(s.Text())
		lineNum++

		// Skip blank lines
		if len(line) == 0 {
			continue
		}

		// Skip comments
		if line[0] == '/' && line[1] == '/' {
			continue
		}

		// Strip line comments
		line = strings.Fields(line)[0]

		// Handle jump labels
		if line[0] == '(' {
			if len(line) < 3 || line[len(line)-1] != ')' {
				return nil, nil, fmt.Errorf("%d: invalid label specifier", lineNum)
			}

			label := line[1 : len(line)-1]

			if _, exists := symbols.addrs[label]; exists {
				return nil, nil, fmt.Errorf("%d: jump label \"%s\" previously declared", lineNum, label)
			}

			symbols.addrs[label] = len(instructions)
			continue
		}

		instructions = append(instructions, instruction{
			s:       line,
			lineNum: lineNum,
		})
	}

	return instructions, symbols, s.Err()
}

// modifies symbol table
func translateAInstruction(s string, symbols *symbolTable) (string, error) {
	var (
		identifier = s[1:] // strip '@' prefix
		res        string
		addr       int
	)

	if isInt(identifier) {
		addr64, err := strconv.ParseUint(identifier, 10, 15)
		if err != nil {
			return "", err
		}

		addr = int(addr64)
	} else if a, ok := symbols.addrs[identifier]; ok {
		addr = a
	} else {
		addr = symbols.nextAddr
		symbols.addrs[identifier] = addr
		symbols.nextAddr++
	}

	res = strconv.FormatInt(int64(addr), 2)
	for len(res) < 16 {
		res = "0" + res
	}

	return res, nil
}

func translateCInstruction(s string) (string, error) {
	toks := strings.Split(s, ";")
	destComp := toks[0]

	var jump string
	if len(toks) == 2 {
		jump = toks[1]
	}

	toks = strings.Split(destComp, "=")
	var dest, comp string
	if len(toks) == 2 {
		dest = toks[0]
		comp = toks[1]
	} else {
		comp = toks[0]
	}

	if _, ok := compTable[comp]; !ok {
		return "", fmt.Errorf("invalid comp value: %q", comp)
	}

	if _, ok := destTable[dest]; !ok {
		return "", fmt.Errorf("invalid dest value: %q", dest)
	}

	if _, ok := jumpTable[jump]; !ok {
		return "", fmt.Errorf("invalid jump value: %q", jump)
	}

	return "111" + compTable[comp] + destTable[dest] + jumpTable[jump], nil
}

func isInt(s string) bool {
	for _, c := range s {
		if !unicode.IsDigit(c) {
			return false
		}
	}
	return true
}
