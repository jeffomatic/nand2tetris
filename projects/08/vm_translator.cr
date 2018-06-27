require "option_parser"

struct SourceLoc
  getter path, line, basename

  def initialize(@path : String, @line : Int32)
    @basename = File.basename(@path, File.extname(@path))
  end

  def to_s
    "#{path}:#{line}"
  end

  def to_mangled_s
    "#{basename}__#{line}"
  end
end

def exit_error(parser, s) : NoReturn
  STDERR.puts "Error: #{s}"
  STDERR.puts parser
  exit(1)
end

skip_init = false
source_path = ""

parser = OptionParser.parse! do |parser|
  parser.banner = "Usage: #{PROGRAM_NAME} [flags] source_path"
  parser.on("--skip-init", "Skips initialization code") { skip_init = true }
  parser.on("-h", "--help", "Show usage") do
    puts parser
    exit
  end
  parser.unknown_args do |before_dash, after_dash|
    exit_error(parser, "invalid source path") if before_dash.size != 1 || after_dash.size != 0
    source_path = before_dash.first
  end
  parser.invalid_option do |flag|
    exit_error(parser, "#{flag} is not a valid option.")
  end
end

exit_error(parser, "no source path provided") if source_path.size == 0
init_program unless skip_init

if File.directory?(source_path)
  Dir.new(source_path).each_child.select { |c|
    !File.directory?(File.join(source_path, c)) && File.extname(c) == ".vm"
  }.to_a.sort { |a, b|
    next -1 if a == "Sys.vm"
    next 1 if b == "Sys.vm"
    a <=> b
  }.each { |c|
    handle_source(File.join(source_path, c))
  }
elsif File.exists?(source_path)
  handle_source(source_path)
end

def handle_source(path : String) : Nil
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
    loc = SourceLoc.new(path, line)

    case command
    when "push"     then push_command(args, loc)
    when "pop"      then pop_command(args, loc)
    when "add"      then binary_operator_command(args, loc, "add", "+")
    when "sub"      then binary_operator_command(args, loc, "add", "-")
    when "and"      then binary_operator_command(args, loc, "add", "&")
    when "or"       then binary_operator_command(args, loc, "add", "|")
    when "not"      then unary_operator_command(args, loc, "not", "!")
    when "neg"      then unary_operator_command(args, loc, "neg", "-")
    when "eq"       then comparison_command(args, loc, "eq", "JEQ")
    when "gt"       then comparison_command(args, loc, "gt", "JGT")
    when "lt"       then comparison_command(args, loc, "lt", "JLT")
    when "label"    then label_command(args, loc)
    when "goto"     then goto_command(args, loc)
    when "if-goto"  then if_goto_command(args, loc)
    when "call"     then call_command(args, loc)
    when "function" then function_command(args, loc)
    when "return"   then return_command(args, loc)
    else                 raise "#{loc}: invalid command #{c.join}"
    end
  end
end

def push_command(args : Array(String), loc : SourceLoc)
  check_arg_count(args, loc, 2, "push")
  segment = args[0]
  offset = cast_numeric_literal(args[1], loc, min: 0, max: 32767)

  case segment
  when "argument"
    load_segment_offset("ARG", offset)
    puts "D=M" # deref address and cache value
  when "local"
    load_segment_offset("LCL", offset)
    puts "D=M" # deref address and cache value
  when "static"
    puts "@#{loc.basename}.#{offset}"
    puts "D=M" # deref address and cache value
  when "constant"
    puts "@#{offset}"
    puts "D=A" # cache immediate value
  when "this"
    load_segment_offset("THIS", offset)
    puts "D=M" # deref address and cache value
  when "that"
    load_segment_offset("THAT", offset)
    puts "D=M" # deref address and cache value
  when "pointer"
    case offset
    when 0 then puts "@THIS"
    when 1 then puts "@THAT"
    else        raise "#{loc}: push command: invalid offset for pointer segment"
    end

    puts "D=M" # deref address and cache value
  when "temp"
    offset += 5 # temp segment starts at RAM[5]
    raise "#{loc}: push command: invalid offset for temp segment" if offset < 5 || 12 < offset

    puts "@#{offset}"
    puts "D=M" # deref address and cache value
  else
    raise "#{loc}: push command: invalid memory segment #{segment}"
  end

  stack_push_d
end

def pop_command(args : Array(String), loc : SourceLoc)
  check_arg_count(args, loc, 2, "pop")
  segment = args[0]
  offset = cast_numeric_literal(args[1], loc, min: 0, max: 32767)

  case segment
  when "argument" then load_segment_offset("ARG", offset)
  when "local"    then load_segment_offset("LCL", offset)
  when "static"   then puts "@#{loc.basename}.#{offset}"
  when "this"     then load_segment_offset("THIS", offset)
  when "that"     then load_segment_offset("THAT", offset)
  when "pointer"
    case offset
    when 0 then puts "@THIS"
    when 1 then puts "@THAT"
    else        raise "#{loc}: push command: invalid offset for pointer segment"
    end
  when "temp"
    offset += 5 # temp segment starts at RAM[5]
    raise "#{loc}: push command: invalid offset for temp segment" if offset < 5 || 12 < offset
    puts "@#{offset}"
  else
    raise "#{loc}: push command: invalid memory segment #{segment}"
  end

  # Cache target location in R13
  puts "D=A"  # $D = target address
  puts "@R13" # $A = 13
  puts "M=D"  # *13 = target address

  # Pop value off of stack into $D
  load_segment_offset("SP", -1) # $A = address of last stack value
  puts "D=M"                    # $D = last stack value
  decrement_stack_pointer       # won't clobber $D

  # Load target location into $A
  puts "@R13" # $A = 13
  puts "A=M"  # $A = *13
  puts "M=D"  # **13 = $D
end

def binary_operator_command(args : Array(String), loc : SourceLoc, command : String, operator : String)
  check_arg_count(args, loc, 0, command)

  load_segment_offset("SP", -1)
  puts "D=M"             # load second operand
  puts "A=A-1"           # move backward in stack
  puts "M=M#{operator}D" # overwrite first operand with result of applying operator to first and second operand
  decrement_stack_pointer
end

def unary_operator_command(args : Array(String), loc : SourceLoc, command : String, operator : String)
  check_arg_count(args, loc, 0, command)

  load_segment_offset("SP", -1)
  puts "M=#{operator}M" # overwite top of the stack with negation
end

def comparison_command(args : Array(String), loc : SourceLoc, command : String, op : String)
  check_arg_count(args, loc, 0, command)

  load_segment_offset("SP", -1)
  puts "D=M"                                  # load second operand
  puts "A=A-1"                                # move backward in stack
  puts "D=M-D"                                # subtract second operand from first
  puts "@__cond_true__#{loc.to_mangled_s}__"  # load jump label address
  puts "D;#{op}"                              # jump on comparison
  puts "D=0"                                  # comparison not true
  puts "@__cond_done__#{loc.to_mangled_s}__"  # load done
  puts "0;JMP"                                # goto done
  puts "(__cond_true__#{loc.to_mangled_s}__)" # equal label label
  puts "D=-1"                                 # equal
  puts "(__cond_done__#{loc.to_mangled_s}__)" # done label
  decrement_stack_pointer
  puts "A=M-1" # move backward (address of first operand)
  puts "M=D"   # overwrite first operand with equality value
end

def label_command(args : Array(String), loc : SourceLoc)
  check_arg_count(args, loc, 1, "label")
  puts "(__label__#{args[0]})"
end

def goto_command(args : Array(String), loc : SourceLoc)
  check_arg_count(args, loc, 1, "goto")
  puts "@__label__#{args[0]}"
  puts "0;JMP"
end

def if_goto_command(args : Array(String), loc : SourceLoc)
  check_arg_count(args, loc, 1, "if-goto")

  decrement_stack_pointer
  load_segment_offset("SP", 0)
  puts "D=M" # load top stack value
  puts "@__label__#{args[0]}"
  puts "D;JNE"
end

def call_command(args : Array(String), loc : SourceLoc)
  check_arg_count(args, loc, 2, "call")
  func = args[0]
  argc = args[1].to_i

  # Load return address and push to stack
  puts "@__return__#{loc.to_mangled_s}__#{func}"
  puts "D=A"
  stack_push_d

  # Push frame state to stack
  ["LCL", "ARG", "THIS", "THAT"].each do |reg|
    puts "@#{reg}"
    puts "D=M"
    stack_push_d
  end

  # Set ARG
  puts "@SP"   # $A = SP
  puts "D=M"   # $D = *SP
  puts "@5"    # $A = 5
  puts "D=D-A" # $D = *SP - 5

  if argc > 0
    puts "@#{argc}" # $A = num_args
    puts "D=D-A"    # $D = *SP - 5 - num_args
  end

  puts "@ARG" # $A = ARG
  puts "M=D"  # *ARG = *SP - 5 - num_args

  # Set LCL
  puts "@SP"  # $A = SP
  puts "D=M"  # $D = *SP
  puts "@LCL" # $A = LCL
  puts "M=D"  # *LCL = *SP

  # Jump to function code
  puts "@__func__#{func}"
  puts "0;JMP"

  # Place return address label
  puts "(__return__#{loc.to_mangled_s}__#{func})"
end

def function_command(args : Array(String), loc : SourceLoc)
  check_arg_count(args, loc, 2, "function")

  # Write jump label
  puts "(__func__#{args[0]})"

  # Initialize local variables
  argc = args[1].to_i
  if argc > 0
    puts "D=0"
    argc.times { stack_push_d }
  end
end

def return_command(args : Array(String), loc : SourceLoc)
  check_arg_count(args, loc, 0, "return")

  # Cache th return value, which sits at *LCL - 5. In the case of a zero-argument
  # function, this is the same as *ARG.
  puts "@LCL"  # $A = LCL
  puts "D=M"   # $D = *LCL
  puts "@5"    # $A = 5
  puts "A=D-A" # $A = *LCL - 5
  puts "D=M"   # $D = *(*LCL - 5)
  puts "@R13"  # $A = 13
  puts "M=D"   # *13 = *(*LCL - 5)

  # Set return value: Set start of ARG segment (start of closing frame) to the
  # top value of the stack.
  # **ARG = *(*SP - 1)
  puts "@SP"   # $A = SP
  puts "A=M-1" # $A = *SP - 1
  puts "D=M"   # $D = *(*SP - 1)
  puts "@ARG"  # $A = ARG
  puts "A=M"   # $A = *ARG
  puts "M=D"   # **ARG = $D

  # We no longer have use for the current SP value, so we can go ahead and
  # restore it to just after the return value.
  puts "@ARG"  # $A = ARG
  puts "D=M+1" # $D = *ARG + 1
  puts "@SP"   # $A = SP
  puts "M=D"   # *SP = *ARG + 1

  # R15 contains a pointer that moves backward from the start of the local
  # segment.
  # Move R15 to LCL-1 (previous THAT)
  puts "@LCL"  # $A = LCL
  puts "D=M-1" # $D = *LCL - 1
  puts "@R15"  # $A = 15
  puts "AM=D"  # $A = *15 = *LCL - 1

  # Restore THAT
  puts "D=M"   # $D = *(*LCL - 1)
  puts "@THAT" # $A = THAT
  puts "M=D"   # *THAT = *(*LCL - 1)

  # Move R15 to LCL-2 (previous THIS)
  puts "@R15"   # $A = 15
  puts "AM=M-1" # $A = *15 = *LCL - 2

  # Restore THIS
  puts "D=M"   # $D = *(*LCL - 2)
  puts "@THIS" # $A = THIS
  puts "M=D"   # *THIS = *(*LCL - 2)

  # Move R15 to LCL-3 (previous ARG)
  puts "@R15"   # $A = 15
  puts "AM=M-1" # $A = *15 = *LCL - 3

  # Restore ARG
  puts "D=M"  # $D = *(*LCL - 3)
  puts "@ARG" # $A = ARG
  puts "M=D"  # *ARG = *(*LCL - 3)

  # Move R15 to LCL-4 (previous LCL)
  puts "@R15"   # $A = 15
  puts "AM=M-1" # $A = *15 = *LCL - 4

  # Restore LCL
  puts "D=M"  # $D = *(*LCL - 4)
  puts "@LCL" # $A = LCL
  puts "M=D"  # *LCL = *(*LCL_prev - 4)

  # Load return address, which was cached in R13
  puts "@R13" # $A = 13
  puts "A=M"  # $A = *13

  # Jump!
  puts "0;JMP"
end

def check_arg_count(args : Array(String), loc : SourceLoc, want : Int, command : String)
  got = args.size
  raise "#{loc}: #{command} command: got #{got} args, want #{want}" if got != want
end

def cast_numeric_literal(literal : String, loc : SourceLoc, *, min : Int? = nil, max : Int? = nil) : Int
  begin
    n = literal.to_i

    if !min.nil? && n < min
      raise "#{loc}: numeric literal #{literal} is less than minimum #{min}"
    end

    if !max.nil? && n > max
      raise "#{loc}: numeric literal #{literal} is greater than max #{max}"
    end

    n
  rescue ArgumentError
    raise "#{loc}: invalid numeric literal #{literal}"
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

def decrement_stack_pointer
  puts "@SP"   # load stack pointer address
  puts "M=M-1" # decrement stack pointer
end

def increment_stack_pointer
  puts "@SP"   # $A = SP
  puts "M=M+1" # *SP = *SP + 1
end

def stack_push_d
  load_segment_offset("SP", 0)
  puts "M=D" # write to stack top
  increment_stack_pointer
end

def init_program
  # Set SP to 256
  puts "@256"
  puts "D=A"
  puts "@SP"
  puts "M=D"

  # Set LCL, ARG, THIS, THAT to -1
  puts "@0"
  puts "D=!A"
  puts "@LCL"
  puts "M=D"
  puts "@ARG"
  puts "M=D"
  puts "@THIS"
  puts "M=D"
  puts "@THAT"
  puts "M=D"

  # Call Sys.init
  call_command(["Sys.init", "0"], SourceLoc.new("__init__", 0))
end
