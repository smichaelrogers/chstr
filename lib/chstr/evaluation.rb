# The sole evaluation function
# Evaluates the state of the current board in respect to the side to move based on:
#   - Pawn structure
#   - Positioning
#   - Material
#   - Mobility of sliding pieces
#   - Center control
#   - Piece/square tables ( see definitions.rb )
#   - Attack/defense mapping
#   - King safety
class Chstr
  def evaluate
    score = 0
    attacks = []
    @nodes += 1
    @max_depth = @ply if @ply > @max_depth
    @npp[@ply] += 1

    SQ.select { |i| @squares[i] != EMPTY }.each do |from|
      color, piece = @colors[from], @squares[from]
      # piece evaluation score starts with material value + piece square value
      if @stage == MID_GAME
        current = MATERIAL[piece] + PST_MID[piece][SQ120[color][from]]
      else
        current = MATERIAL[piece] + PST_END[piece][SQ120[color][from]]
      end

      case piece
      when PAWN
        fwd = FORWARD[color]
        to = from + fwd
        # penalty for pawns sharing a file
        if @colors[to] == color
          current -= 32 if @squares[to] == PAWN
        elsif @colors[to + fwd] == color
          current -= 32 if @squares[to + fwd] == PAWN
        end
        # bonus for defensive positioning
        [to + 1, to - 1].each do |pos|
          if @colors[pos] == color
            attacks << -pos
            if @squares[pos] < ROOK
              current += CNTR[pos]
              current += CNTR[pos] if @squares[pos] == KNIGHT
            end

          elsif @colors[pos] == OTHER[color]
            attacks << pos
          end
        end

        [from + 1, from - 1].each do |pos|
          if @squares[pos] == PAWN
            current += CNTR[pos] if @colors[pos] == color
          end
        end

      when KNIGHT
        N_STEPS.each do |step|
          to = from + step
          current += CNTR[to]
          if @colors[to] == color
            current += CNTR[to]
            attacks << -to
          elsif @colors[to] == OTHER[color]
            attacks << to
          end
        end

      when BISHOP
        mobility = 0

        B_STEPS.each do |step|
          to = from + step

          while true
            current += CNTR[to]
            if @colors[to] == EMPTY
              mobility += 1
              to = to + step
              next

            elsif @colors[to] == color
              current += CNTR[to]
              attacks << -to
            elsif @colors[to] == OTHER[color]
              attacks << to
            end

            break
          end
        end

        current += MOBILITY[mobility]

      when ROOK
        mobility = 0

        R_STEPS.each do |step|
          to = from + step

          while true
            current += CNTR[to]
            if @colors[to] == EMPTY
              mobility += 1
              to = to + step
              next

            elsif @colors[to] == color
              attacks << -to
              current += CNTR[to]
            elsif @colors[to] == OTHER[color]
              attacks << to
            end

            break
          end
        end
        current += MOBILITY[mobility]

      when QUEEN
        mobility = 0

        Q_STEPS.each do |step|
          to = from + step

          while true
            current += CNTR[to]
            if @colors[to] == EMPTY
              mobility += 1
              to = to + step
              next

            elsif @colors[to] == color
              attacks << -to
              current += CNTR[to]
            elsif @colors[to] == OTHER[color]
              attacks << to
            end

            break
          end
        end

        current += MOBILITY[mobility]
        if @full_moves + @ply < 10
          current -= 16 if from != QUEEN_INITIAL[color]
        end

      when KING
        threat = 0

        8.times do |i|
          pos = from + RAYS[i]

          if @colors[pos] == color
            attacks << -pos
          elsif @colors[pos] == OTHER[color]
            attacks << pos
          end

          while @squares[pos] == EMPTY
            pos = pos + RAYS[i]
            threat += 1
          end
        end

        current += KING_THREAT[threat]
      end

      score += color == @wtm ? current : -current
    end

    return score if attacks.empty?
    attacks.sort!
    return score if attacks.last < 0

    j = -1
    attacks.length.times do |i|

      break if attacks[i] > 0
      next if -attacks[i] > attacks[j]

      if -attacks[i] == attacks[j]
        j -= 1
        next

      elsif -attacks[i] < attacks[j]
        n = 16
        pos = attacks[j]
        j -= 1
        if attacks[j] == attacks[j + 1]
          n += n
          j -= 1
          if attacks[j] == attacks[j + 1]
            n += n
            j -= 1
          end
        end

        if @squares[pos] > PAWN
          n += n
          if @squares[pos] > ROOK
            n += n
          end
        end

        if @colors[pos] == @wtm
          score -= n
        else
          score += n
        end
      end
    end

    score
  end

end
