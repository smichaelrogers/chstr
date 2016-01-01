module Chstr
  class Search

    # Creates a move object with the current irreversible game data (castling, move clock, ep square)
    #   extracted from the current FEN position to serve as the "on move" for ply 0/the stump that
    #   all roots stem from.  The irreversible data is typically retrieved from the current
    #   move of the previous ply, which means for the 0 ply stump move, an incomplete surrogate move
    #   must be made to accomidate the API which only handles single positions
    def make_gamestate
      @ply, @mv_n, @root = 0, 0, 0
      @mv, @mv_score = Array.new(MV_CAPACITY) { nil }, Array.new(MV_CAPACITY) { 0 }
      @mv_idx, @on_mv = Array.new(MV_CAPACITY) { 0 }, Array.new(MAXPLY) { 0 }
      n, c = @fen.split, 0
      @mx = n[1] == 'w' ? WHITE : BLACK
      @mn = @mx + 1 & 1

      CASTLING.each { |letter, num| c += num if n[2].include?(letter) }
      @mv[0] = Move.new(nil, nil, nil, nil, @mx, c, SQ_ID.index(n[3]), n[4].to_i, n[5].to_i)
      @on_mv[0], @mv_idx[0] = 0, 0

      nil
    end

    # Constructs two arrays to represent the pieces in the positions designated by the current
    #   FEN position.  Two single dimension 120 length arrays are used to represent the board
    #   The additional squares are used as padding to avoid the costly amount of
    #   conditional statements involved in moving a knight
    def make_board
      @colors, @squares = Array.new(120) { 6 }, Array.new(120) { 6 }
      @kings, piece_count = [nil, nil], 0
      120.times do |i|
        if i < 21 || i % 10 == 0 || i % 10 == 9 || i > 98
          @colors[i], @squares[i] = -1, -1
        end
      end
      @fen.split.first.split('/').map do |row|
          row.chars.map { |sq| sq.between?('1', '8') ? sq.to_i.times.map { '6' } : sq }
      end.flatten.each_with_index do |sq, i|
        color, piece = FEN[sq][0], FEN[sq][1]
        @colors[SQ[i]], @squares[SQ[i]] = color, piece
        piece_count += 1 if piece != EMPTY
        @kings[color] = SQ[i] if piece == K
      end
      @stage = piece_count < 16 ? LATE : MID

      nil
    end

    # Creates data used from the stump of the move tree, flags illegal moves
    def make_root
      @ply, @mv_n, @root = 1, 1, 1
      generate_moves(false)
      @root_n = @mv_n
      @mv_fen, @mv_san, @mv_type = Array.new(@root_n) { '' }, Array.new(@root_n) { '' }, Array.new(@root_n) { '' }
      @mv_legal = Array.new(@root_n) { true }
      fen_history = @history.first(6).map { |m| m.split.first }
      1.upto(@root_n - 1) do |i|
        @root, @on_mv[1] = @mv_idx[i], @mv_idx[i]
        if make_move
          @mv_fen[@root], @mv_san[@root] = make_fen(@root), make_san(@mv[@root])
          @mv_type[@root] = make_type(@mv_san[@root])
          unmake_move
          @mv_legal[@root] = false if fen_history.count(@mv_fen[@root].split.first) > 1 || @mv[@root].half_moves > 50
        else
          @mv_legal[@root] = false
        end
      end

      nil
    end

    # Organizes the data collected during the search for rendering in the browser
    def render
      total_pv, total_nw, total_qs = @npp_pv.inject(:+), @npp_nw.inject(:+), @npp_qs.inject(:+)
      total_nodes = total_pv + total_nw + total_qs
      {
        fen: @fen,
        nps: (total_nodes.to_f / @clock).round(2),
        clock: "#{@clock.round(2)} / #{@duration}",
        move: @best_move,
        pv_count: total_pv,
        nw_count: total_nw,
        qs_count: total_qs,
        node_count: total_nodes,
        board: SQ.map { |sq| @squares[sq] == EMPTY ? "" : UTF8[@colors[sq]][@squares[sq]] },
        moves: (1...@root_n).to_a.select { |i| @mv_legal[@mv_idx[i]] }.map { |i| @mv_idx[i] }
        .map { |idx| { piece: UTF8[@colors[@mv[idx].from]][@squares[@mv[idx].from]],
                       from: SQ64[@mv[idx].from],
                       to: SQ64[@mv[idx].to],
                       type: @mv_type[idx],
                       san: @mv_san[idx],
                       fen: @mv_fen[idx] } }.sort_by { |m| m[:from] },
        pv_board: @pv_chart.map { |sq| (sq[:piece] != '' && sq[:depth] > 0) ?
          { piece: sq[:piece], class: "p#{sq[:ply]} d#{sq[:depth]}"} : { piece: "", class: "" } },
        pv_list: @pv_list.reverse.select { |m| m[:depth] > 0 }.map { |m|
          { moves: m[:moves], class: "d#{m[:depth]}", depth: m[:depth] } },
        evaluation: [
          { field: "Material", white: @w_material, black: @b_material },
          { field: "Mobility", white: @w_mobility, black: @b_mobility },
          { field: "Position", white: @w_position, black: @b_position },
          { field: "Control", white: @w_control, black: @b_control },
          { field: "Structure", white: @w_pawns, black: @b_pawns },
          { field: "Threat", white: @w_threat, black: @b_threat },
          { field: "Total", white: @w_total, black: @b_total }],
        npp: [
          ['pv', @npp_pv[2, 12]].flatten,
          ['nw', @npp_nw[2, 12]].flatten,
          ['qs', @npp_qs[2, 12]].flatten]
      }
    end

    # Generates a representation of a move object in standard algebraic notation
    def make_san(m)
      d = (m.from - m.to).abs
      if m.piece == P
        san =
          if d % 10 == 0
            "#{SQ_ID[m.to]}"
          elsif m.target == EMPTY
            "#{SQ_ID[m.from][0]}x#{SQ_ID[m.to + DIR[m.mx]]}e.p."
          else
            "#{SQ_ID[m.from][0]}x#{SQ_ID[m.to]}"
          end
        san += "=Q" if m.to > 90 || m.to < 30
        return san
      end
      return (m.to % 10 == 3) ? "O-O-O" : "O-O" if m.piece == K && d == 2
      return "#{SAN[m.piece]}x#{SQ_ID[m.to]}" unless m.target == EMPTY

      "#{SAN[m.piece]}#{SQ_ID[m.to]}"
    end

    # Determines the move type of a SAN string
    def make_type(san)
      type = san.include?('x') ? "Capture" : (san.include?("O-O") ? "Castle" : "Quiet")
      type += " e.p." if san.include?('e.p.')
      type += " promotion" if san.include?('=Q')

      type
    end

    # Generates a FEN string representation of the current gamestate
    def make_fen(idx)
      m, rows, c = @mv[idx], [], ''
      8.times do |i|
        row, empty = [], 0
        8.times do |j|
          sq = SQ[(i * 8) + j]
          if @squares[sq] == EMPTY
            empty += 1
            next
          end
          row << empty.to_s if empty > 0
          row << TO_FEN[@colors[sq]][@squares[sq]]
          empty = 0
        end
        row << empty.to_s if empty > 0
        rows << row.join
      end
      'KQkq'.chars.each_with_index { |l, i| c += l if m.castling[3 - i] == 1 }
      [rows.join("/"), ['w','b'][m.mx], c == '' ? '-' : c, SQ_ID[m.ep], m.half_moves, m.full_moves].join(" ")
    end


  end
end
