# All of the make and unmake operations involved in search deepening.  Because of all of the
# instance variables already chewing on memory, only moves at the root are considered
# for castling and en passant captures, to allow these moves beyond the root, all of the
# irreversible gamestates would have to be stored in memory (50 move rule, castling, ep square,
# etc.) or tested for extensively
class Chstr
  # Selects root moves to send to the browser for the valid move square highlighting effect
  def valid_root_moves
    valid = []

    generate_root_moves.each do |move|
      from, to, piece, target, type, rating = move
      if attempt_move(from, to, piece, target)
        valid << move

        descend!
        # deal with uncastling/ep/king position
        root_unmake(from, to, piece, target, type)
      end
    end

    valid
  end

  # Attempts to make a move from at the root of the search tree (ply 0).  At this point all moves
  # are pseudolegal (see 'generate_root_moves' / 'generate_root_evasions'), no castling moves
  # are generated if already in check.
  def root_make(from, to, piece, target, type)
    return false unless attempt_move(from, to, piece, target)

    if piece == KING
      # we already know that the rook is there since the move was generated and @castling includes
      # the rook's square
      if type == CASTLE

        # queen side castle
        # R _ x _ K _ _ _ ->  _ _ K R _ _ _ _
        # a b c d e f g h     a b c d e f g h
        if to + 2 == from
          # try the middle square
          @squares[to + 1], @colors[to + 1] = KING, @wtm
          @squares[to], @colors[to] = EMPTY, EMPTY
          # can't move through check
          if in_check?
            @squares[from], @colors[from] = KING, @wtm
            @squares[to + 1], @colors[to + 1] = EMPTY, EMPTY
            # put the king back
            @kings[@wtm] = from

            return false
          end
          # move the rook
          @squares[to], @colors[to] = KING, @wtm
          @squares[to - 2], @colors[to - 2] = EMPTY, EMPTY
          @squares[to + 1], @colors[to + 1] = ROOK, @wtm

        # king side castle
        # _ _ _ K _ x _ R ->  _ _ _ _ _ R K _
        # a b c d e f g h     a b c d e f g h
        elsif to - 2 == from

          @squares[to - 1], @colors[to - 1] = KING, @wtm
          @squares[to], @colors[to] = EMPTY, EMPTY

          if in_check?
            @squares[from], @colors[from] = KING, @wtm
            @squares[to - 1], @colors[to - 1] = EMPTY, EMPTY

            @kings[@wtm] = from

            return false
          end

          @squares[to], @colors[to] = KING, @wtm
          @squares[to + 1], @colors[to + 1] = EMPTY, EMPTY
          @squares[to - 1], @colors[to - 1] = ROOK, @wtm
        end
      end

    elsif piece == PAWN
      # already know that we can make an en passant capture since @ep == the target square
      # so the 'to' square and one step back is where the pawn is
      if type == EP_CAPTURE
        @squares[to - FORWARD[@wtm]], @colors[to - FORWARD[@wtm]] = EMPTY, EMPTY
      elsif to > 90 || to < 30
        # only allows queen promotions
        @squares[to] = QUEEN
        piece = QUEEN
      end
    end

    descend!

    true
  end

  # Responsible for handling the reversal of irreversible moves, essentially 'root_make', backwards
  def root_unmake(from, to, piece, target, type)

    ascend!

    if piece == KING
      @kings[@wtm] = from
      if type == CASTLE
        if to + 2 == from
          @squares[to - 2], @colors[to - 2] = ROOK, @wtm
          @squares[to + 1], @colors[to + 1] = EMPTY, EMPTY

        elsif to - 2 == from
          @squares[to + 1], @colors[to + 1] = ROOK, @wtm
          @squares[to - 1], @colors[to - 1] = EMPTY, EMPTY
        end
      end

    elsif piece == PAWN
      if type == EP_CAPTURE
        @squares[to - FORWARD[@wtm]], @colors[to - FORWARD[@wtm]] = PAWN, @ntm
      elsif @squares[to] == QUEEN
        # if the 'piece' variable says pawn but what's on the board is a queen, it can be assumed
        # that it should be demoted
        @squares[to] = PAWN
      end
    end

    @squares[from], @colors[from] = piece, @wtm
    @squares[to] = target

    @colors[to] = target == EMPTY ? EMPTY : @ntm
  end


  # Performs a sub-root move, 'attempt_move' handles most of it
  def make(from, to, piece, target)
    return false unless attempt_move(from, to, piece, target)

    descend!

    true
  end

  # Reverse a reversible sub-root move
  def unmake(from, to, piece, target)
    ascend!

    @kings[@wtm] = from if piece == KING

    @squares[from], @colors[from] = piece, @wtm
    @squares[to] = target

    @colors[to] = target == EMPTY ? EMPTY : @ntm
  end

  # Performs a move, determining if the side to move will be in check after doing so
  def attempt_move(from, to, piece, target)
    @squares[to], @colors[to] = piece, @wtm
    @squares[from], @colors[from] = EMPTY, EMPTY

    @kings[@wtm] = to if piece == KING

    if in_check?
      @squares[from], @colors[from] = piece, @wtm
      @squares[to] = target
      @colors[to] = target == EMPTY ? EMPTY : @ntm

      @kings[@wtm] = from if piece == KING

      return false
    end

    true
  end

  # Adjusts variables one (half) move closer to the root of the search tree (0 ply)
  def ascend!
    @ply -= 1
    @ntm = @wtm
    @wtm = @wtm + 1 & 1
  end

  # Adjusts variables one (half) move deeper, further from the root
  def descend!
    @ply += 1
    @ntm = @wtm
    @wtm = @wtm + 1 & 1
  end

end
