(function () {
  function str(v, d) {
    if (v === undefined || v === null) return d;
    var s = String(v).trim();
    if (!s.length || s === 'undefined' || s === 'null') return d;
    return s;
  }

  var base = str(typeof CONTROL_SERVER_URL !== 'undefined' ? CONTROL_SERVER_URL : undefined, 'http://127.0.0.1:4567');
  var caseId = str(
    typeof CASE_ID !== 'undefined' ? CASE_ID : undefined,
    str(typeof MAESTRO_FILENAME !== 'undefined' ? MAESTRO_FILENAME : undefined, 'STUDIO_CASE')
  );
  var timestamp = str(typeof RUN_TS !== 'undefined' ? RUN_TS : undefined, '');
  var runRoot = str(typeof RUN_ROOT !== 'undefined' ? RUN_ROOT : undefined, '');

  var captureId = str(typeof CAPTURE_ID !== 'undefined' ? CAPTURE_ID : undefined, 'IDCEVO_STUDIO');
  var payload = { caseId: caseId, timestamp: timestamp, runRoot: runRoot, captureId: captureId };
  var resp = http.post(base.replace(/\/+$/, '') + '/evidence/bundle-studio', {
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(payload)
  });

  var raw = (resp && typeof resp === 'object' && resp.body !== undefined) ? resp.body : resp;
  var parsed = (typeof raw === 'string') ? JSON.parse(raw) : raw;
  output.bundle = parsed;
  output.bundleOk = !!(parsed && parsed.ok === true);
})();