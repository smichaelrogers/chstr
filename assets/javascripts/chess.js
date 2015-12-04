var FILES = ["a", "b", "c", "d", "e", "f", "g", "h"];
var RANKS = ["8", "7", "6", "5", "4", "3", "2", "1"];
var PLIES = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '10', '11', '12', '13', '14', '15', '16'];
var WHITE = 0;
var BLACK = 1;

adjustSquares = function() {
  var w = $("#board").width() / 8;
  $("td").width(w);
  $("td").height(w);
  $("td").css('font-size', w * 0.6);
}

showNodeDistribution = function(data) {
  new Chartist.Line('.ct-chart', {
    labels: PLIES,
    series: data
  }, {
    fullWidth: true,
    chartPadding: {
      right: 40
    }
  });
}


init = function() {
  resetBoard();
  $.ajax({
    type: 'get',
    url: '/show',
    success: function(resp) {
      console.log(resp);
      debugger
      updateBoard(JSON.parse(resp));
    }
  });
}

resetBoard = function() {
  var clr = 'white';
  var str = "";
  for (var i = 0; i < 8; i++) {
    str += "<tr>";
    for (var j = 0; j < 8; j++) {
      str += '<td class=\"' + clr + '\" data-id=\"' + FILES[j] + RANKS[i] + '\"></td>';
      if (clr === 'white') {
        clr = 'black';
      } else {
        clr = 'white';
      }
    }
    if (clr === 'white') {
      clr = 'black';
    } else {
      clr = 'white';
    }
    str += "</tr>";
  }
  $("#board").html(str);
  adjustSquares();
}

updateBoard = function(resp) {
  console.log(resp);
  var pieces = resp.pieces;
  var report = resp.report;
  var npp = resp.npp;
  var nppp = resp.npp_percent;
  $("#npp").html("");
  for (var i = 0; i < 16; i++) {
    var prcnt = nppp[i];
    $("#npp").append('<span><strong>' + i + '</strong> ' + Math.round(prcnt) + '%  ' + npp[i] +
      '</span>');
  }

  $("#fen").html(resp.fen);
  $("#report").html("");
  for (var key in resp.report) {
    var val = resp.report[key];
    $("#report").append('<div class="card"><h5>' + val.toString() + '</h5><span>' + key.toString() + '</span></div>');
  }

  for (var i = 0; i < pieces.length; i++) {
    var $sq = $('td[data-id="' + pieces[i].square + '"]');
    $sq.text(pieces[i].piece);
    $sq.data('moves', pieces[i].moves);
  }
  adjustSquares();
}
