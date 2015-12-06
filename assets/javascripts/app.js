/*
 *
 */

var View = function(){
  this.bindEvents();
  this.pvWhiteColors = ["#9e0142", "#c2294a", "#df4d4b", "#f36c43", "#fa9856", "#fdbe6e", "#fee08b", "#fef4ad"];
  this.pvBlackColors = ["#5e4fa2", "#4075b4", "#439bb5", "#66c2a5", "#94d4a4", "#bee5a0", "#e6f598", "#f6fbb2"];
}

View.prototype.bindEvents = function() {
  var view = this;
  $('.ready .square').on('click', function(event) {
    var $sq = $(event.currentTarget);
    if($sq.hasClass('.selected')){
      $sq.removeClass('selected');
      $('.square').removeClass('valid');
    } else if ($sq.hasClass('valid')){
      view.movePiece($sq);
    } else if ($sq.text().length > 0) {
      view.handlePieceClick($sq);
    } else {
      $('.square').removeClass('selected').removeClass('valid')
    }
  });
  $('.new-game').on('click', function(event) {
    $('.board').removeClass('ready').addClass('thinking');
    $.ajax({
      type: 'get',
      url: '/new',
      data: { 'duration': $('#duration').val() },
      success: function(resp) {
        view.updateBoard(JSON.parse(resp));
      }
    });
  });
}

View.prototype.movePiece = function($piece) {
  var boardData = {
    'fen': $('.board').data('fen'),
    'from': $('.selected').data('square'),
    'to':  $piece.data('square'),
    'duration': $('#duration').val()
  };
  var view = this;
  $piece.text($('.selected').text());
  $('.selected').text('');
  $('.square').removeClass('valid').removeClass('selected');
  $('.board').removeClass('ready').addClass('thinking');
  $.ajax({
    type: 'post',
    url: '/move',
    data: boardData,
    success: function(resp) {
      console.log(JSON.parse(resp));
      view.updateBoard(JSON.parse(resp));
    }
  });
}

View.prototype.handlePieceClick = function($piece) {
  var moves = $piece.data('moves');
  $('.square').removeClass('selected').removeClass('valid');
  if(moves && moves.length) {
    $piece.addClass('selected');
    for(var i = 0; i < moves.length; i++) {
      $('.square[data-square="'+moves[i]+'"]').addClass('valid');
    }
  }
}

View.prototype.updateBoard = function(resp) {
  $('.board').data('fen', resp.fen);
  $('#evaluation').text(resp.evaluation);
  $('#nodes').text(resp.nodes);
  $('#eps').text(resp.eps);
  $('#clock').text(resp.clock);
  $('#move').text(resp.move);
  $('#move-score').text(resp.score);
  $('.square').empty().removeData('moves');
  var pieces = resp.pieces;
  var pvWhite = resp.pv.white;
  var pvBlack = resp.pv.black;
  if(resp.status === 'You lost'){
    $('.board').removeClass('thinking').addClass('defeat');
    alert('you lost');
    return;
  } else if (resp.status === 'You win') {
    $('.board').removeClass('thinking').addClass('victory');
    alert('you win');
    return;
  } else {
    $('.board').removeClass('thinking').addClass('ready');
  }
  $('.pv-square').text('');
  for(var i = 0; i < pvWhite.length; i++) {
    var $sq = $('.pv-square[data-pv="' + pvWhite[i].square + '"]');
    $sq.text(pvWhite[i].piece);
    var clr = this.pvWhiteColors[pvWhite[i].ply];
    $sq.css({
      'color': clr,
      'opacity': pvWhite[i].val
    });
  }
  for(var i = 0; i < pvBlack.length; i++) {
    var $sq = $('.pv-square[data-pv="' + pvBlack[i].square + '"]');
    $sq.text(pvBlack[i].piece);
    var clr = this.pvBlackColors[pvBlack[i].ply];
    $sq.css({
      'color': clr,
      'opacity': pvBlack[i].val
    });
  }

  for(var i = 0; i < pieces.length; i++) {
    $('.square[data-square="'+pieces[i].square+'"]')
      .text(pieces[i].piece)
      .data('moves', pieces[i].moves);
  }
  for(var i = 1; i < 8; i++) {
    if(resp.npp[i] > 0){
      $('.bar[data-ply="'+i+'"]')
        .css('height', Math.round(resp.npp[i] / resp.nodes * 100)+'%')
        .find('span').text(resp.npp[i]);
    } else {
      $('.bar[data-ply="'+i+'"]').css('height', 0)
        .find('span').text('');
    }
  }
  $('.square[data-square="'+resp.from+'"]').toggleClass('move-from');
  $('.square[data-square="'+resp.to+'"]').toggleClass('move-to');
  window.setTimeout(this.toggleMovement.bind(this), 1000);
}

View.prototype.toggleMovement = function() {
  $('.square').removeClass('move-from').removeClass('move-to');
}
