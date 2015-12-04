$(function() {
  resetBoard();
  $(window).resize(function() {
    adjustSquares();
  });

  $('td').click(function() {
    if ($(this).hasClass('valid')) {
      var piece = $('.selected').text();
      var fromPos = $(".selected").data('id');
      var toPos = $(this).data('id');
      $(".selected").empty().removeClass('selected');
      $(this).text(piece);
      $.ajax({
        type: 'post',
        url: '/show',
        dataType: 'json',
        data: {
          'fen': $("#fen").text(),
          'from': fromPos,
          'to': toPos
        },
        success: function(resp) {
          $("td").empty().removeClass('selected').removeClass('valid');
          updateBoard(JSON.parse(resp));
        }
      });
    } else {
      var moves = $(this).data('moves');
      console.log($(this));
      $('td').removeClass('selected').removeClass('valid');
      if (moves && moves.length) {
        $(this).addClass('selected');
        for (var i = 0; i < moves.length; i++) {
          $('td[data-id="' + moves[i] + '"]').addClass('valid');
        }
      }
    }
  });
});
