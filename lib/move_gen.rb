module Chstr
  class Search

    # Generates all moves for the current side
    def generate_moves(only_captures = false)
      @check = in_check?
      ep, castling = @mv[@on_mv[@ply - 1]].ep, @mv[@on_mv[@ply - 1]].castling
      SQ.select { |sq| @colors[sq] == @mx }.each do |from|
        case @squares[from]
        when P
          to = from + DIR[@mx]
          add_move(from, to + 1, P, true) if @colors[to + 1] == @mn || to + 1 == ep
          add_move(from, to - 1, P, true) if @colors[to - 1] == @mn || to - 1 == ep
          if @colors[to] == EMPTY && !only_captures
            add_move(from, to, P)
            if (from > 80 || from < 40) && @colors[to + DIR[@mx]] == EMPTY
              add_move(from, to + DIR[@mx], P)
            end
          end
        when N
          STEP.each do |n|
            if @colors[from + n] == @mn
              add_move(from, from + n, N, true)
            elsif @colors[from + n] == EMPTY && !only_captures
              add_move(from, from + n, N)
            end
          end
        when B
          DIAG.each do |n|
            to = from + n
            while @colors[to] == EMPTY
              add_move(from, to, B) unless only_captures
              to += n
            end
            add_move(from, to, B, true) if @colors[to] == @mn
          end
        when R
          ORTH.each do |n|
            to = from + n
            while @colors[to] == EMPTY
              add_move(from, to, R) unless only_captures
              to += n
            end
            add_move(from, to, R, true) if @colors[to] == @mn
          end
        when Q
          OCTL.each do |n|
            to = from + n
            while @colors[to] == EMPTY
              add_move(from, to, Q) unless only_captures
              to += n
            end
            add_move(from, to, Q, true) if @colors[to] == @mn
          end
        when K
          OCTL.each do |n|
            if @colors[from + n] == @mn
              add_move(from, from + n, K, true)
            elsif @colors[from + n] == EMPTY && !only_captures
              add_move(from, from + n, K)
              next if @check || n.abs != 1
              if n == -1
                if castling[QSC[@mx]] == 1
                  if @colors[from - 2] == EMPTY && @colors[from - 3] == EMPTY
                    add_move(from, from - 2, K) if king_can_move?(from, from - 1)
                  end
                end
              elsif castling[KSC[@mx]] == 1
                if @colors[from + 2] == EMPTY
                  add_move(from, from + 2, K) if king_can_move?(from, from + 1)
                end
              end
            end
          end
        end
      end

      nil
    end

    # Adds a move object to the move list.
    #   adds respective ordering score and separate index for sorting by score, determines
    #   changes to game related variables that the move causes, so that the data stored in the
    #   move object will reflect the current gamestate once the move has been made
    def add_move(from, to, piece, capture = false)
      idx = @on_mv[@ply - 1]
      c, t, h, e, f = @mv[idx].castling, @squares[to], 0, 0, @mx == BLACK ? @mv[idx].full_moves + 1 : @mv[idx].full_moves

      if capture
        s = (t == EMPTY ? 100000 : ((t + 1) * 100) + 99999 - piece)
        if t == R
          if RQSC[@mn] == to && c[QSC[@mn]] == 1
            c -= REMOVE_QSC[@mn]
          elsif RKSC[@mn] == to && c[KSC[@mn]] == 1
            c -= REMOVE_KSC[@mn]
          end
        end
      else
        s = (@rpt[@root][piece][to] * (@ppt[@ply][piece][to] + @pt[piece][to])) / (@rtn[@root][to] * @ptn[piece][to])
        if piece == @mv[@k1[@ply]].piece && to == @mv[@k1[@ply]].to
          s += 5000
        elsif piece == @mv[@k2[@ply]].piece && to == @mv[@k2[@ply]].to
          s += 3500
        end
        if piece == P
          e = from + DIR[@mx] if (from - to).abs == 20
        else
          h = @mv[idx].half_moves + 1
        end
      end
      if piece == R
        c -= REMOVE_QSC[@mx] if c[QSC[@mx]] == 1 && RQSC[@mx] == from
        c -= REMOVE_KSC[@mx] if c[KSC[@mx]] == 1 && RKSC[@mx] == from
      elsif piece == K
        c -= REMOVE_QSC[@mx] if c[QSC[@mx]] == 1
        c -= REMOVE_KSC[@mx] if c[KSC[@mx]] == 1
      end
      @mv_idx[@mv_n] = @mv_n
      @mv[@mv_n] = Move.new(from, to, piece, t, @mn, c, e, h, f)
      @mv_score[@mv_n] = s
      @mv_n += 1

      nil
    end

    # Moves a piece
    def make_move
      m = @mv[@on_mv[@ply]]
      @squares[m.from], @colors[m.from] = EMPTY, EMPTY
      @squares[m.to], @colors[m.to] = m.piece, @mx
      if m.piece == P
        if (m.to - m.from) % 10 != 0
          if m.target == EMPTY
            @squares[m.to - DIR[@mx]], @colors[m.to - DIR[@mx]] = EMPTY, EMPTY
          end
        elsif m.to > 90 || m.to < 30
          @squares[m.to] = Q
        end
      elsif m.piece == K
        @kings[@mx] = m.to
        if m.to - m.from == 2
          @squares[m.to - 1], @colors[m.to - 1] = R, @mx
          @squares[m.to + 1], @colors[m.to + 1] = EMPTY, EMPTY
        elsif m.from - m.to == 2
          @squares[m.to + 1], @colors[m.to + 1] = R, @mx
          @squares[m.to - 2], @colors[m.to - 2] = EMPTY, EMPTY
        end
      end
      @ply += 1
      if in_check?
        @mx = @mn
        @mn = @mx + 1 & 1
        unmake_move
        return false
      end
      @mx = @mn
      @mn = @mx + 1 & 1

      true
    end

    # Moves a piece back to where it was
    def unmake_move
      @mx = @mn
      @mn = @mx + 1 & 1
      @ply -= 1
      m = @mv[@on_mv[@ply]]
      @squares[m.from], @colors[m.from] = m.piece, @mx
      if m.target != EMPTY
        @squares[m.to], @colors[m.to] = m.target, @mn
      else
        @squares[m.to], @colors[m.to] = EMPTY, EMPTY
      end
      if m.piece == P
        if (m.to - m.from) % 10 != 0
          if m.target == EMPTY
            @squares[m.to - DIR[@mx]], @colors[m.to - DIR[@mx]] = P, @mn
          end
        elsif m.to > 90 || m.to < 30
          @squares[m.to] = P if @squares[m.to] == Q
        end
      elsif m.piece == K
        @kings[@mx] = m.from
        if m.to - m.from == 2
          @squares[m.to - 1], @colors[m.to - 1] = EMPTY, EMPTY
          @squares[m.to + 1], @colors[m.to + 1] = R, @mx
        elsif m.from - m.to == 2
          @squares[m.to + 1], @colors[m.to + 1] = EMPTY, EMPTY
          @squares[m.to - 2], @colors[m.to - 2] = R, @mx
        end
      end

      nil
    end

    # Checks whether a king will be in check in a given position, used for determining if
    #   a player can castle without moving through check
    def king_can_move?(from, to)
      @squares[to], @colors[to] = K, @mx
      @squares[from], @colors[from] = EMPTY, EMPTY
      @kings[@mx] = to
      c = in_check?
      @squares[from], @colors[from] = K, @mx
      @squares[to], @colors[to] = EMPTY, EMPTY
      @kings[@mx] = from

      !c
    end

    # Determines whether the current side king is being attacked or not..
    def in_check?
      k = @kings[@mx]
      8.times do |i|
        if @squares[k + STEP[i]] == N
          return true if @colors[k + STEP[i]] == @mn
        end
        sq = k + OCTL[i]
        sq += OCTL[i] while @colors[sq] == EMPTY
        next unless @colors[sq] == @mn
        case @squares[sq]
        when Q; return true
        when B; return true if i < 4
        when R; return true if i > 3
        when P; return true if k + DIR[@mx] - 1 == sq || k + DIR[@mx] + 1 == sq
        when K; return true if sq - (k + OCTL[i]) == 0
        else next end
      end

      false
    end

  end
end
