# encoding: utf-8
unless ARGV[0].nil?
  $: << File.join(File.expand_path(File.dirname(__FILE__)), 'lib')
  require 'error'
  require 'lexer'
  require 'emitter'
  require 'parser'
  require 'interpreter'
  begin
    lexer = Lexer.new(File.new(ARGV[0])).scan
    emitter = Emitter.new
    parser = Parser.new(lexer, emitter).parse
    emitter.build
    diag = "%s\n%s" % [lexer, emitter]
    File.open(ARGV[0][0..-File.extname(ARGV[0]).size] + 'log', 'w') do |log|
      log.write(diag)
    end
    Interpreter.new.run(emitter.pcode)
  rescue BoyarError => e
    puts "Сие творение смердит, а писарь — охальник!\n%s\n\n" % e
  end
else
  puts "Непотребно твориши, не лепо деять изволишь!\n\n"
end