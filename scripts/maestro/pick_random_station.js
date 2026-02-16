// pick_random_station.js
// Chooses a bounded random station index and builds a selector object.
//
// Expected JS variables:
//   RAND_MAX (string/int) default 3
// Writes:
//   output.randStationIndex (int)
//   output.randStationSelector (object)
(function () {
  function intVal(v, dflt) {
    var n = parseInt(String(v), 10);
    return isNaN(n) ? dflt : n;
  }
  var max = intVal(typeof RAND_MAX !== 'undefined' ? RAND_MAX : 3, 3);
  if (max < 0) max = 0;
  if (max > 50) max = 50;

  var idx = Math.floor(Math.random() * (max + 1));
  output.randStationIndex = idx;
  output.randStationSelector = { id: "ListImageComponent ImageRightIcon", index: idx, retryTapIfNoChange: true };
})();
