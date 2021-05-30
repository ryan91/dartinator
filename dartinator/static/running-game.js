"use strict"

var dart_count = 0;
var dart_fields = [];

$(document).ready(function() {
  document.querySelectorAll('path[data-value]').forEach((el) =>
    el.addEventListener('click', (evt) => on_field_selected(evt)));
  document.querySelectorAll('circle[data-value]').forEach((el) =>
    el.addEventListener('click', (evt) => on_field_selected(evt)));
});

function on_field_selected(evt) {
  dart_count++;

  if (dart_count <= 3) {
    const r = Number(evt.target.dataset.radius);
    const v = Number(evt.target.dataset.radius);
    dart_fields.push({ radius: r, value: v });
  }

  if (dart_count == 3) {
    const request = new XMLHttpRequest();
    request.open('POST', '/running-game');
    request.setRequestHeader('Content-Type', 'application/json; charset=UTF-8');
    request.send(JSON.stringify(dart_fields));
    dart_count = 0;
    dart_fields.length = 0;
  }
}
