(function () {
  function str(v, d) {
    if (v === undefined || v === null) return d;
    var s = String(v).trim();
    if (!s.length || s === 'undefined' || s === 'null') return d;
    return s;
  }

  var base = str(typeof CONTROL_SERVER_URL !== 'undefined' ? CONTROL_SERVER_URL : undefined, 'http://127.0.0.1:4567');
  var captureId = str(typeof CAPTURE_ID !== 'undefined' ? CAPTURE_ID : undefined, 'IDCEVO_STUDIO');

  var payload = { captureId: captureId };
  var resp = http.post(base.replace(/\/+$/, '') + '/dlt/stop', {
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(payload)
  });

  var raw = (resp && typeof resp === 'object' && resp.body !== undefined) ? resp.body : resp;
  var parsed = (typeof raw === 'string') ? JSON.parse(raw) : raw;
  output.dltStop = parsed;
  output.dltStopOk = !!(parsed && parsed.ok === true);
})();