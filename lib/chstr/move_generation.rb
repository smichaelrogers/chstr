# Generation of moves for the side to move.  Uses some simple heuristics to order them in a way
# that should yield faster cutoffs (more pruning of the search tree, less wasted evaluations).
#   Types of moves: (see 'definitions.rb')
#   QUIET - not a capture or pawn move, increases the fifty move clock
#   CASTLE - castling move, either side, increases the fifty move clock
#   CAPTURE - resets fifty move clock
#   PAWN_PUSH - resets fifty move clock
#   DOUBLE_PAWN_PUSH - resets fifty move clock, sets ep square directly behind the 'to' position
class Chstr
  # Collects all moves for the side to move, including castling and en passant captures,
  # most of the move ordering will be done after the initial search before iterative deepening
  def generate_root_moves
    moves = []
    check = in_check?

    SQ.select { |sq| @colors[sq] == @wtm }.each do |from|
      piece = @squares[from]

      if piece != PAWN
        STEP[piece].each do |step|
          to = from + step

          while true
            target = @squares[to]

            if @colors[to] == EMPTY
              if @state == MID_GAME
                rating = PST_MID[piece][SQ120[@wtm][to]] - PST_MID[piece][SQ120[@wtm][from]]
              else
                rating = PST_END[piece][SQ120[@wtm][to]] - PST_END[piece][SQ120[@wtm][from]]
              end

              moves << [from, to, piece, target, QUIET, rating]

              if piece == KING
                # already know there is no check since that would result in 'generate_root_evasions'
                if step == 1 && @castling.include?(KSC[@wtm])
                  if @squares[to + 1] == EMPTY
                    moves << [from, to + 1, KING, EMPTY, CASTLE, 110]
                  end

                elsif step == -1 && @castling.include?(QSC[@wtm])
                  to -= 1
                  if @squares[to] == EMPTY && @squares[to - 1] == EMPTY
                    moves << [from, to, KING, EMPTY, CASTLE, 110]
                  end
                end
              end

              break unless SLIDING[piece]

              to += step
              next

            elsif @colors[to] == @ntm
              if @squares[to] > piece
                moves << [from, to, piece, target, CAPTURE, 130]
              else
                moves << [from, to, piece, target, CAPTURE, 100]
              end
            end

            break
          end
        end

      else
        # pawn moves

        to = from + FORWARD[@wtm]

        if @colors[to + 1] == @ntm
          if @squares[to + 1] > PAWN
            rating = 160
          else
            rating = 120
          end

          moves << [from, to + 1, PAWN, @squares[to + 1], CAPTURE, rating]
        end

        if @colors[to - 1] == @ntm
          if @squares[to - 1] > PAWN
            rating = 160
          else
            rating = 120
          end

          moves << [from, to - 1, PAWN, @squares[to - 1], CAPTURE, rating]
        end

        if @ep
          # if @ep isn't nil, and forward && left or right is == @ep, then it can be captured
          if to + 1 == @ep
            moves << [from, to + 1, PAWN, EMPTY, EP_CAPTURE, 110]
          elsif to - 1 == @ep
            moves << [from, to - 1, PAWN, EMPTY, EP_CAPTURE, 110]
          end
        end

        if @colors[to] == EMPTY
          if @stage == MID_GAME
            rating = PST_MID[PAWN][SQ120[@wtm][to]] - PST_MID[PAWN][SQ120[@wtm][from]]
          else
            rating = PST_END[PAWN][SQ120[@wtm][to]] - PST_END[PAWN][SQ120[@wtm][from]]
          end

          moves << [from, to, PAWN, EMPTY, PAWN_PUSH, rating]

          if from > 80 || from < 40
            to += FORWARD[@wtm]

            if @colors[to] == EMPTY
              if @stage == MID_GAME
                rating = PST_MID[PAWN][SQ120[@wtm][to]] - PST_MID[PAWN][SQ120[@wtm][from]]
              else
                rating = PST_END[PAWN][SQ120[@wtm][to]] - PST_END[PAWN][SQ120[@wtm][from]]
              end
              moves << [from, to, PAWN, EMPTY, PAWN_DOUBLE_PUSH, rating]
            end
          end
        end
      end
    end

    moves.sort_by{ |m| -m[5] }
  end

  # Collects moves for when in check, uses a different ordering method and doesn't
  # allow castling.  Prioritizes moves that block the path of the attacker or capture it.
  def generate_root_evasions
    paths, moves = [], []
    k = @kings[@wtm]

    # find the positions that block/capture the attacker
    8.times do |i|
      pos = k + N_STEPS[i]
      # check if the attacker is a knight
      if @squares[pos] == KNIGHT && @colors[pos] == @ntm
        paths << pos
      end

      pos = RAYS[i] + k
      current_path = []
      # follow ray until either invalid square or a piece
      while @squares[pos] == EMPTY
        current_path << pos
        pos = pos + RAYS[i]
      end
      # only matters if piece belongs to the opponent
      next unless @colors[pos] == @ntm

      current_path << pos
      case @squares[pos]
      when QUEEN
        paths.concat(current_path)
      when BISHOP
        # (-9, 9, -11, 11)
        paths.concat(current_path) if i < 4
      when ROOK
        # (-10, 10, -1, 1)
        paths.concat(current_path) if i > 3
      when PAWN
        paths << pos if pos + FORWARD[@ntm] - 1 == k || pos + FORWARD[@ntm] + 1 == k
      end
    end

    SQ.select { |sq| @colors[sq] == @wtm }.each do |from|
      piece = @squares[from]

      if piece != PAWN
        STEPS[piece].times do |j|
          step = STEP[piece][j]
          to = from + step

          while true
            target = @squares[to]
            if @colors[to] == EMPTY
              if paths.include?(to)
                moves << [from, to, piece, target, QUIET, 100]
              else
                moves << [from, to, piece, target, QUIET, 0]
              end

              break unless SLIDING[piece]
              to += step
              next

            elsif @colors[to] == @ntm
              if paths.include?(to)
                moves << [from, to, piece, target, CAPTURE, 110]
              else
                moves << [from, to, piece, target, CAPTURE, 10]
              end
            end
            break
          end

        end
      else

        to = from + FORWARD[@wtm]

        if @colors[to + 1] == @ntm
          if paths.include?(to + 1)
            moves << [from, to + 1, PAWN, @squares[to + 1], CAPTURE, 115]
          else
            moves << [from, to + 1, PAWN, @squares[to + 1], CAPTURE, 15]
          end
        end

        if @colors[to - 1] == @ntm
          if paths.include?(to - 1)
            moves << [from, to - 1, PAWN, @squares[to - 1], CAPTURE, 115]
          else
            moves << [from, to - 1, PAWN, @squares[to - 1], CAPTURE, 15]
          end
        end

        if @colors[to] == EMPTY
          if paths.include?(to)
            moves << [from, to, PAWN, EMPTY, PAWN_PUSH, 100]
          else
            moves << [from, to, PAWN, EMPTY, PAWN_PUSH, 5]
          end

          if from > 80 || from < 40
            to += FORWARD[@wtm]
            if @colors[to] == EMPTY
              if paths.include?(to)
                moves << [from, to, PAWN, EMPTY, PAWN_DOUBLE_PUSH, 105]
              else
                moves << [from, to, PAWN, EMPTY, PAWN_DOUBLE_PUSH, 10]
              end
            end
          end
        end
      end
    end

    moves.sort_by{ |m| -m[5] }
  end

  # Collects all sub-root moves, doesn't look for castling or en passant capturing moves,
  # orders them with several heuristics described below.
  def generate_moves
    moves = []
    SQ.select { |sq| @colors[sq] == @wtm }.each do |from|
      piece = @squares[from]
      if piece != PAWN

        STEP[piece].each do |step|
          to = from + step

          while true
            target = @squares[to]
            if target == EMPTY
              moves << [from, to, piece, EMPTY]

              break unless SLIDING[piece]
              to = to + step
              next

            elsif @colors[to] == @ntm
              moves << [from, to, piece, target]
            end

            break
          end
        end

      else
        to = from + FORWARD[@wtm]
        if @colors[to + 1] == @ntm
          moves << [from, to + 1, PAWN, @squares[to + 1]]
        end

        if @colors[to - 1] == @ntm
          moves << [from, to - 1, PAWN, @squares[to - 1]]
        end

        if @colors[to] == EMPTY
          moves << [from, to, PAWN, EMPTY]
          if from > 80 || from < 40
            to = to + FORWARD[@wtm]
            if @colors[to] == EMPTY
              moves << [from, to, PAWN, EMPTY]
            end
          end
        end
      end
    end

    moves.sort_by { |m|
      (
        # bonus for captures, greater bonus for winning captures
        (m[3] == EMPTY ? 0 : (m[3] > m[2] ? 120 : 60)) +
        # prioritize moves that have yielded cutoffs at this ply
        (@kt[@ply][m[2]][m[1]] * 8) +
        # prioritize moves that have yielded cutoffs one move (two ply) separated slightly less
        (@kt[@ply - 2][m[2]][m[1]] * 4) +
        # and moves that have caused any cutoffs at all, at any depth, get a bonus
        @ht[m[2]][m[1]]
      # divide everything by the number of times the move has not yielded anything significant
      ) / @bt[m[2]][m[1]] }
  end

  # Generates only capturing moves.  Same thing as 'generate_moves', but pickier.
  # Orders moves from least valuable attacker && most valuable target to most valuable attacker
  # and least valuable target.
  def generate_captures
    captures = []
    SQ.select { |sq| @colors[sq] == @wtm }.each do |from|
      piece = @squares[from]

      if piece != PAWN

        STEPS[piece].times do |j|
          step = STEP[piece][j]
          to = from + step

          while true
            target = @squares[to]
            if @colors[to] == EMPTY

              break if !SLIDING[piece]
              to = to + step
              next

            elsif @colors[to] == @ntm
              captures << [from, to, piece, target]
            end

            break
          end
        end

      else
        to = from + FORWARD[@wtm]
        if @colors[to + 1] == @ntm
          captures << [from, to + 1, PAWN, @squares[to + 1]]
        end
        if @colors[to - 1] == @ntm
          captures << [from, to - 1, PAWN, @squares[to - 1]]
        end
      end
    end

    captures.sort_by { |m| MATERIAL[m[3]] - MATERIAL[m[2]] }
  end

  # Determines if the side to move is in check, returns true immiediately upon discovering check
  def in_check?
    k = @kings[@wtm]

    8.times do |i|
      pos = k + N_STEPS[i]
      # check for knights
      if @squares[pos] == KNIGHT
        return true if @colors[pos] == @ntm
      end

      pos = RAYS[i] + k
      # follows the ray until a piece or the end of the board is found
      while @squares[pos] == EMPTY
        pos += RAYS[i]
      end
      # ignore friendly pieces and invalid squares
      next if @colors[pos] != @ntm

      case @squares[pos]
      when QUEEN
        return true
      when BISHOP
        return true if i < 4
      when ROOK
        return true if i > 3
      when PAWN
        return true if pos + FORWARD[@ntm] - 1 == k || pos + FORWARD[@ntm] + 1 == k
      end
    end

    false
  end

end
