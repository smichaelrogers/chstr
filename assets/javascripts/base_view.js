App.BaseView = Backbone.View.extend({

  template: JST['index'],

  el: $('body'),

  events: {
    'click #new-game': 'newGame',
    'click #undo-move': 'undoMove',
    'click .revert-position': 'revertPosition',
    'click .square': 'handleSquareClick',
    'click .select-duration': 'selectDuration'
  },


  initialize: function() {
    this.gameHistory = [App.INIT_FEN];
    this.lastPosition = App.INIT_FEN;
    this.moveHistory = [];
    this.moveList = [];
    this.duration = 4;
    this.render();
  },


  render: function() {
    var content = this.template({ranks: App.RANKS,files: App.FILES});
    this.$el.html(content);

    this.nppChart = c3.generate({
      bindto: '#npp',
      data: {
        columns: [
          // ['pv', 0], ['nw', 0], ['qs', 0]
        ],
        empty: {label: { text: 'No Data' }},
        subchart: {show: true},
        types: { pv: 'area-spline', nw: 'spline', qs: 'spline' },
        names: { pv: 'PV', nw: 'Scout', qs: 'Leaf' },
        order: null
      },
      color: { pattern: App.COLORS },
      size: { width: 420, height: 200 },
      axis: { y: {tick: {values: [0, 5000, 10000, 20000, 30000, 40000, 50000, 75000, 100000, 150000] }},
              x: {min: 0, tick: { values: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12] }}},
      point: { show: false },
      tooltip: { show: false },
      legend: { hide: true, position: 'inset', inset: {anchor: 'top-right', x: 10, y: 0, step: undefined }},
      zoom: { enabled: true },
      transition: { duration: 1000 }
    });

    return this;
  },


  renderViews: function(data) {
    var view = this;
    this.lastPosition = this.gameHistory[0];
    this.gameHistory.unshift(data.fen);
    this.moveHistory.unshift(data.move);
    this.nppChart.load({columns: data.npp});

    this.$('#history').html(JST['history']({ moves: view.moveHistory }));
    this.$('#pv-board').html(JST['pv_board']({ squares: data.pv_board }));
    this.$('#pv-list').html(JST['pv_list']({ list: data.pv_list }));
    this.$('#evaluation').html(JST['evaluation']({ ev: data.evaluation }));

    this.$('#pv-count').text(data.pv_count);
    this.$('#nw-count').text(data.nw_count);
    this.$('#qs-count').text(data.qs_count);

    this.$('#clock').text(data.clock);
    this.$('#node-count').text(data.node_count);
    this.$('#nps').text(data.nps);

    this.$('div.square').removeClass('selected movable valid');

    for(var i = 0; i < 64; i++) {
      var $sq = this.$('div.square[data-square="' + i + '"]');
      $sq.empty();
      $sq.text(data.board[i]);

      this.moveList[i] = [];

      if(data.moves[i].length && data.moves[i].length > 0) {
        $sq.addClass('movable');
        for(var j = 0; j < data.moves[i].length; j++) {
          this.moveList[i][j] = _.clone(data.moves[i][j]);
        }
      }
    }
  },


  handleSquareClick: function(event) {
    event.preventDefault();

    var $sq = $(event.currentTarget);
    var i = parseInt($sq.data('square'));

    if($sq.hasClass('movable')) {
      this.$('div.square').removeClass('selected valid');
      $sq.addClass('selected');

      for(var j = 0; j < this.moveList[i].length; j++) {
        this.$('div.square[data-square="' + this.moveList[i][j].to + '"]').addClass('valid');
      }

    } else if($sq.hasClass('valid')) {
      var $selected = this.$('div.selected');
      var j = parseInt($selected.data('square'));

      for(var k = 0; k < this.moveList[j].length; k++) {
        if(this.moveList[j][k].to === i) {
          var fen = this.moveList[j][k].fen;
          var view = this;

          $.ajax({
            url: '/api',
            type: 'post',
            data: {'fen': fen, 'history': view.gameHistory, 'duration': view.duration},
            success: function(resp) {
              console.log(JSON.parse(resp));
              view.renderViews(JSON.parse(resp));
            }
          });
        }
      }
    } else {
      this.$('div.square').removeClass('selected valid');
    }
  },


  newGame: function(event) {
    event.preventDefault();
    var view = this;

    $.ajax({
      url: '/api',
      type: 'get',
      data: {'duration': view.duration },
      success: function(resp) {
        console.log(JSON.parse(resp));
        view.renderViews(JSON.parse(resp));
      }
    });
  },


  selectDuration: function(event) {
    event.preventDefault();
    this.$('.select-duration').removeClass('btn-selected');
    $(event.currentTarget).addClass('btn-selected');
    this.duration = parseInt($(event.currentTarget).text());
  }
});
