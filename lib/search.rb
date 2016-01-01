module Chstr
  # Performs a move search and interfaces its functionalities to relay clientside
  class Search
    attr_accessor :fen, :history

    def initialize(fen = FEN_START)
      @fen = fen
      @history = []
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

  end
end
