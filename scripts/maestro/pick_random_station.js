// pick_random_station.js
// Chooses a random station index with optional pre-scroll pages.
//
// Expected JS variables:
//   RAND_MAX (string/int) default 5
//
// Writes:
//   output.randStationIndex         (0..5 visible index after scrolling)
//   output.randStationScrolls       (how many page scrolls before tapping)
//   output.randStationAbsoluteIndex (absolute random index before paging)
//   output.randStationMax           (effective max bound)
(function () {
  function intVal(v, dflt) {
    var n = parseInt(String(v), 10);
    return isNaN(n) ? dflt : n;
  }

  var pageSize = 6; // We tap among 6 visible rows (index 0..5)
  var maxScrolls = 4; // Supports up to 30 stations (5 pages x 6)
  var max = intVal(typeof RAND_MAX !== "undefined" ? RAND_MAX : 5, 5);

  if (max < 0) max = 0;
  if (max > (pageSize * (maxScrolls + 1) - 1)) {
    max = pageSize * (maxScrolls + 1) - 1;
  }

  var absIdx = Math.floor(Math.random() * (max + 1));
  var scrolls = Math.floor(absIdx / pageSize);
  if (scrolls > maxScrolls) scrolls = maxScrolls;

  output.randStationAbsoluteIndex = absIdx;
  output.randStationScrolls = scrolls;
  output.randStationIndex = absIdx % pageSize;
  output.randStationMax = max;
})();
