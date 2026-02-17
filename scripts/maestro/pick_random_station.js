// pick_random_station.js
// Chooses a bounded random station index for YAML conditional tap branches.
//
// Expected JS variables:
//   RAND_MAX (string/int) default 5
// Writes:
//   output.randStationIndex (int)
//   output.randStationMax   (int)
(function () {
  function intVal(v, dflt) {
    var n = parseInt(String(v), 10);
    return isNaN(n) ? dflt : n;
  }
  var max = intVal(typeof RAND_MAX !== 'undefined' ? RAND_MAX : 5, 5);
  if (max < 0) max = 0;
  // Keep selection bounded to currently visible entries in the All stations list.
  if (max > 5) max = 5;

  var idx = Math.floor(Math.random() * (max + 1));
  output.randStationIndex = idx;
  output.randStationMax = max;
})();
