// ediabas_str_sidecar_backend.js
// Triggers EDIABAS STR sidecar execution via local control server.
//
// Expected JS variables (passed via runScript env):
//   BACKEND_URL      default: http://127.0.0.1:4567
//   TEST_ID          optional
//   STR_SECONDS      optional (default 5 for smoke)
//   SETTLE_SECONDS   optional (default 1 for smoke)
//   TIMEOUT_SECONDS  optional (default 90)
//   RETRIES          optional (default 1)
//   ECU              optional (default IPB_APP1)
//   JOB              optional (default STEUERN_ROUTINE)
//   ARGPAD           optional
//   ARGWOHNEN        optional
//   ARGPARKING       optional
(function () {
  function str(v, dflt) {
    if (v === undefined || v === null) return dflt;
    var s = String(v).trim();
    if (!s.length || s === 'undefined' || s === 'null') return dflt;
    return s;
  }

  function intVal(v, dflt) {
    var n = parseInt(String(v == null ? '' : v), 10);
    return Number.isNaN(n) ? dflt : n;
  }

  var backendUrl = str(typeof BACKEND_URL !== 'undefined' ? BACKEND_URL : undefined, 'http://127.0.0.1:4567');
  if (!/^https?:\/\//i.test(backendUrl)) backendUrl = 'http://' + backendUrl;

  var payload = {
    testId: str(typeof TEST_ID !== 'undefined' ? TEST_ID : undefined, 'studio_ediabas_str_sidecar'),
    strSeconds: intVal(typeof STR_SECONDS !== 'undefined' ? STR_SECONDS : undefined, 5),
    settleSeconds: intVal(typeof SETTLE_SECONDS !== 'undefined' ? SETTLE_SECONDS : undefined, 1),
    timeoutSeconds: intVal(typeof TIMEOUT_SECONDS !== 'undefined' ? TIMEOUT_SECONDS : undefined, 90),
    retries: intVal(typeof RETRIES !== 'undefined' ? RETRIES : undefined, 1),
    ecu: str(typeof ECU !== 'undefined' ? ECU : undefined, 'IPB_APP1'),
    job: str(typeof JOB !== 'undefined' ? JOB : undefined, 'STEUERN_ROUTINE'),
    argPad: str(typeof ARGPAD !== 'undefined' ? ARGPAD : undefined, 'ARG;ZUSTAND_FAHRZEUG;STR;0x07'),
    argWohnen: str(typeof ARGWOHNEN !== 'undefined' ? ARGWOHNEN : undefined, 'ARG;ZUSTAND_FAHRZEUG;STR;0x05'),
    argParking: str(typeof ARGPARKING !== 'undefined' ? ARGPARKING : undefined, 'ARG;ZUSTAND_FAHRZEUG;STR;0x01')
  };

  var url = backendUrl.replace(/\/+$/, '') + '/ediabas/str-sidecar';
  var resp = http.post(url, { headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(payload) });

  var raw = (resp && typeof resp === 'object' && resp.body !== undefined) ? resp.body : resp;
  var parsed = null;
  try {
    parsed = (typeof raw === 'string') ? JSON.parse(raw) : raw;
  } catch (e) {
    parsed = { ok: false, error: String(e), raw: raw };
  }

  output.ediabasStr = parsed;
  output.ediabasStrOk = !!(parsed && parsed.ok === true);

  if (!output.ediabasStrOk) {
    throw new Error('EDIABAS STR sidecar backend call failed: ' + JSON.stringify(parsed));
  }
})();
