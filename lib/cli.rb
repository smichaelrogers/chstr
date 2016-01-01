# require_relative 'definitions'
# require_relative 'search'
# require_relative 'interface'
# require_relative 'move_gen'
# require_relative 'evaluate'
# require 'json'
# require 'byebug'
# module Chstr
#   class Search
#     def show_board
#       SQ.each_with_index do |sq, i|
#         puts if i % 8 == 0
#         if @colors[sq] == EMPTY
#           print " _ "
#         else
#           print " #{UTF8[@colors[sq]][@squares[sq]]} "
#         end
#       end
#       print "\n\n"
#     end
#   end
# end
#
# fen = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"
# i = 0
# history = []
# while true
#   search = Chstr::Search.new(fen)
#   search.history = history
#   search.start
#   search.show_board
#   history = search.history
#   g = search.render
#   debugger
#   fen = search.fen
#   i += 1
# end
