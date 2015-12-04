require 'json'
require 'pgn'
PGNCLN = [/\{.*?\}/,/\(.*\)/,/\$./,/\(.*$/,/\n.*\)/]
FILE = ['a','b','c','d','e','f','g','h']
RANK = ['1','2','3','4','5','6','7','8']
PIECES = ['','N','B','R','Q','K']
UTF8 = [
  ['♙', '♘', '♗', '♖', '♕', '♔'],
  ['♟', '♞', '♝', '♜', '♛', '♚']]

def load_moves(filename)
  puts "loading #{filename}"
  all = JSON.parse(File.read('book.json'))
  pgn_data = File.read(filename)
  PGNCLN.each{ |regex| pgn_data.gsub!(regex, '') }
  PGN.parse(pgn_data).each do |game|
    next if game.moves.first != 'e4'
    game.positions.each_with_index do |position, turn|
      break if turn > 7
      fen = position.to_fen.inspect.split.first.gsub("/", '')
      if !all.include?(fen)
        all << fen
      end
    end
  end
  puts "loaded #{filename}"
  File.open('book.json', 'w'){ |f| f.puts all.to_json }
end
load_moves('pgn/CenterGame-Danish.pgn')
load_moves('pgn/j11.pgn')
load_moves('pgn/j18.pgn')
load_moves('pgn/j21.pgn')
load_moves('pgn/j22.pgn')
load_moves('pgn/j23.pgn')
load_moves('pgn/j25.pgn')
load_moves('pgn/j28.pgn')
load_moves('pgn/j34.pgn')
load_moves('pgn/j35.pgn')
load_moves('pgn/j37.pgn')
load_moves('pgn/j39.pgn')
load_moves('pgn/j40.pgn')
load_moves('pgn/j41.pgn')
load_moves('pgn/j42.pgn')
load_moves('pgn/j47.pgn')
load_moves('pgn/j48.pgn')
load_moves('pgn/j49.pgn')
load_moves('pgn/j50.pgn')
load_moves('pgn/j51.pgn')
load_moves('pgn/j52.pgn')
load_moves('pgn/j53.pgn')
load_moves('pgn/j54.pgn')
load_moves('pgn/j55.pgn')
load_moves('pgn/j57.pgn')
load_moves('pgn/j58.pgn')
load_moves('pgn/j59.pgn')
load_moves('pgn/j60.pgn')
load_moves('pgn/j61.pgn')
load_moves('pgn/j62.pgn')
load_moves('pgn/j63.pgn')
load_moves('pgn/j64.pgn')
load_moves('pgn/j65.pgn')
load_moves('pgn/j67.pgn')
load_moves('pgn/j68.pgn')
load_moves('pgn/j69.pgn')
load_moves('pgn/j70.pgn')
load_moves('pgn/j71.pgn')
load_moves('pgn/j72.pgn')
load_moves('pgn/j74.pgn')
load_moves('pgn/j75.pgn')
load_moves('pgn/j76.pgn')
load_moves('pgn/j77.pgn')
load_moves('pgn/j78.pgn')
load_moves('pgn/j79.pgn')
load_moves('pgn/j80.pgn')
load_moves('pgn/misc1.pgn')
load_moves('pgn/misc2.pgn')
load_moves('pgn/misc3.pgn')
load_moves('pgn/misc4.pgn')
load_moves('pgn/misc5.pgn')
load_moves('pgn/misc6.pgn')
load_moves('pgn/misc7.pgn')
load_moves('pgn/misc8.pgn')
load_moves('pgn/nebula1.pgn')
load_moves('pgn/nebula2.pgn')
load_moves('pgn/nebula3.pgn')
load_moves('pgn/nebula4.pgn')
load_moves('pgn/nebula5.pgn')
load_moves('pgn/nebula6.pgn')
load_moves('pgn/z3.pgn')
load_moves('pgn/z5.pgn')
load_moves('pgn/z7.pgn')
load_moves('pgn/z8.pgn')
load_moves('pgn/z9.pgn')
load_moves('pgn/z10.pgn')
load_moves('pgn/z11.pgn')
load_moves('pgn/z13.pgn')
load_moves('pgn/z14.pgn')
load_moves('pgn/z15.pgn')
