require "../../lexer/lexer"
require "../../parser/parser"
require "../../codegen/codegen"
require "../../util"

def codegen(srcpath : String, outdir : String) : Void
  tokens = nil
  File.open(srcpath) { |io| tokens = Lexer.lex(io) }
  raise "Unable to tokenize #{srcpath}" if tokens.nil?

  nodes = Parser.parse(tokens)
  globals = Codegen.collect_globals(nodes)
  code = Codegen.codegen(globals, nodes).join("\n")

  outpath = File.join(outdir, File.basename(srcpath, ".jack") + ".vm")
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
