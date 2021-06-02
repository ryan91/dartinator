"use strict"

function set_red_dot(row, do_set) {
  if (do_set) {
    row.cells[1].innerHTML = '<span class="dot"></span>';
  } else {
    row.cells[1].innerHTML = '';
  }
}

function set_white_triangle(row, do_set) {
  if (do_set) {
    row.cells[5].classList.remove('transparent-cell');
    row.cells[5].classList.add('red-cell');
    row.cells[5].textContent = "\u25c0";
  } else {
    row.cells[5].classList.remove('red-cell');
    row.cells[5].classList.add('transparent-cell');
    row.cells[5].textContent = "";
  }
}

function set_sets(row, sets) {
  row.cells[2].textContent = sets;
}

function set_legs(row, legs) {
  row.cells[3].textContent = legs;
}

function set_score(row, score) {
  row.cells[4].textContent = score;
}

function notify(msg) {
  var notbox = document.getElementById('notificationbox');
  notbox.textContent = msg;
  setTimeout(() => notbox.textContent = '', 2000);
}

function to_nth_string(i) {
  switch (i) {
    case 1: return '1st';
    case 2: return '2nd';
    case 3: return '3rd';
    default: return String(i) + "th";
  }
}

function regular_throw(msg, is_no_score) {
  const player = msg.player;
  const next_player = msg.next_player;
  var table = document.getElementById("viewtable");
  for (var i = 1, row; row = table.rows[i]; i++) {
    if (row.cells[0].textContent == player) {
      if (!is_no_score) {
        set_score(row, msg.score);
      }
      set_white_triangle(row, false);
    } else if (row.cells[0].textContent == next_player) {
      set_white_triangle(row, true);
    }
  }
  if (is_no_score) {
    notify('No Score')
  }
}

$(document).ready(function () {
  var socket = io.connect('http://localhost:5000');

  socket.on('register_throw', (msg) => regular_throw(msg, false));

  socket.on('game_shot_and_leg', function(msg) {
    const player = msg.player;
    const starting_player = msg.starting_player;
    const legs = msg.legs;
    const score = msg.score;
    const total = msg.total_legs;
    var table = document.getElementById("viewtable");
    for (var i = 1, row; row = table.rows[i]; i++) {
      set_score(row, score);
      set_red_dot(row, false);
      if (row.cells[0].textContent == player) {
        set_legs(row, legs);
        set_white_triangle(row, false);
      }
      if (row.cells[0].textContent == starting_player) {
        set_white_triangle(row, true);
        set_red_dot(row, true);
      }
    }
    const not = 'Game shot and the ' + to_nth_string(total) + ' leg - ' + player;
    notify(not)
  });

  socket.on('game_shot_and_set', function(msg) {
    const player = msg.player;
    const starting_player = msg.starting_player;
    const sets = msg.sets;
    const score = msg.score;
    const total = msg.total_legs;
    var table = document.getElementById("viewtable");
    for (var i = 1, row; row = table.rows[i]; i++) {
      set_score(row, score);
      set_red_dot(row, false);
      if (row.cells[0].textContent == player) {
        set_sets(row, sets);
        set_white_triangle(row, false);
        set_legs(row, 0);
      }
      if (row.cells[0].textContent == starting_player) {
        set_white_triangle(row, true);
        set_red_dot(row, true);
      }
    }
    const not = 'Game shot and the ' + to_nth_string(total) + ' set - ' + player;
    notify(not);
  });

  socket.on('game_shot_and_match', function(msg) {
    const player = msg.player;
    const sets = msg.sets;

    var table = document.getElementById('viewtable');
    for (var i = 1, row; row = table.rows[i]; i++) {
      set_legs(row, 0);
      if (row.cells[0] == player) {
        set_sets(row, sets);
      }
    }
    notify('Game shot and the match - ' + player);
  });

  socket.on('no_score', (msg) => regular_throw(msg, true));
});
