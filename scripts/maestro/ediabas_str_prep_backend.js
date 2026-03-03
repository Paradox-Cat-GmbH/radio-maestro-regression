// ediabas_str_prep_backend.js
// Optional pre-STR ADB preparation via local control server.
//
// Expected JS variables (runScript env):
//   BACKEND_URL                     default: http://127.0.0.1:4567
//   TEST_ID                         optional
//   DEVICE_ID                       optional
//   PREP_ENABLED                    default: false
//   PREP_REBOOT                     default: false
//   PREP_TIMEOUT_SECONDS            default: 30
//   PREP_POST_REBOOT_DELAY_SECONDS  default: 15
//   PREP_BEFORE_SHELL               command list separated by || or newline
//   PREP_AFTER_SHELL                command list separated by || or newline
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

  function boolVal(v, dflt) {
    if (v === undefined || v === null) return dflt;
    if (typeof v === 'boolean') return v;
    var s = String(v).trim().toLowerCase();
    if (!s.length) return dflt;
    if (s === '1' || s === 'true' || s === 'yes' || s === 'on') return true;
    if (s === '0' || s === 'false' || s === 'no' || s === 'off') return false;
    return dflt;
  }

  function splitCmds(raw) {
    var s = str(raw, '');
    if (!s) return [];
    return s
      .split(/\r?\n|\|\|/)
      .map(function (x) { return String(x || '').trim(); })
      .filter(function (x) { return x.length > 0; });
  }

  var backendUrl = str(typeof BACKEND_URL !== 'undefined' ? BACKEND_URL : undefined, 'http://127.0.0.1:4567');
  if (!/^https?:\/\//i.test(backendUrl)) backendUrl = 'http://' + backendUrl;

  var payload = {
    testId: str(typeof TEST_ID !== 'undefined' ? TEST_ID : undefined, 'studio_ediabas_str_prep'),
    deviceId: str(typeof DEVICE_ID !== 'undefined' ? DEVICE_ID : undefined, ''),
    enabled: boolVal(typeof PREP_ENABLED !== 'undefined' ? PREP_ENABLED : undefined, false),
    reboot: boolVal(typeof PREP_REBOOT !== 'undefined' ? PREP_REBOOT : undefined, false),
    timeoutSeconds: intVal(typeof PREP_TIMEOUT_SECONDS !== 'undefined' ? PREP_TIMEOUT_SECONDS : undefined, 30),
    postRebootDelaySeconds: intVal(typeof PREP_POST_REBOOT_DELAY_SECONDS !== 'undefined' ? PREP_POST_REBOOT_DELAY_SECONDS : undefined, 15),
    beforeShell: splitCmds(typeof PREP_BEFORE_SHELL !== 'undefined' ? PREP_BEFORE_SHELL : undefined),
    afterShell: splitCmds(typeof PREP_AFTER_SHELL !== 'undefined' ? PREP_AFTER_SHELL : undefined)
  };

  var url = backendUrl.replace(/\/+$/, '') + '/ediabas/str-prep';
  var resp = http.post(url, { headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(payload) });

  var raw = (resp && typeof resp === 'object' && resp.body !== undefined) ? resp.body : resp;
  var parsed = null;
  try {
    parsed = (typeof raw === 'string') ? JSON.parse(raw) : raw;
  } catch (e) {
    parsed = { ok: false, error: String(e), raw: raw };
  }

  output.ediabasPrep = parsed;
  output.ediabasPrepOk = !!(parsed && parsed.ok === true);

  if (!output.ediabasPrepOk) {
    throw new Error('EDIABAS STR prep backend call failed: ' + JSON.stringify(parsed));
  }
})();
