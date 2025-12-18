/* -----------------------------------------------------------------------------
 * DevOps Simulator - Frontend Logic (STABLE MODE)
 *
 * FINAL ARCHITECTURE:
 * - Grafana and Prometheus are opened directly (no gateway, no iframe)
 * - This avoids reverse proxy, subpath, CSP, and redirect issues
 *
 * URLs:
 *   Grafana    -> http://<host>:3000
 *   Prometheus -> http://<host>:9090
 *
 * IMPORTANT UI BEHAVIOR:
 * - Scenarios are triggered via gateway path: /api/scenarios/<scenario>/start
 * - Live logs arrive via WebSocket: /ws/events
 *
 * HARDENING (new):
 * - If backend response does not include run_id, UI logs a clear warning
 *   instead of silently showing "(n/a)".
 * --------------------------------------------------------------------------- */

/* ---------------------------------------------------------------------------
 * Resolve host dynamically (localhost, LAN, cloud IP, domain)
 * --------------------------------------------------------------------------- */
const host = window.location.hostname;
const grafanaUrl = `http://${host}:3000`;
const prometheusUrl = `http://${host}:9090`;

/* ---------------------------------------------------------------------------
 * DOM references
 * --------------------------------------------------------------------------- */
const stream = document.getElementById("stream");
const scenarioButtons = document.querySelectorAll("[data-scenario]");
const grafanaBtn = document.getElementById("openGrafana");
const promBtn = document.getElementById("openPrometheus");

/* ---------------------------------------------------------------------------
 * Helpers
 * --------------------------------------------------------------------------- */
function appendLine(prefix, msg) {
  const line = document.createElement("div");
  line.className = "line";
  line.textContent = `${new Date().toLocaleTimeString()} · ${prefix} · ${msg}`;
  stream.appendChild(line);
  stream.scrollTop = stream.scrollHeight;
}

function safeJsonParse(text) {
  try {
    return JSON.parse(text);
  } catch {
    return null;
  }
}

/* ---------------------------------------------------------------------------
 * Observability buttons
 * --------------------------------------------------------------------------- */
grafanaBtn.addEventListener("click", () => {
  window.open(grafanaUrl, "_blank");
  appendLine("UI", `📊 Opened Grafana → ${grafanaUrl}`);
});

promBtn.addEventListener("click", () => {
  window.open(prometheusUrl, "_blank");
  appendLine("UI", `📈 Opened Prometheus → ${prometheusUrl}`);
});

/* ---------------------------------------------------------------------------
 * Scenario buttons
 * --------------------------------------------------------------------------- */
scenarioButtons.forEach((btn) => {
  btn.addEventListener("click", async () => {
    const scenario = btn.dataset.scenario;

    appendLine("UI", `▶ Triggering scenario: ${scenario}`);

    try {
      const res = await fetch(`/api/scenarios/${scenario}/start`, { method: "POST" });

      // We want good debugging if server returns non-JSON
      const rawText = await res.text();
      const data = safeJsonParse(rawText);

      if (!res.ok) {
        const detail = data?.detail || rawText || "unknown error";
        appendLine("UI", `❌ Scenario failed: ${scenario} (${detail})`);
        return;
      }

      // Try multiple known fields for compatibility
      const runId =
        data?.run_id ||
        data?.runId ||
        data?.id ||
        data?.data?.run_id ||
        null;

      if (!runId) {
        appendLine("UI", `⚠️ Scenario accepted but no run_id returned. Check scenario-runner route/proxy.`);

        // Still show something consistent
        appendLine("UI", `✅ Scenario started (n/a)`);
        return;
      }

      appendLine("UI", `✅ Scenario started (${runId})`);
    } catch (err) {
      appendLine("UI", `❌ Failed to trigger scenario: ${scenario}`);
    }
  });
});

/* ---------------------------------------------------------------------------
 * Live Incident Stream (WebSocket)
 * --------------------------------------------------------------------------- */
(function connectWs() {
  const proto = window.location.protocol === "https:" ? "wss" : "ws";
  const wsUrl = `${proto}://${window.location.host}/ws/events`;

  const ws = new WebSocket(wsUrl);

  ws.onopen = () => appendLine("Incident Stream", "🟢 Connected to live incident stream");

  ws.onclose = () => {
    appendLine("Incident Stream", "🔴 Live stream disconnected");
    setTimeout(connectWs, 1500);
  };

  ws.onerror = () => appendLine("Incident Stream", "⚠️ WebSocket error");

  ws.onmessage = (ev) => {
    try {
      const msg = JSON.parse(ev.data);
      const prefix = [msg.scenario, msg.step ? `step ${msg.step}` : null, msg.level]
        .filter(Boolean)
        .join(" · ");

      appendLine(prefix || "Event", msg.message || ev.data);
    } catch {
      appendLine("Event", ev.data);
    }
  };
})();
