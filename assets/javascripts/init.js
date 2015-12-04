$(function() {
  $("#new-game").click(function() {
    newGame();
    $(window).resize(function() {
      adjustSizes();
    });
  });
});


newGame = function() {
  var files = ["a", "b", "c", "d", "e", "f", "g", "h"];
  var ranks = ["8", "7", "6", "5", "4", "3", "2", "1"];
  var clr = 'white';
  var $report = $("#report");
  var $pv = $("#pv");
  var $npp = $("#npp");
  var $board = $("#board");
  $report.empty();
  $pv.empty();
  $npp.empty();
  $board.empty();
  var pvRow = "";
  var boardRow = "";
  for (var i = 0; i < 8; i++) {
    for (var j = 0; j < 8; j++) {
      boardRow += '<td class="board-sq ' + clr + '" data-id="' + files[j] + ranks[i] + '"></td>';
      pvRow += '<td class="pv-sq ' + clr + '" data-pv-id="' + files[j] + ranks[i] + '"></td>';
      clr = (clr === 'white' ? 'black' : 'white');
    }
    clr = (clr === 'white' ? 'black' : 'white');
    $board.append('<tr>' + boardRow + '</tr>');
    $pv.append('<tr>' + pvRow + '</tr>');
    boardRow = "";
    pvRow = "";
  }
  $npp.html('<thead></thead><tbody></tbody>');
  for (var i = 0; i < 16; i++) {
    $("#npp > thead").append('<th>' + (i + 1).toString() + '</th>');
    $("#npp > tbody").append('<td class="npp-sq" data-ply="' + i + '"></td>');
  }
  new App($board, $report, $pv, $npp);
}
