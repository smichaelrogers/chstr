var App = function($board, $report, $pv, $npp) {
  this.$board = $board;
  this.$report = $report;
  this.$pv = $pv;
  this.$npp = $npp;

  this.bindEvents();

  var view = this;
  $.ajax({
    type: 'get',
    url: '/new',
    dataType: 'json',
    data: {
      'duration': $('#strength').val()
    },
    success: function(resp) {
      console.log(JSON.parse(resp));
      view.updateBoard(JSON.parse(resp));
    }
  });
};

App.prototype.bindEvents = function() {
  var view = this;

  this.$board.click('td', function(event) {
    var $square = $(event.currentTarget);
    if ($square.hasClass('valid')) {
      var fromPos = $('.selected').data('id');
      var toPos = $square.data('id');
      $('td').empty().removeClass('selected');
      $square.text(piece);
      $.ajax({
        type: 'post',
        url: '/move',
        dataType: 'json',
        data: {
          'fen': $('#fen').val(),
          'from': fromPos,
          'to': toPos,
          'duration': $('#strength').val()
        },
        success: function(resp) {
          view.updateBoard(JSON.parse(resp));
        }
      });
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
};

App.prototype.updateBoard = function(resp) {
  $('#fen').val(resp.fen);
  $('#report').empty();
  $('td.board-sq').empty();
  $('td.pv-sq').empty();
  $('td.npp-sq').empty();
  var pieces = resp.pieces;
  for (var key in resp.report) {
    $('#report').append(
      '<div class="report-item"><span class="report-key">' + key +
      '</span><span class="report-value">' + resp.report[key] +
      '</span></div>'
    );
  }
  for (var key in resp.pv) {
    $('td.pv-sq[data-pv-id="' + key + '"]').css('background-color', resp.pv[key]);
  }
  for (var i = 0; i < pieces.length; i++) {
    var $sq = $('td[data-id="' + pieces[i].square + '"]');
    $sq.text(pieces[i].piece);
    $sq.data('moves', pieces[i].moves);
  }
  for (var i = 0; i < 16; i++) {
    $('td.npp-sq[data-ply="' + i + '"]').html('<span class="bar" style="height: ' + Math.round((resp.npp[i] / resp.nodes) * 100) + '%;">' + resp.npp[i] + '</span>');
  }

  $('td.board-sq[data-id="' + resp.from + '"]').toggleClass('flash-movement-from');
  $('td.board-sq[data-id="' + resp.to + '"]').toggleClass('flash-movement-to');

  adjustSizes();
  window.setInterval(toggleMovement, 1000);
};

toggleMovement = function() {
  $('td.board-sq').removeClass('flash-movement-from').removeClass('flash-movement-to');
};

adjustSizes = function() {
  var w = $('#board').width() / 8;
  $('td.board-sq').width(w).height(w).css('font-size', w * 0.6);
  var pvw = $("#pv").width() / 8;
  $('td.pv-sq').width(pvw).height(pvw).css('font-size', pvw * 0.6);
};
