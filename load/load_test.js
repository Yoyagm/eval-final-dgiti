// ============================================================================
// load_test.js — Prueba de carga k6 contra el ALB del servicio FastAPI.
// Evidencia: balanceo entre instancias, latencia bajo carga, error rate.
//
// Uso:
//   BASE_URL=http://<alb-dns>  k6 run load/load_test.js
//   o:
//   BASE_URL=$(cd infra && terraform output -raw alb_url)  k6 run load/load_test.js
//
// Reporte: tiempo real en terminal + summary final + JSON exportable.
// ============================================================================
import http from "k6/http";
import { check, sleep, group } from "k6";
import { Counter, Rate, Trend } from "k6/metrics";

// --- Métricas custom ---
const errorRate     = new Rate("errors");
const createdItems  = new Counter("items_created");
const requestsByOp  = new Counter("requests_by_op");
const latencyHealth = new Trend("latency_health_ms");
const latencyList   = new Trend("latency_list_ms");
const latencyCreate = new Trend("latency_create_ms");

// --- Configuración del test ---
const BASE_URL = (__ENV.BASE_URL || "http://localhost:8000").replace(/\/$/, "");

export const options = {
  // Stages: rampa 0→50 VUs en 30s, sostener 50 VUs por 2 min, ramp-down 30s.
  stages: [
    { duration: "30s", target: 50 },   // ramp-up
    { duration: "2m",  target: 50 },   // sostener carga
    { duration: "30s", target: 0  },   // ramp-down
  ],
  thresholds: {
    "http_req_duration":      ["p(95)<1500"],   // p95 menor a 1.5 s
    "http_req_failed":        ["rate<0.05"],    // <5% de errores
    "errors":                 ["rate<0.05"],
    "latency_health_ms":      ["p(95)<800"],
    "latency_list_ms":        ["p(95)<1200"],
    "latency_create_ms":      ["p(95)<2000"],
  },
  // Resumen al final
  summaryTrendStats: ["min", "med", "avg", "p(90)", "p(95)", "p(99)", "max"],
};

const COMMON_HEADERS = {
  "Content-Type": "application/json",
  "Accept":       "application/json",
};

// Pool de nombres random para no colisionar en POST
const NAMES = ["Mouse", "Keyboard", "Monitor", "Cable", "Adapter", "Hub", "Webcam", "Stand"];
const SUFFIX = () => Math.random().toString(36).slice(2, 8);

// --- Distribución de tráfico (mix realista) ---
// 70% GET /api/items, 20% POST /api/items, 10% GET /health
export default function () {
  const dice = Math.random();

  if (dice < 0.10) {
    group("health", () => {
      const r = http.get(`${BASE_URL}/health`, { headers: COMMON_HEADERS, tags: { op: "health" } });
      check(r, { "health 200": (res) => res.status === 200 });
      errorRate.add(r.status !== 200);
      latencyHealth.add(r.timings.duration);
      requestsByOp.add(1, { op: "health" });
    });
  } else if (dice < 0.80) {
    group("list_items", () => {
      const r = http.get(`${BASE_URL}/api/items?limit=20`, { headers: COMMON_HEADERS, tags: { op: "list" } });
      check(r, {
        "list 200":         (res) => res.status === 200,
        "list has data":    (res) => res.json("data") !== undefined,
      });
      errorRate.add(r.status !== 200);
      latencyList.add(r.timings.duration);
      requestsByOp.add(1, { op: "list" });
    });
  } else {
    group("create_item", () => {
      const payload = JSON.stringify({
        name: `${NAMES[Math.floor(Math.random() * NAMES.length)]}-${SUFFIX()}`,
        description: `Generado por k6 a las ${new Date().toISOString()}`,
      });
      const r = http.post(`${BASE_URL}/api/items`, payload, { headers: COMMON_HEADERS, tags: { op: "create" } });
      const ok = check(r, {
        "create 201":      (res) => res.status === 201,
        "create has id":   (res) => res.json("data.id") !== undefined,
      });
      if (ok) createdItems.add(1);
      errorRate.add(r.status !== 201);
      latencyCreate.add(r.timings.duration);
      requestsByOp.add(1, { op: "create" });
    });
  }

  sleep(Math.random() * 1.5); // think time entre 0 y 1.5 s
}

// --- Custom summary: imprime tabla amigable al final ---
export function handleSummary(data) {
  const m = data.metrics;
  const pct = (v) => (v * 100).toFixed(2) + "%";
  const ms  = (v) => (v ?? 0).toFixed(1) + " ms";

  const lines = [
    "",
    "============================================================",
    "  RESUMEN DE CARGA — eval-final-dgiti",
    "============================================================",
    `  Target            : ${BASE_URL}`,
    `  Duración total    : ${(data.state.testRunDurationMs / 1000).toFixed(1)} s`,
    `  Iteraciones       : ${m.iterations?.values.count ?? 0}`,
    `  Requests          : ${m.http_reqs?.values.count ?? 0}`,
    `  RPS promedio      : ${(m.http_reqs?.values.rate ?? 0).toFixed(2)}`,
    `  VUs máximo        : ${m.vus_max?.values.max ?? 0}`,
    "",
    "  LATENCIA (todos los requests)",
    `    p50             : ${ms(m.http_req_duration?.values["p(50)"] ?? m.http_req_duration?.values.med)}`,
    `    p95             : ${ms(m.http_req_duration?.values["p(95)"])}`,
    `    p99             : ${ms(m.http_req_duration?.values["p(99)"])}`,
    `    max             : ${ms(m.http_req_duration?.values.max)}`,
    "",
    "  TASA DE ERROR",
    `    HTTP fallidos   : ${pct(m.http_req_failed?.values.rate ?? 0)}`,
    `    checks fallidos : ${pct(1 - (m.checks?.values.rate ?? 1))}`,
    "",
    "  ITEMS CREADOS     : " + (m.items_created?.values.count ?? 0),
    "============================================================",
    "",
  ];

  return {
    "stdout": lines.join("\n"),
    "load/results/summary.json": JSON.stringify(data, null, 2),
  };
}
