require 'json'
require 'pgn'
PGNCLN = [/\{.*?\}/,/\(.*\)/,/\$./,/\(.*$/,/\n.*\)/]
def load_moves(filename)
  puts "Loading #{filename}"
  positions = JSON.parse(File.read('book.json'))
  pgn_data = File.read(filename)
  PGNCLN.each{ |regex| pgn_data.gsub!(regex, '') }
  PGN.parse(pgn_data).select { |game| game.moves.first == 'e4' }.each do |game|
    game.positions.first(8).each do |position|
      current = position.to_fen.inspect.split.first.gsub("/", '')
      fen << current unless fen.include?(current)
    end
    print "."
  end
  File.open('book.json', 'w'){ |f| f.puts all.to_json }
  puts "Loaded #{filename}"
end
%w(CenterGame-Danish j11 j18 j21 j22 j23 j25 j28 j34 j35 j37 j39 j40 j41 j42 j47 j48 j49 j50 j51
j52 j53 j54 j55 j57 j58 j59 j60 j61 j62 j63 j64 j65 j67 j68 j69 j70 j71 j72 j74 j75 j76 j77 j78
j79 j80 misc1 misc2 misc3 misc4 misc5 misc6 misc7 misc8 nebula1 nebula2 nebula3 nebula4 nebula5
nebula6 z3 z5 z7 z8 z9 z10 z11 z13 z14 z15).each { |f| load_moves("#{f}.pgn")}
