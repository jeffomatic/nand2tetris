raise "No filename provided" unless ARGV.size > 0

path = ARGV[0]
basename = File.basename(path, File.extname(path))

commands = File.read_lines(path).map_with_index { |command, line|
  # remove initial whitespace
  {command.strip, line + 1}
}.select { |command, line|
  # filter out full-line comments
  command[0..1] != "//" && command.size > 0
}.map { |command, line|
  # remove partial-line comments, additional trailing whitespace, then tokenize
  {command[0...(command.index("//") || command.size)].strip.split, line}
}

commands.each do |c, line|
  command = c[0]
  args = c[1..-1]

  case command
  when "push"           then push_command(args, line, basename)
  when "pop"            then pop_command(args, line)
  when "add"            then binary_operator_command("add", "+", args, line)
  when "sub"            then binary_operator_command("add", "-", args, line)
  when "neg"            then unary_operator_command("neg", "-", args, line)
  when "eq", "gt", "lt" then comparison_command(command, args, line)
  when "and"            then binary_operator_command("add", "&", args, line)
  when "or"             then binary_operator_command("add", "|", args, line)
  when "not"            then unary_operator_command("not", "!", args, line)
  else                       raise "Invalid command #{c.join}"
  end
end

def push_command(args : Array(String), line : Int, basename : String)
  check_arg_count(args, 2, "push", line)
  segment = args[0]
  offset = cast_numeric_literal(args[1], line, min: 0, max: 32767)

  case segment
  when "argument"
    load_segment_offset("ARG", offset)
    puts "D=M" # deref address and cache value
  when "local"
    load_segment_offset("LCL", offset)
    puts "D=M" # deref address and cache value
  when "static"
    puts "@#{basename}.#{offset}"
    puts "D=M" # deref address and cache value
  when "constant"
    puts "@#{offset}"
    puts "D=A" # cache value
  when "this"
    load_segment_offset("THIS", offset)
    puts "D=M" # deref address and cache value
  when "that"
    load_segment_offset("THAT", offset)
    puts "D=M" # deref address and cache value
  when "pointer"
    case offset
    when 0 then puts "@3"
    when 1 then puts "@4"
    else        raise "line #{line}: push command: invalid offset for pointer segment"
    end

    puts "D=A"
  when "temp"
    offset += 5 # temp segment starts at RAM[5]
    raise "line #{line}: push command: invalid offset for temp segment" if offset < 5 || 12 < offset
    puts "@#{offset}"
  else
    raise "line #{line}: push command: invalid memory segment #{segment}"
  end

  load_segment_offset("SP", 0)
  puts "M=D"   # write to stack top
  puts "@SP"   # load stack pointer
  puts "M=M+1" # increment stack pointer
end

def pop_command(args : Array(String), line : Int)
  check_arg_count(args, 2, "pop", line)
  segment = args[0]
  offset = cast_numeric_literal(args[1], line, min: 0, max: 32767)
end

def binary_operator_command(command : String, operator : String, args : Array(String), line : Int)
  check_arg_count(args, 0, command, line)

  load_segment_offset("SP", -1)
  puts "D=M"             # load second operand
  puts "A=A-1"           # move backward in stack
  puts "D=M#{operator}D" # apply operator to first and second operand
  puts "M=D"             # overwrite first operand with sum
  puts "@SP"             # load stack pointer
  puts "M=M-1"           # overwrite stack pointer value
end

def unary_operator_command(command : String, operator : String, args : Array(String), line : Int)
  check_arg_count(args, 0, command, line)

  load_segment_offset("SP", -1)
  puts "M=#{operator}M" # overwite top of the stack with negation
end

def comparison_command(command : String, args : Array(String), line : Int)
  check_arg_count(args, 0, command, line)

  load_segment_offset("SP", -1)
  puts "D=M"                  # load second operand
  puts "A=A-1"                # move backward in stack
  puts "D=M-D"                # subtract second operand from first
  puts "@#{line}a"            # load jump label address
  puts "D;J#{command.upcase}" # jump on comparison
  puts "D=0"                  # not equal
  puts "@#{line}done"         # load done
  puts "0;JMP"                # goto done
  puts "(#{line}a)"           # equal label label
  puts "D=-1"                 # equal
  puts "(#{line}done)"        # done label
  puts "@SP"                  # load stack pointer address
  puts "M=M-1"                # decrement stack pointer (now points to second operand)
  puts "A=M-1"                # move backward (address of first operand)
  puts "M=D"                  # overwrite first operand with equality value
end

def check_arg_count(args : Array(String), want : Int, command : String, line : Int)
  got = args.size
  raise "line #{line}: #{command} command: got #{got} args, want #{want}" if got != want
end

def cast_numeric_literal(literal : String, line : Int, *, min : Int? = nil, max : Int? = nil) : Int
  begin
    n = literal.to_i

    if !min.nil? && n < min
      raise "line #{line}: numeric literal #{literal} is less than minimum #{min}"
    end

    if !max.nil? && n > max
      raise "line #{line}: numeric literal #{literal} is greater than max #{max}"
    end

    n
  rescue ArgumentError
    raise "line #{line}: invalid numeric literal #{literal}"
  end
end

# Puts memory address into A.
# Clobbers D if A > 2.
def load_segment_offset(base : String, offset : Int)
  raise "Invalid offset #{offset}" if offset < -1

  puts "@" + base

  case offset
  when -1
    puts "A=M-1"
  when 0
    puts "A=M"
  when 1
    puts "A=M+1"
  when 2
    puts "A=M+1"
    puts "A=A+1"
  else
    puts "A=M"
    puts "D=A"
    puts "@#{offset}"
    puts "A=A+D"
  end
end
