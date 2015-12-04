# Contains all of the search algorithms and data structures involved with the move search
# Methods are clearly somehwat lengthy for Ruby but this seems to be the most performant.
class Chstr
  # Begins iterative deepening, uses a saved opening if possible.  Adjusts the search window
  # while deepening to ideally search less unnecessary nodes.  Generates tables for the
  # different heuristics involved in move ordering and move generation.  Stores report data for
  # relay to the browser.
  def init_search(duration = 4)
    @duration = duration
    @clock = 0.0
    init_tables
    start_time = Time.now

    alpha, beta = -INF, INF
    @best_score, @best_move = -INF, nil
    moves = in_check? ? generate_root_evasions : generate_root_moves

    initial = true

    # don't go beyond MAXPLY, since it determines the array sizes
    while @hrzn + 1 <= MAXPLY
      i = 0
      while i < moves.length
        from, to, piece, target, type, rating = moves[i]
        if !root_make(from, to, piece, target, type)
          # get rid of moves that give self check
          moves.delete_at(i)
          next
        end

        if i == 0 && !initial
          @pv[@ply] << SQ_ID[to]
          # search full depth for the principal variation (current best path from the root)
          score = -search(-beta, -alpha, @hrzn, true)
        else
          # null window search
          score = -search(-alpha - 1, -alpha, @hrzn, false)
          if score > @best_score
            @pv[@ply] << SQ_ID[to]
            # found a new principal variation, search it fully
            score = -search(-beta, -alpha, @hrzn, true)
          end
        end

        if initial && @full_moves < 10
          # check for a book position on first round, randomize for less repetitive behavior
          fen = to_fen.split.first.gsub("/", '')
          if @@book.include?(fen)
            score += INF + rand(32)
          end
        end

        root_unmake(from, to, piece, target, type)
        # use the score in the next iteration for ordering
        moves[i][5] = score
        if score > alpha
          alpha = score
          if score > @best_score
            @best_score = score
            @best_move = [from, to, piece, target, type, score]
          end
          # adjust faulty windows
          if score >= beta
            beta = INF
          elsif score <= alpha
            alpha = -INF
          end
        end

        i += 1
        break if start_time + @duration < Time.now
      end

      moves = moves.sort_by{|m| -m[5] }
      initial = false
      # adjust windows
      if @best_score > -INF
        alpha = @best_score - 64
        beta = @best_score + 64
        @hrzn += 1
      end
      # break if out of time or a book move is found
      break if start_time + @duration < Time.now || @best_score > INF
    end

    @clock = (Time.now - start_time).round(2)

    # no move available means checkmate
    return unless @best_move

    # adjust irreversibles
    from, to, piece, target, type, score = @best_move
    @ep = nil
    @full_moves += 1
    if type == PAWN_DOUBLE_PUSH
      @ep = from + FORWARD[@wtm]
    elsif piece == ROOK
      @castling.delete(from)
    elsif piece == KING
      @castling.delete(QSC[@wtm])
      @castling.delete(KSC[@wtm])
    end

    @fifty = type > 1 ? 0 : @fifty + 1
    root_make(from, to, piece, target, type)
  end

  # Performs a Principal Variation (NegaScout) search, a directional minimax recursive algorithm
  # and extension to Alpha Beta that facilitates pruning with effective move ordering and null
  # window searches (see https://en.wikipedia.org/wiki/Principal_variation_search)
  def search(alpha, beta, depth, pv_node)
    # reach target depth
    return quiesce(alpha, beta) if depth < 1
    # cache move list
    @mv[@ply] = generate_moves
    i = 0
    while @mv[@ply].length > 0
      from, to, piece, target = @mv[@ply].pop
      # check if move puts self in check
      next unless make(from, to, piece, target)
      i += 1

      if pv_node && i == 1
        @pv[@ply] << SQ_ID[to]
        # on principal variation, search full window
        score = -search(-beta, -alpha, depth - 1, true)
      else
        # null window, scale depth down for moves that seem pointless
        score = -search(-(alpha + 1), -alpha, depth - (1 + (i / 4)), false)
        if score > alpha && score < beta
          if pv_node
            @pv[@ply] << SQ_ID[to]
            # still on principal variation just not the move we expected
            score = -search(-beta, -alpha, depth - 1, true)
          else
            # found something but still not the principal variation as that must come all of the way
            # from the root, but search a full window as it is interesting
            score = -search(-beta, -score, depth - 1, false)
          end
        end
      end

      unmake(from, to, piece, target)

      if score > alpha
        @ht[piece][to] += @hrzn
        return beta if score >= beta

        alpha = score
        @kt[@ply][piece][to] += 2**@hrzn
        if pv_node
          @kt[@ply][piece][to] += @hrzn**@hrzn
        end
      else
        @bt[piece][to] += @hrzn
      end
    end

    alpha
  end

  # Performs a quiescence search, used to evaluate beyond the 'horizon' to avoid misleading
  # evaluations (see: https://en.wikipedia.org/wiki/Quiescence_search)
  def quiesce(alpha, beta)
    score = evaluate
    # too good
    return beta if score >= beta
    # just right
    alpha = score if score > alpha
    # too deep
    return alpha if @ply >= MAXPLY - 1

    @mv[@ply] = generate_captures
    while @mv[@ply].length > 0
      from, to, piece, target = @mv[@ply].pop
      # ignore moves that are very unlikely to raise alpha
      next if MATERIAL[target] + 128 < alpha
      next unless make(from, to, piece, target)

      score = -quiesce(-beta, -alpha)

      unmake(from, to, piece, target)

      if score > alpha
        @ht[piece][to] += @hrzn

        return beta if score >= beta

        alpha = score
        @kt[@ply][piece][to] += 2**@hrzn
      else
        @bt[piece][to] += @hrzn
      end
    end

    alpha
  end

  def init_tables
    # all cutoffs
    @ht = Array.new(6){ Array.new(120){ 1 }}
    # all non cutoffs
    @bt = Array.new(6){ Array.new(120){ 1 }}
    # all cutoffs @ ply
    @kt = Array.new(MAXPLY){ Array.new(6){ Array.new(120){ 1 }}}
    # move cache
    @mv = Array.new(MAXPLY){ [] }
    # progress
    @stage = SQ.count{ |i| @squares[i] != EMPTY } < 16 ? LATE_GAME : MID_GAME
    # horizon depth / search depth to perform quiescence search
    @hrzn = 1
    # node counter
    @nodes = 0
    # nodes per ply
    @npp = Array.new(MAXPLY){ 0 }
    # current ply
    @ply = 0
    # greatest ply searched
    @max_depth = 0
    # move the computer has chosen, for browser
    @best_move = nil
    @best_score = -INF
    @duration = 4
    @clock = 0
    @pv = Array.new(MAXPLY){ [] }
  end

end
