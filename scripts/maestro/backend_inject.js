// backend_inject.js
// Sends an action to the local host control server.
//
// Expected JS variables (passed via runScript env):
//   BACKEND_URL (string)  default: http://127.0.0.1:4567
//   DEVICE_ID   (string)  optional; forwarded to adb -s
//   RUN_DIR     (string)  optional; stored by server for artifacts
//   TEST_ID     (string)  optional; used for artifact naming
//   KIND        (string)  "swag" | "bim" | "ehh" (default: "swag")
//   TARGET      (string)  action target, e.g. "media", "center", "menu", "next", "prev"
//
// Writes:
//   output.inject        (object) server response
//   output.injectOk      (boolean)
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
  var testId     = str(typeof TEST_ID     !== 'undefined' ? TEST_ID     : undefined, "inject");
  var kind       = str(typeof KIND        !== 'undefined' ? KIND        : undefined, "swag").toLowerCase();
  var target     = str(typeof TARGET      !== 'undefined' ? TARGET      : undefined, "");

  var url = backendUrl.replace(/\/+$/, "") + "/inject/" + kind;
  var payload = { deviceId: deviceId, target: target, runDir: runDir, testId: testId };

  var resp = http.post(url, { headers: { "Content-Type": "application/json" }, body: JSON.stringify(payload) });

  // Maestro http.post may return either a string, an object, or an object with .body
  var raw = (resp && typeof resp === "object" && resp.body !== undefined) ? resp.body : resp;
  var parsed = null;
  try {
    parsed = (typeof raw === "string") ? JSON.parse(raw) : raw;
  } catch (e) {
    parsed = { ok: false, error: String(e), raw: raw };
  }

  output.inject = parsed;
  output.injectOk = !!(parsed && parsed.ok === true);
})();
