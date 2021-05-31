"use strict"

var dart_count = 0;
var dart_fields = [];
const HIGHTLIGHT_PERIOD_MS = 150;
const HIGHLIGHT_DIFF = 20;

$(document).ready(function() {
  document.querySelectorAll('path[data-value]').forEach((el) => {
    el.addEventListener('click', (evt) => on_field_selected(evt))
  });
  document.querySelectorAll('circle[data-value]').forEach((el) =>
    el.addEventListener('click', (evt) => on_field_selected(evt)));
});

function parseRGB(rgb) {
  const sep = rgb.indexOf(",") > -1 ? "," : " ";
  rgb = rgb.substr(4).split(")")[0].split(sep);
  return[+rgb[0], +rgb[1], +rgb[2]];
}

function on_field_selected(evt) {
  dart_count++;
  
  const rgb = parseRGB(evt.target.style.fill);
  var rgb_new = [];
  for (var i = 0; i < rgb.length; ++i) {
    rgb_new.push(rgb[i] + HIGHLIGHT_DIFF);
  }

  evt.target.style.fill=`rgb(${rgb_new[0]}, ${rgb_new[1]}, ${rgb_new[2]})`;
  setTimeout(() => evt.target.style.fill=
    `rgb(${rgb[0]}, ${rgb[1]}, ${rgb[2]})`, HIGHTLIGHT_PERIOD_MS);

  if (dart_count <= 3) {
    const r = Number(evt.target.dataset.radius);
    const v = Number(evt.target.dataset.radius);
    dart_fields.push({ radius: r, value: v });
  }

  if (dart_count == 3) {
    const request = new XMLHttpRequest();
    request.open('POST', '/running-game');
    request.setRequestHeader('Content-Type',
      'application/json; charset=UTF-8');
    request.send(JSON.stringify(dart_fields));
    dart_count = 0;
    dart_fields.length = 0;
  }
}
