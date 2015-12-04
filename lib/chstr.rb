require 'json'
# All of Chstr resides in one class spread across several files.
# Although this is clearly not in line with most Ruby styleguides it seems to be the most efficient
# approach to avoiding many of the pitfalls in Ruby performance.
# This file contains the functionality involved in interfacing with the browser.
# The Chstr object represents a move search from any gamestate translated from a FEN string, although
# by tweaking a few lines Chstr is capible of playing against itself in the console.
class Chstr
  # Creates a new Chstr instance by loading a FEN string
  # The default parameter, INIT_FEN is the starting position of a game:
  #   'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1'
  # (see https://en.wikipedia.org/wiki/Forsyth%E2%80%93Edwards_Notation)
  def initialize(fen = INIT_FEN)
    load_fen(fen)
  end

  # Takes a move gathered from the browser and applies it to the current gamestate
  def input_move(from_id, to_id)
    from, to = SQ_ID.index(from_id), SQ_ID.index(to_id)
    piece, target = @squares[from], @squares[to]
    type, @ep = QUIET, nil
    # update irreversibles
    if piece == PAWN
      if (from - to).abs == 20
        type = PAWN_DOUBLE_PUSH
        @ep = from + FORWARD[@wtm]
      elsif (from - to).abs == 10
        type = PAWN_PUSH
      elsif (from - to).abs == 1
        type = EP_CAPTURE
      end
      @fifty = 0
    elsif piece == ROOK
      @castling.delete(from)
    elsif piece == KING
      @castling.delete(KSC[@wtm])
      @castling.delete(QSC[@wtm])
      type = CASTLE if (from - to).abs == 2
    end

    if target != EMPTY
      type = CAPTURE
      @fifty = 0
    elsif piece != PAWN
      @fifty += 1
    end

    root_make(from, to, piece, target, type)
  end

  # Parses and creates a set of instance variables that will be used during the move search.
  def load_fen(fen)
    sect = fen.split
    @colors, @squares = INIT.dup, INIT.dup

    sect.first.split("/").
      map { |i| i.chars.
      map { |j| RANK.include?(j) ? j.to_i.times.
      map { 6 } : j }}.flatten.each_with_index do |sq, i|

      if sq == EMPTY
        @colors[SQ[i]], @squares[SQ[i]] = EMPTY, EMPTY
      else
        @colors[SQ[i]] = sq == sq.downcase ? BLACK : WHITE
        @squares[SQ[i]] = FEN_SQUARES[BLACK].index(sq.downcase)
      end
    end

    @kings = [ SQ.find { |i| @colors[i] == WHITE && @squares[i] == KING },
               SQ.find { |i| @colors[i] == BLACK && @squares[i] == KING } ]

    @wtm = FEN_COLOR[sect[1]]
    @ntm = OTHER[@wtm]
    @castling = []
    FEN_CASTLE.each { |letter, square| @castling << square if sect[2].include?(letter) }

    @ep = sect[3] == '-' ? nil : SQ_ID.index(sect[3])
    @fifty = sect[4].to_i
    @full_moves = sect[5].to_i
    @ply = 0
  end

  # Translates the current gamestate to be stored in browser memory, so the game can be recreated
  # and the user's move can be applied
  def to_fen
    fen, str, num_empty = [], "", 0
    # translate piece positions and account for empty squares
    SQRND.each do |row|
      row.each do |col|
        if @colors[col] == EMPTY
          num_empty += 1
          next
        end

        str += num_empty.to_s if num_empty > 0
        str += FEN_SQUARES[@colors[col]][@squares[col]]
        num_empty = 0
      end

      str += num_empty.to_s if num_empty > 0
      fen << str
      str, num_empty = "", 0
    end

    fen = [fen.join("/")]
    fen << ['w', 'b'][@wtm]
    # append irreversibles to the fen array
    FEN_CASTLE.each { |letter, square| str += letter if @castling.include?(square) }
    fen << str == "" ? "-" : str
    fen << @ep ? SQ_ID[@ep] : "-"
    fen << @fifty.to_s
    fen << @full_moves.to_s

    fen.join(" ")
  end

  # Generates a bunch of lovely stuff for the browser
  def generate_json
    npp_percentages = []
    npp_max = 0
    npp_max_ply = 0
    time_elapsed = (Time.now - @duration.to_f).round(1)
    moves = []
    @npp[1, 16].each_with_index do |i, idx|
      if i > npp_max
        npp_max = i
        npp_max_ply = idx
      end
      npp_percentages << ((i.to_f / @nodes.to_f) * 100.0).round(1)
    end
    valid_moves = valid_root_moves
    SQ.each do |sq|
      if @colors[sq] != EMPTY
        piece, color = @squares[sq], @colors[sq]

        if color == @wtm
          current_moves = valid_moves.select { |m| m[0] == sq }.map { |m| SQ_ID[m[1]] }
        else
          current_moves = []
        end
        moves << { square: SQ_ID[sq], moves: current_moves }
      end
    end
    pv_length = 0
    @pv.each_with_index do |m, depth|
      if m.empty?
        pv_length = depth
      end
    end

    {
      fen: to_fen,
      moves: moves,
      from: SQ_ID[@best_move[0]],
      to: SQ_ID[@best_move[1]],
      npp: {
        count: @npp,
        percentages: npp_percentages,
        pv: @pv[0, 16]
      },
      report: {
        'move' => "#{UTF8[WHITE][@best_move[2]]} #{SQ_ID[@best_move[0]]} #{SQ_ID[@best_move[1]]}",
        'move type' => TYPES[@best_move[4]],
        'move score' => @best_score,
        'move changes' => @pv[0].count,
        'principal variation length' => pv_length,
        'evaluation after move' => evaluate,
        'evaluations' => @nodes,
        'evaluations per second' => (@nodes.to_f / time_elapsed).round(1),
        'time elapsed' => time_elapsed,
        'time allotted' => @duration,
        'max depth' => @max_depth,
        'median depth' => npp_max_ply,
        'horizon depth' => @hrzn,
        'nodes at median' => npp_max
      }
    }.to_json
  end

end
