module Chstr
  class Search

    # Attempts to determine who is winning
    def evaluate
      @w_material, @w_mobility, @w_position, @w_control, @w_pawns, @w_total = 0, 0, 0, 0, 0, 0
      @b_material, @b_mobility, @b_position, @b_control, @b_pawns, @b_total = 0, 0, 0, 0, 0, 0
      @w_threat, @b_threat = 1, 1
      SQ.select { |n| @colors[n] != EMPTY }.each do |from|
        color = @colors[from]
        other = color + 1 & 1
        mtrl, pst, mbl, con, ps, thr = 0, 0, 0, 0, 0, 1
        case @squares[from]
        when P
          mtrl, ps, mbl, dir = 100, 0, CENTER[from], DIR[color]
          pst = P_PST[@stage][FLIP[color][from]]
          n, s, e, w = from + dir, from - dir, from + 1, from - 1
          ne, nw, se, sw = n + 1, n - 1, s + 1, s - 1
          ps += DEFEND[@squares[nw]] * CENTER[nw] if @colors[nw] == color
          ps += DEFEND[@squares[ne]] * CENTER[ne] if @colors[ne] == color
          con += CENTER[nw] if @squares[nw] > P
          con += CENTER[ne] if @squares[ne] > P
          ps += BEHIND[@squares[n]] if @colors[n] == color
          ps += FRONT[@squares[s]] if @colors[s] == color
          ps += BLOCK[@squares[se]] if @colors[se] == color
          ps += BLOCK[@squares[sw]] if @colors[sw] == color
          ps += 2 + CENTER[e] if @squares[e] + @colors[e] == color
          ps += 2 + CENTER[w] if @squares[w] + @colors[w] == color
          ps += UNDEV[from % 10] if from / 10 == P_RANK[color]
        when N
          mtrl, mbl, pst = 305, -6, N_PST[@stage][FLIP[color][from]]
          8.times do |i|
            to = STEP[i] + from
            case @colors[to]
            when EMPTY
              mbl += 1
            when color
              con += CONNECT[@squares[to]] + CENTER[to]
              mbl += 1 unless @squares[to] == P
            when other
              if REGION_A[to] == REGION_A[@kings[other]]
                thr += 2
                thr += 2 if REGION_B[to] == REGION_B[@kings[other]]
              end
            end
          end
          mbl *= 3
        when B
          mtrl, mbl, pst = 325, -7, B_PST[@stage][FLIP[color][from]]
          4.times do |i|
            to = from + DIAG[i]
            while true
              case @colors[to]
              when EMPTY
                mbl += 1
              when color
                con += CONNECT[@squares[to]] + CENTER[to]
                break if @squares[to] == P
                mbl += 1
              when other
                if REGION_A[to] == REGION_A[@kings[other]]
                  thr += 2
                  thr += 2 if REGION_B[to] == REGION_B[@kings[other]]
                elsif DIAG_A[to] == DIAG_A[@kings[other]]
                  thr += 2 if DIAG_A[from] == DIAG_A[@kings[other]]
                elsif DIAG_B[to] == DIAG_B[@kings[other]]
                  thr += 2 if DIAG_B[from] == DIAG_B[@kings[other]]
                end
                break
              else break
              end
              to += DIAG[i]
            end
          end
          mbl *= 3
        when R
          mtrl, mbl, pst, dir = 535, -5, R_PST[@stage][FLIP[color][from]], DIR[color]
          4.times do |i|
            to = from + ORTH[i]
            while true
              case @colors[to]
              when EMPTY
                mbl += ORTH[i] == dir ? 2 : 1
              when color
                con += CONNECT[@squares[to]] + CENTER[to]
                break if @squares[to] == P
                mbl += 1
              when other
                if REGION_A[to] == REGION_A[@kings[other]]
                  thr += 2
                  thr += 2 if REGION_B[to] == REGION_B[@kings[other]]
                elsif to % 10 == @kings[other] % 10
                  thr += 2 if from % 10 == @kings[other] % 10
                end
                break
              else break
              end
              to += ORTH[i]
            end
          end
          mbl *= 2 if @stage == LATE
        when Q
          mtrl, mbl, pst = 925, -14, Q_PST[@stage][FLIP[color][from]]
          8.times do |i|
            to = from + OCTL[i]
            while true
              case @colors[to]
              when EMPTY
                mbl += 1
              when color
                con += CONNECT[@squares[to]] + CENTER[to]
                break if @squares[to] == P
                mbl += 1
              when other
                if REGION_A[to] == REGION_A[@kings[other]]
                  thr += 2
                  thr += 2 if REGION_B[to] == REGION_B[@kings[other]]
                end
                break
              else
                break
              end
              to += OCTL[i]
            end
          end
          mbl *= 2 if @stage == LATE
        when K
          pst = K_PST[@stage][FLIP[color][from]]
        end
        if color == WHITE
          @w_pawns += ps
          @w_mobility += mbl
          @w_position += pst
          @w_material += mtrl
          @w_control += con
          @w_threat *= thr
        else
          @b_pawns += ps
          @b_mobility += mbl
          @b_position += pst
          @b_material += mtrl
          @b_control += con
          @b_threat *= thr
        end
      end
      @w_threat = 0 if @w_threat < 32
      @b_threat = 0 if @b_threat < 32
      @w_total = @w_material + @w_mobility + @w_position + @w_control + @w_pawns + @w_threat
      @b_total = @b_material + @b_mobility + @b_position + @b_control + @b_pawns + @b_threat
      @evaluation = @mx == WHITE ? @w_total - @b_total : @b_total - @w_total
      @evaluation
    end
  end

end
