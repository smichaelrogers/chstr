class Search
  attr_accessor :fen, :history

  def initialize(fen = FEN_START)
    @fen = fen
    @history = []
  end


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
    moves = Array.new(64) { [] }
    1.upto(@root_n - 1) do |i|
      idx = @mv_idx[i]
      next unless @mv_legal[idx]
      m = @mv[idx]
      moves[SQ64[m.from]] << { to: SQ64[m.to], san: @mv_san[idx], fen: @mv_fen[idx], type: @mv_type[idx] }
    end
    board =
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
      moves: moves,
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

  # Progressive deepening from the root of the move tree, stores the best variations from
  #   each root move to accelerate deepening on the next progression
  def start(duration = 4)
    make_tables
    make_gamestate
    make_board
    make_root

    @duration = duration
    clock_start = Time.now
    clock_stop = clock_start + @duration
    alpha_idx = 0

    MAXPLY.times do |depth|
      @best_idx = alpha_idx
      alpha, alpha_idx = -INF, 0
      sort_moves(1, @root_n - 1)

      1.upto(@root_n - 1) do |i|
        next unless @mv_legal[@mv_idx[i]]
        @root = @mv_idx[i]
        @on_mv[1] = @root

        next unless make_move
        @pv[@root][1] = @mv[@root].dup if depth == 0
        @pv_ply[@root], @mv_ply, @on_pv, @mv_n = 1, 1, true, @root_n
        @k1.fill(0)
        @k2.fill(0)
        if depth == 0 || i == 1
          @npp_pv[@ply] += 1
          score = -search(-INF, -alpha, depth)
        else
          @npp_nw[@ply] += 1
          score = -search(-alpha-1, -alpha, depth)
          if score > alpha
            @npp_pv[@ply] += 1
            score = -search(-INF, -alpha, depth)
          end
        end
        unmake_move

        @mv_score[@root] = score
        if score > alpha
          alpha, alpha_idx = score, @root
        end

        break if Time.now > clock_stop
      end

      break if Time.now > clock_stop
      next if alpha_idx == 0 || depth == 0

      pvl = []
      1.upto([@pv_ply[alpha_idx], 5].min) do |j|
        if @pv[alpha_idx][j] && @pv[alpha_idx][j].from
          m = @pv[alpha_idx][j]
          @pv_chart[SQ64[m.to]] = { piece: UTF8[m.mx + 1 & 1][m.piece], depth: depth, ply: j}
          pvl << make_san(m)
        else
          break
        end
      end
      @pv_list << { depth: depth, moves: pvl.join(", ") } unless pvl.empty?
    end

    @clock = Time.now - clock_start
    @root, @fen = @best_idx, @mv_fen[@best_idx]
    @san, type = @mv_san[@root], @mv_type[@root]

    piece, from = UTF8[@mx][@mv[@root].piece], SQ_ID[@mv[@root].from]
    to, target = SQ_ID[@mv[@root].to], ""
    target = " #{UTF8[@mn][P]}" if @san.include?('e.p.')
    target = " #{UTF8[@mn][@mv[@root].target]}" unless @mv[@root].target == EMPTY

    @best_move = { notation: @san, type: type, move: "#{piece}#{from} → #{to}#{target}",
                   score: @mv_score[@root], fen: @fen }
    @ply, @on_mv[0], @mv[0] = 0, 0, @mv[@root].dup

    make_move
    make_root
    evaluate
    nil
  end

  # Performs a depth first variation search beyond the root of the move tree
  def search(alpha, beta, depth)
    quiesce = false
    if depth <= 0
      score = evaluate
      return beta if score >= beta
      alpha = score if score > alpha
      return alpha if @ply >= MAXPLY - 1 || score < alpha - 900 || depth < -3
      @npp_qs[@ply] += 1
      quiesce = true
    end

    moved, i = false, @mv_n
    generate_moves(quiesce)
    c, n = @check, @mv_n - 1
    return -INF if n < i && c

    assert_pv(i, n) if @on_pv
    sort_moves(i, n)
    @mv_ply = @ply

    i.upto(n) do |j|
      idx = @mv_idx[j]
      @on_mv[@ply] = idx
      next unless make_move
      moved = true

      if j == i
        @npp_pv[@ply] += 1
        score = -search(-beta, -alpha, depth - 1)
      else
        @npp_nw[@ply] += 1
        score = -search(-alpha-1, -alpha, depth - 1)
        if score > alpha && score < beta && depth > 1
          @npp_pv[@ply] += 1
          score = -search(-beta, -alpha, depth - 1)
        end
      end
      unmake_move

      if score > alpha
        if @mv[idx].target == EMPTY
          @rpt[@root][@mv[idx].piece][@mv[idx].to] += depth
          @ppt[@ply][@mv[idx].piece][@mv[idx].to] += depth
          @pt[@mv[idx].piece][@mv[idx].to] += 1
        end

        if score >= beta
          if @mv[idx].target == EMPTY
            @k2[@ply] = @k1[@ply]
            @k1[@ply] = idx
          end

          return beta
        end
        alpha = score
        @pv[@root][@ply] = @mv[idx].dup
        (@ply + 1).upto(@mv_ply) { |k| @pv[@root][k] = @mv[@on_mv[k]].dup }
        @pv_ply[@root] = @mv_ply

      elsif @mv[idx].target == EMPTY
        @rtn[@root][@mv[idx].to] += depth
        @ptn[@mv[idx].piece][@mv[idx].to] += 1
      end
    end

    moved ? alpha : -INF
  end

  # Sorts moves by their assigned ordering scores
  def sort_moves(i, n)
    i.upto(n - 1) do |j|
      best = j
      (j + 1).upto(n) { |k| best = k if @mv_score[@mv_idx[k]] > @mv_score[@mv_idx[best]] }
      unless best == j
        l = @mv_idx[j]
        @mv_idx[j] = @mv_idx[best]
        @mv_idx[best] = l
      end
    end

    nil
  end

  # Checks if the current branch is the root node's best variation,
  #   if it is the next move will go first
  def assert_pv(i, n)
    @on_pv = false
    return nil if @pv[@root][@ply].nil?
    i.upto(n) do |j|
      if @mv[@mv_idx[j]] == @pv[@root][@ply]
        @mv_score[@mv_idx[j]] += 99999999
        @on_pv = true
        return nil
      end
    end

    nil
  end

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

  # Makes some arrays
  def make_tables
    # Counters
    @npp_pv = Array.new(MAXPLY) { 0 }
    @npp_nw = Array.new(MAXPLY) { 0 }
    @npp_rw = Array.new(MAXPLY) { 0 }
    @npp_qs = Array.new(MAXPLY) { 0 }
    # Move recognition
    @rpt = Array.new(128) { Array.new(6) { Array.new(120) { 0 } } }
    @ppt = Array.new(MAXPLY) { Array.new(6) { Array.new(120) { 0 } } }
    @pt = Array.new(6) { Array.new(120) { 0 } }
    @ptn = Array.new(6) { Array.new(120) { 1 } }
    @rtn = Array.new(128) { Array.new(120) { 1 } }
    @k1 = Array.new(MAXPLY) { 0 }
    @k2 = Array.new(MAXPLY) { 0 }
    # Variations
    @pv = Array.new(128) { Array.new(MAXPLY) { nil } }
    @pv_ply = Array.new(128) { 0 }
    @pv_chart = Array.new(64) { { piece: '', ply: 0, depth: 0 } }
    @pv_list = []
    # Evaluation
    @w_material, @w_mobility, @w_position, @w_control, @w_pawns, @w_threat, @w_total = 0, 0, 0, 0, 0, 0, 0
    @b_material, @b_mobility, @b_position, @b_control, @b_pawns, @b_threat, @b_total = 0, 0, 0, 0, 0, 0, 0
    @evaluation = 0

    nil
  end


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
