// ensure_user_profile.js
// Ensures expected Android user profile is active via local control server.
//
// Expected JS variables (runScript env):
//   BACKEND_URL       default: http://127.0.0.1:4567
//   TEST_ID           optional
//   DEVICE_ID         optional
//   TARGET_USER_ID    optional (integer)
//   TARGET_USER_NAME  optional (contains match against `pm list users` output)
//   STRICT            optional bool, default false (throw when ensure fails)
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

  var strict = boolVal(typeof STRICT !== 'undefined' ? STRICT : undefined, false);
  var targetUserIdRaw = intVal(typeof TARGET_USER_ID !== 'undefined' ? TARGET_USER_ID : undefined, -1);
  var targetUserName = str(typeof TARGET_USER_NAME !== 'undefined' ? TARGET_USER_NAME : undefined, '');
  var switchSettleMs = intVal(typeof SWITCH_SETTLE_MS !== 'undefined' ? SWITCH_SETTLE_MS : undefined, -1);

  var payload = {
    testId: str(typeof TEST_ID !== 'undefined' ? TEST_ID : undefined, 'studio_ensure_user_profile'),
    deviceId: str(typeof DEVICE_ID !== 'undefined' ? DEVICE_ID : undefined, ''),
    targetUserId: targetUserIdRaw >= 0 ? targetUserIdRaw : null,
    targetUserName: targetUserName,
    strict: strict
  };
  if (switchSettleMs >= 0) {
    payload.switchSettleMs = switchSettleMs;
  }

  var url = backendUrl.replace(/\/+$/, '') + '/device/user-ensure';
  var resp = http.post(url, { headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(payload) });

  var raw = (resp && typeof resp === 'object' && resp.body !== undefined) ? resp.body : resp;
  var parsed = null;
  try {
    parsed = (typeof raw === 'string') ? JSON.parse(raw) : raw;
  } catch (e) {
    parsed = { ok: false, error: String(e), raw: raw };
  }

  output.userProfileEnsure = parsed;
  output.userProfileEnsureOk = !!(parsed && parsed.ok === true);

  if (strict && !output.userProfileEnsureOk) {
    throw new Error('Ensure user profile backend call failed: ' + JSON.stringify(parsed));
  }
})();
