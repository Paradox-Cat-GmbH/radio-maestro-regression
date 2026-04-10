(function () {
  function str(v, d) {
    if (v === undefined || v === null) return d;
    var s = String(v).trim();
    if (!s.length || s === 'undefined' || s === 'null') return d;
    return s;
  }

  function hostFromDeviceId(deviceId, d) {
    var s = str(deviceId, '');
    if (!s.length) return d;
    var m = s.match(/^([^:]+)/);
    return m && m[1] ? m[1] : d;
  }

  function stamp() {
    var d = new Date();
    function p(n) { return String(n).padStart(2, '0'); }
    return String(d.getFullYear()) +
      p(d.getMonth() + 1) +
      p(d.getDate()) + '_' +
      p(d.getHours()) +
      p(d.getMinutes()) +
      p(d.getSeconds());
  }

  function capturePrefix(suite, role) {
    var s = str(suite, '');
    var r = str(role, '');
    if (s.length && r.length && r !== s) {
      return s.toUpperCase() + '_' + r.toUpperCase();
    }
    if (s.length) return s.toUpperCase();
    if (r.length) return r.toUpperCase();
    return 'STUDIO';
  }

  var base = str(typeof CONTROL_SERVER_URL !== 'undefined' ? CONTROL_SERVER_URL : undefined, 'http://127.0.0.1:4567');
  var deviceId = str(typeof DEVICE_ID !== 'undefined' ? DEVICE_ID : undefined, '');
  var suite = str(typeof SUITE !== 'undefined' ? SUITE : undefined, str(typeof PLATFORM !== 'undefined' ? PLATFORM : undefined, ''));
  var role = str(typeof ROLE !== 'undefined' ? ROLE : undefined, '');
  var caseId = str(
    typeof CASE_ID !== 'undefined' ? CASE_ID : undefined,
    str(typeof MAESTRO_FILENAME !== 'undefined' ? MAESTRO_FILENAME : undefined, 'STUDIO_CASE')
  );
  var timestamp = str(
    typeof RUN_TS !== 'undefined' ? RUN_TS : undefined,
    str(output.generatedRunTs, stamp())
  );
  var captureId = str(
    typeof CAPTURE_ID !== 'undefined' ? CAPTURE_ID : undefined,
    str(output.generatedCaptureId, capturePrefix(suite, role) + '_STUDIO_' + caseId + '_' + timestamp)
  );
  var ip = str(typeof DLT_IP !== 'undefined' ? DLT_IP : undefined, hostFromDeviceId(deviceId, '169.254.8.177'));
  var port = str(typeof DLT_PORT !== 'undefined' ? DLT_PORT : undefined, '3490');
  var runRoot = str(typeof RUN_ROOT !== 'undefined' ? RUN_ROOT : undefined, '');
  var outputFile = str(typeof DLT_OUTPUT !== 'undefined' ? DLT_OUTPUT : undefined, '');

  var payload = {
    ip: ip,
    port: port,
    captureId: captureId,
    caseId: caseId,
    timestamp: timestamp,
    runRoot: runRoot,
    outputFile: outputFile,
    deviceId: deviceId,
    suite: suite,
    role: role
  };

  var resp = http.post(base.replace(/\/+$/, '') + '/dlt/start', {
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(payload)
  });

  var raw = (resp && typeof resp === 'object' && resp.body !== undefined) ? resp.body : resp;
  var parsed = (typeof raw === 'string') ? JSON.parse(raw) : raw;
  output.dltStart = parsed;
  output.dltStartOk = !!(parsed && parsed.ok === true);
  output.generatedRunTs = str(parsed && parsed.timestamp, timestamp);
  output.generatedRunRoot = str(parsed && parsed.runRoot, runRoot);
  output.generatedDltOutput = str(parsed && parsed.output, outputFile);
  output.generatedCaptureId = str(parsed && parsed.captureId, captureId);
})();
