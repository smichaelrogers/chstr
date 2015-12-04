$(function() {
  $("#new-game").click(function() {
    newGame();
  });

  $(window).resize(function() {
    var w = $("#board").width() / 8;
    $("td").width(w);
    $("td").height(w);
    $("td").css('font-size', w * 0.6);
  });
});



newGame = function() {
  var files = ["a", "b", "c", "d", "e", "f", "g", "h"];
  var ranks = ["8", "7", "6", "5", "4", "3", "2", "1"];
  var clr = 'white';
  var str = "";
  for (var i = 0; i < 8; i++) {
    str += "<tr>";
    for (var j = 0; j < 8; j++) {
      str += '<td class=\"' + clr + '\" data-id=\"' + files[j] + ranks[i] + '\"></td>';
      clr = (clr === 'white' ? 'black' : 'white');
    }
    clr = (clr === 'white' ? 'black' : 'white');
    str += "</tr>";
  }
  var $board = $("#board");
  var $report = $("#report");
  var $gfx = $("#gfx");
  $board.html(str);
  $report.empty();
  $gfx.html(
    '<div class="one-half column"><div id="npp" class="ct-chart ct-golden-section"></div></div><div class="one-half column"><div id="pv" class="ct-chart ct-golden-section"></div></div>'
  );
  new App($board, $report, $gfx);
}
