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
//   WAIT_AFTER_PAD_INITIAL_SECONDS      optional
//   WAIT_AFTER_WOHNEN_ENTER_SECONDS     optional
//   WAIT_AFTER_PARKING_COMMAND_SECONDS  optional
//   WAIT_AFTER_WOHNEN_RETURN_SECONDS    optional
//   WAIT_AFTER_PAD_RETURN_SECONDS       optional
//   SKIP_INITIAL_PAD                     optional (true/false)
//   PRE1_ECU / PRE1_JOB / PRE1_ARG / PRE1_WAIT_SECONDS optional
//   PRE2_ECU / PRE2_JOB / PRE2_ARG / PRE2_WAIT_SECONDS optional
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
    if (!s.length || s === 'undefined' || s === 'null') return dflt;
    if (s === '1' || s === 'true' || s === 'yes' || s === 'on') return true;
    if (s === '0' || s === 'false' || s === 'no' || s === 'off') return false;
    return dflt;
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
    argParking: str(typeof ARGPARKING !== 'undefined' ? ARGPARKING : undefined, 'ARG;ZUSTAND_FAHRZEUG;STR;0x01'),
    waitAfterPadInitialSeconds: intVal(typeof WAIT_AFTER_PAD_INITIAL_SECONDS !== 'undefined' ? WAIT_AFTER_PAD_INITIAL_SECONDS : undefined, 2),
    waitAfterWohnenEnterSeconds: intVal(typeof WAIT_AFTER_WOHNEN_ENTER_SECONDS !== 'undefined' ? WAIT_AFTER_WOHNEN_ENTER_SECONDS : undefined, 2),
    waitAfterParkingCommandSeconds: intVal(typeof WAIT_AFTER_PARKING_COMMAND_SECONDS !== 'undefined' ? WAIT_AFTER_PARKING_COMMAND_SECONDS : undefined, 0),
    waitAfterWohnenReturnSeconds: intVal(typeof WAIT_AFTER_WOHNEN_RETURN_SECONDS !== 'undefined' ? WAIT_AFTER_WOHNEN_RETURN_SECONDS : undefined, 2),
    waitAfterPadReturnSeconds: intVal(typeof WAIT_AFTER_PAD_RETURN_SECONDS !== 'undefined' ? WAIT_AFTER_PAD_RETURN_SECONDS : undefined, 2),
    skipInitialPad: boolVal(typeof SKIP_INITIAL_PAD !== 'undefined' ? SKIP_INITIAL_PAD : undefined, false),
    pre1Ecu: str(typeof PRE1_ECU !== 'undefined' ? PRE1_ECU : undefined, ''),
    pre1Job: str(typeof PRE1_JOB !== 'undefined' ? PRE1_JOB : undefined, ''),
    pre1Arg: str(typeof PRE1_ARG !== 'undefined' ? PRE1_ARG : undefined, ''),
    pre1WaitSeconds: intVal(typeof PRE1_WAIT_SECONDS !== 'undefined' ? PRE1_WAIT_SECONDS : undefined, 0),
    pre2Ecu: str(typeof PRE2_ECU !== 'undefined' ? PRE2_ECU : undefined, ''),
    pre2Job: str(typeof PRE2_JOB !== 'undefined' ? PRE2_JOB : undefined, ''),
    pre2Arg: str(typeof PRE2_ARG !== 'undefined' ? PRE2_ARG : undefined, ''),
    pre2WaitSeconds: intVal(typeof PRE2_WAIT_SECONDS !== 'undefined' ? PRE2_WAIT_SECONDS : undefined, 0)
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
