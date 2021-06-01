"use strict"

var dart_fields = [];
const HIGHTLIGHT_PERIOD_MS = 150;
const HIGHLIGHT_DIFF = 20;

$(document).ready(function() {
  document.getElementById('rg-undo').addEventListener('click', () =>
    on_undo_selected());
  document.getElementById('rg-back').addEventListener('click', () =>
    on_back_selected());
  document.querySelectorAll('path[data-value]').forEach((el) => {
    el.addEventListener('click', (evt) => on_field_selected(evt))
  });
  document.querySelectorAll('circle[data-value]').forEach((el) =>
    el.addEventListener('click', (evt) => on_field_selected(evt)));
});

function on_undo_selected() {
  const l = dart_fields.length;

  if (l == 0)
    return;

  document.getElementById(`t${dart_fields.length}`).textContent = '--';
  dart_fields.length = l - 1;
  update_sum_field();
}

function on_back_selected() {
  var c = confirm('Do you wish to abort this game?');
  if (c) {
    window.location.replace('/home');
  }
}

function on_field_selected(evt) {
  const dart_count = dart_fields.length;

  if (dart_count == 3) {
    const request = new XMLHttpRequest();
    request.open('POST', '/running-game');
    request.setRequestHeader('Content-Type',
      'application/json; charset=UTF-8');
    request.send(JSON.stringify(dart_fields));
    dart_fields.length = 0;
    for (var i = 1; i <= 3; ++i) {
      document.getElementById(`t${i}`).textContent = '--';
    }
    update_sum_field();
  } else if (dart_count < 3) {
    const rgb = parseRGB(evt.target.style.fill);
    var rgb_new = [];
    for (var i = 0; i < rgb.length; ++i) {
      rgb_new.push(rgb[i] + HIGHLIGHT_DIFF);
    }

    // have field light up
    evt.target.style.fill=`rgb(${rgb_new[0]}, ${rgb_new[1]}, ${rgb_new[2]})`;
    setTimeout(() => evt.target.style.fill=
      `rgb(${rgb[0]}, ${rgb[1]}, ${rgb[2]})`, HIGHTLIGHT_PERIOD_MS);

    const r = Number(evt.target.dataset.radius);
    const v = Number(evt.target.dataset.value);
    const n = dart_field_value(r, v);
    dart_fields.push({ radius: r, value: v });
    document.getElementById(`t${dart_fields.length}`).textContent = String(n);
    update_sum_field();
  }
}

function parseRGB(rgb) {
  const sep = rgb.indexOf(",") > -1 ? "," : " ";
  rgb = rgb.substr(4).split(")")[0].split(sep);
  return[+rgb[0], +rgb[1], +rgb[2]];
}

function dart_field_mult(radius) {
  switch (radius) {
    case 0:
    case 5:
      return 2;
    case 1:
    case 2:
    case 4:
      return 1;
    case 3:
      return 3;
    default:
      return 0;
  }
}

function dart_field_value(radius, value) {
  return value * dart_field_mult(radius);
}

function update_sum_field() {
  var sum = 0;
  dart_fields.forEach((el) =>
    sum += dart_field_value(el['radius'], el['value']));
  document.getElementById('tsum').textContent = String(sum);
}
