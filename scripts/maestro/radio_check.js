// radio_check.js
// Calls /radio/check on the local host control server.
//
// Expected JS variables (passed via runScript env):
//   BACKEND_URL (string) default: http://127.0.0.1:4567
//   DEVICE_ID   (string) optional
//   RUN_DIR     (string) optional
//   TEST_ID     (string) optional
//   PACKAGE     (string) expected audio package (default: com.bmwgroup.apinext.tunermediaservice)
//   EXPECTED_PACKAGES (string) optional comma-separated additional packages to accept (first one is PACKAGE)
//
// Writes:
//   output.radioVerdict  (object)
//   output.radioOk       (boolean)
(function () {
  function str(v, dflt) {
    if (v === undefined || v === null) return dflt;
    var s = String(v).trim();
    if (!s.length) return dflt;
    if (s === 'undefined' || s === 'null') return dflt;
    return s;
  }

  var backendUrl = str(typeof BACKEND_URL !== 'undefined' ? BACKEND_URL : undefined, "http://127.0.0.1:4567");
  if (!/^https?:\/\//i.test(backendUrl)) backendUrl = 'http://' + backendUrl;
  var deviceId   = str(typeof DEVICE_ID   !== 'undefined' ? DEVICE_ID   : undefined, "");
  var runDir     = str(typeof RUN_DIR     !== 'undefined' ? RUN_DIR     : undefined, "");
  var testId     = str(typeof TEST_ID     !== 'undefined' ? TEST_ID     : undefined, "radio_check");
  var pkg        = str(typeof PACKAGE     !== 'undefined' ? PACKAGE     : undefined, "com.bmwgroup.apinext.tunermediaservice");
  var extra      = str(typeof EXPECTED_PACKAGES !== 'undefined' ? EXPECTED_PACKAGES : undefined, "");

  var expectedPackages = null;
  if (extra && extra.trim().length) {
    var parts = extra.split(",");
    expectedPackages = [];
    for (var i = 0; i < parts.length; i++) {
      var s = String(parts[i]).trim();
      if (s.length) expectedPackages.push(s);
    }
    if (expectedPackages.length && expectedPackages[0] !== pkg) {
      expectedPackages.unshift(pkg);
    }
  }

  var url = backendUrl.replace(/\/+$/, "") + "/radio/check";
  var payload = { deviceId: deviceId, packageName: pkg, runDir: runDir, testId: testId };
  if (expectedPackages && expectedPackages.length) payload.expectedPackages = expectedPackages;

  var resp = http.post(url, { headers: { "Content-Type": "application/json" }, body: JSON.stringify(payload) });
  var raw = (resp && typeof resp === "object" && resp.body !== undefined) ? resp.body : resp;
  var parsed = null;
  try {
    parsed = (typeof raw === "string") ? JSON.parse(raw) : raw;
  } catch (e) {
    parsed = { ok: false, error: String(e), raw: raw };
  }

  output.radioVerdict = parsed;
  output.radioOk = !!(parsed && parsed.ok === true);
})();
