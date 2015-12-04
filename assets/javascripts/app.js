var App = function($board, $report, $gfx) {
  this.$board = $board;
  this.$report = $report;
  this.$gfx = $gfx;

  this.bindEvents();

  var view = this;
  $.ajax({
    type: 'get',
    url: './new',
    dataType: 'json',
    success: function(resp) {
      console.log(JSON.parse(resp));
      view.updateBoard(JSON.parse(resp));
    }
  });
}

App.prototype.bindEvents = function() {
  var view = this;

  this.$board.click("td", function(event) {
    var $square = $(event.currentTarget);
    if ($square.hasClass('valid')) {
      var fromPos = $(".selected").data('id');
      var toPos = $square.data('id');
      $("td").empty().removeClass('selected');
      $square.text(piece);
      $.ajax({
        type: 'post',
        url: '/move',
        dataType: 'json',
        data: {
          'fen': $("#fen").text(),
          'from': fromPos,
          'to': toPos
        },
        success: function(resp) {
          view.updateBoard(JSON.parse(resp));
        }
      })
    } else {
      var moves = $square.data('moves');
      $('td').removeClass('selected');
      $('td').removeClass('valid');
      if (moves && moves.length) {
        $square.addClass('selected');
        for (var i = 0; i < moves.length; i++) {
          $('td[data-id="' + moves[i] + '"]').addClass('valid');
        }
      }
    }
  });
}

App.prototype.updateBoard = function(resp) {
  $("td").empty();
  $("#fen").text(resp.fen);
  $("#report").empty();
  var pieces = resp.pieces;
  for (var key in resp.report) {
    $("#report").append('<div class="report-item"><span class="report-key">' + key +
      '</span><span class="report-value">' + resp.report[key] + '</span></div>');
  }
  for (var i = 0; i < pieces.length; i++) {
    var $sq = $('td[data-id="' + pieces[i].square + '"]');
    $sq.text(pieces[i].piece);
    $sq.data('moves', pieces[i].moves);
  }
}
