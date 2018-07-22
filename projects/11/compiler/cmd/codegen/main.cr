require "../../lexer/lexer"
require "../../parser/parser"
require "../../codegen/codegen"
require "../../util"

def codegen(srcpath : String, outdir : String) : Void
  outpath = File.join(outdir, File.basename(srcpath, ".jack") + ".vm")
  puts "compiling #{srcpath} to #{outpath}..."

  tokens = nil
  File.open(srcpath) { |io| tokens = Lexer.lex(io) }
  raise "Unable to tokenize #{srcpath}" if tokens.nil?

  nodes = Parser.parse(tokens)
  code = Codegen.codegen(nodes).join("\n")

  File.write(outpath, code)
end

source_path = ARGV[0]

if File.directory?(source_path)
  outdir = File.join(source_path, "out")
  Dir.mkdir_p(outdir) unless File.exists?(outdir)

  Dir.glob(File.join(source_path, "*.jack")).each do |srcpath|
    codegen(srcpath, outdir)
  end
elsif File.exists?(source_path)
  outdir = File.join(File.dirname(source_path), "out")
  Dir.mkdir_p(outdir) unless File.exists?(outdir)
  codegen(source_path, outdir)
else
  raise "Invalid source path: #{source_path}"
end
