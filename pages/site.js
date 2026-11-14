// Optional enhancements. Every instruction on the page works without this file.
(function () {
  "use strict";

  // Fill version placeholders from versions.json, published next to this page.
  fetch("versions.json", { cache: "no-cache" })
    .then(function (r) { return r.ok ? r.json() : Promise.reject(r.status); })
    .then(function (data) {
      if (!data.latest) return;
      document.querySelectorAll("[data-version]").forEach(function (el) {
        el.textContent = data.latest;
      });
      document.querySelectorAll("[data-major]").forEach(function (el) {
        var v = data["latest_" + el.getAttribute("data-major")];
        if (v) el.textContent = "OTP " + v;
      });
      document.querySelectorAll(".js-only").forEach(function (el) { el.hidden = false; });
      document.querySelectorAll(".no-version").forEach(function (el) { el.hidden = true; });
    })
    .catch(function () { /* keep the placeholders and the note that explains them */ });

  // Copy buttons on code blocks.
  document.querySelectorAll("pre").forEach(function (pre) {
    var wrap = document.createElement("div");
    wrap.className = "code";
    pre.parentNode.insertBefore(wrap, pre);
    wrap.appendChild(pre);
    var btn = document.createElement("button");
    btn.type = "button";
    btn.className = "copy";
    btn.textContent = "Copy";
    btn.setAttribute("aria-label", "Copy this command");
    wrap.appendChild(btn);
    btn.addEventListener("click", function () {
      var text = pre.innerText.replace(/\n$/, "");
      var done = function () {
        btn.textContent = "Copied";
        setTimeout(function () { btn.textContent = "Copy"; }, 1600);
      };
      if (navigator.clipboard && navigator.clipboard.writeText) {
        navigator.clipboard.writeText(text).then(done, function () { select(pre); });
      } else {
        select(pre);
      }
    });
  });

  function select(el) {
    var range = document.createRange();
    range.selectNodeContents(el);
    var sel = window.getSelection();
    sel.removeAllRanges();
    sel.addRange(range);
  }
})();
