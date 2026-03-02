(function () {
  function str(v, d) {
    if (v === undefined || v === null) return d;
    var s = String(v).trim();
    if (!s.length || s === 'undefined' || s === 'null') return d;
    return s;
  }

  var base = str(typeof CONTROL_SERVER_URL !== 'undefined' ? CONTROL_SERVER_URL : undefined, 'http://127.0.0.1:4567');
  var ip = str(typeof DLT_IP !== 'undefined' ? DLT_IP : undefined, '169.254.107.117');
  var port = str(typeof DLT_PORT !== 'undefined' ? DLT_PORT : undefined, '3490');
  var caseId = str(
    typeof CASE_ID !== 'undefined' ? CASE_ID : undefined,
    str(typeof MAESTRO_FILENAME !== 'undefined' ? MAESTRO_FILENAME : undefined, 'STUDIO_CASE')
  );
  var captureId = str(typeof CAPTURE_ID !== 'undefined' ? CAPTURE_ID : undefined, 'IDCEVO_STUDIO');
  var timestamp = str(typeof RUN_TS !== 'undefined' ? RUN_TS : undefined, '');
  var runRoot = str(typeof RUN_ROOT !== 'undefined' ? RUN_ROOT : undefined, '');
  var outputFile = str(typeof DLT_OUTPUT !== 'undefined' ? DLT_OUTPUT : undefined, '');
  var deviceId = str(typeof DEVICE_ID !== 'undefined' ? DEVICE_ID : undefined, '');

  var payload = {
    ip: ip,
    port: port,
    captureId: captureId,
    caseId: caseId,
    timestamp: timestamp,
    runRoot: runRoot,
    outputFile: outputFile,
    deviceId: deviceId
  };

  var resp = http.post(base.replace(/\/+$/, '') + '/dlt/start', {
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(payload)
  });

  var raw = (resp && typeof resp === 'object' && resp.body !== undefined) ? resp.body : resp;
  var parsed = (typeof raw === 'string') ? JSON.parse(raw) : raw;
  output.dltStart = parsed;
  output.dltStartOk = !!(parsed && parsed.ok === true);
})();