#!/usr/bin/env bash
# =============================================================================
# test_endpoints.sh — Validación end-to-end del servicio FastAPI tras el ALB.
# Pensado para ejecutarse en VIVO durante el video de evaluación.
#
# Uso:
#   ./scripts/test_endpoints.sh                       # auto-detecta ALB DNS
#   ./scripts/test_endpoints.sh <alb-dns>             # se le pasa explícito
#   BASE_URL=http://localhost:8000 ./scripts/test_endpoints.sh  # override
#
# Salida: códigos de estado por endpoint + latencia + cuerpo JSON, con colores.
# Exit code: 0 si todos los checks pasan, 1 si alguno falla.
# =============================================================================
set -uo pipefail

# ---------- Colores ----------
if [[ -t 1 ]]; then
    GREEN=$'\033[0;32m'
    RED=$'\033[0;31m'
    YELLOW=$'\033[1;33m'
    BLUE=$'\033[0;34m'
    BOLD=$'\033[1m'
    NC=$'\033[0m'
else
    GREEN=""; RED=""; YELLOW=""; BLUE=""; BOLD=""; NC=""
fi

# ---------- Resolver BASE_URL ----------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
INFRA_DIR="$PROJECT_ROOT/infra"

resolve_base_url() {
    if [[ -n "${BASE_URL:-}" ]]; then
        echo "$BASE_URL"
        return
    fi
    if [[ -n "${1:-}" ]]; then
        echo "http://$1"
        return
    fi
    if [[ -d "$INFRA_DIR/.terraform" ]]; then
        local dns
        dns=$(cd "$INFRA_DIR" && terraform output -raw alb_dns_name 2>/dev/null)
        if [[ -n "$dns" ]]; then
            echo "http://$dns"
            return
        fi
    fi
    echo ""
}

BASE_URL=$(resolve_base_url "${1:-}")

if [[ -z "$BASE_URL" ]]; then
    echo "${RED}${BOLD}✗ ERROR:${NC} No se pudo resolver el ALB DNS." >&2
    echo "   Opciones:" >&2
    echo "     export BASE_URL=http://<alb-dns>" >&2
    echo "     ./scripts/test_endpoints.sh <alb-dns>" >&2
    echo "     cd infra && terraform output alb_dns_name" >&2
    exit 1
fi

echo "${BOLD}${BLUE}=========================================================${NC}"
echo "${BOLD}${BLUE}  Validación de endpoints — eval-final-dgiti${NC}"
echo "${BOLD}${BLUE}=========================================================${NC}"
echo "${BOLD}Target:${NC} $BASE_URL"
echo

# ---------- Contadores ----------
PASS=0
FAIL=0
TOTAL=0

# ---------- Helper de validación ----------
# call <NAME> <METHOD> <PATH> <EXPECTED_STATUS> [BODY_JSON] [JQ_FILTER]
call() {
    local name="$1"
    local method="$2"
    local path="$3"
    local expected="$4"
    local body="${5:-}"
    local jq_filter="${6:-.}"

    TOTAL=$((TOTAL + 1))
    local url="${BASE_URL}${path}"

    echo "${BOLD}[${TOTAL}] ${name}${NC}"
    echo "    → ${method} ${url}  (esperado HTTP ${expected})"

    local tmp_body
    tmp_body=$(mktemp)
    local curl_args=(
        -sS
        -o "$tmp_body"
        -w "%{http_code}|%{time_total}|%{size_download}"
        -X "$method"
        -H "Accept: application/json"
        -H "X-Request-ID: $(uuidgen 2>/dev/null || date +%s%N)"
        --max-time 15
    )
    if [[ -n "$body" ]]; then
        curl_args+=( -H "Content-Type: application/json" -d "$body" )
    fi

    local metrics
    metrics=$(curl "${curl_args[@]}" "$url" 2>/dev/null) || {
        echo "    ${RED}✗ FAIL${NC} — error de conexión / timeout"
        FAIL=$((FAIL + 1))
        rm -f "$tmp_body"
        echo
        return 1
    }

    local status_code time_total size_download
    IFS='|' read -r status_code time_total size_download <<<"$metrics"

    local latency_ms
    latency_ms=$(awk -v t="$time_total" 'BEGIN { printf "%.0f", t * 1000 }')

    echo "    ← HTTP ${status_code}  •  ${latency_ms} ms  •  ${size_download} bytes"

    if command -v jq >/dev/null 2>&1 && [[ -s "$tmp_body" ]]; then
        local preview
        preview=$(jq -c "$jq_filter" "$tmp_body" 2>/dev/null || cat "$tmp_body")
        echo "    ↳ $preview"
    else
        echo "    ↳ $(head -c 200 "$tmp_body")"
    fi

    if [[ "$status_code" == "$expected" ]]; then
        echo "    ${GREEN}✓ PASS${NC}"
        PASS=$((PASS + 1))
    else
        echo "    ${RED}✗ FAIL${NC} — esperaba ${expected}, recibió ${status_code}"
        FAIL=$((FAIL + 1))
    fi
    echo

    rm -f "$tmp_body"
    return 0
}

# ---------- Suite ----------

call "Root del servicio" \
     "GET" "/" \
     "200" \
     "" \
     "{service, version, docs, health}"

call "Health check (con verificación BD)" \
     "GET" "/health" \
     "200" \
     "" \
     ".data"

call "OpenAPI schema (debe exponer Swagger)" \
     "GET" "/openapi.json" \
     "200" \
     "" \
     ".info"

call "Listar items (estado inicial)" \
     "GET" "/api/items" \
     "200" \
     "" \
     ".meta"

call "Crear item válido" \
     "POST" "/api/items" \
     "201" \
     '{"name":"Demo item","description":"creado por test_endpoints.sh"}' \
     ".data | {id, name}"

call "Validación pydantic (name vacío)" \
     "POST" "/api/items" \
     "422" \
     '{"name":""}' \
     ".detail[0].msg"

call "Item inexistente devuelve 404" \
     "GET" "/api/items/9999999" \
     "404" \
     "" \
     "."

call "Listar items (debe tener al menos 1)" \
     "GET" "/api/items?limit=5" \
     "200" \
     "" \
     ".meta"

# ---------- Resumen ----------
echo "${BOLD}${BLUE}=========================================================${NC}"
echo "${BOLD}Resumen:${NC} ${TOTAL} checks  •  ${GREEN}${PASS} pass${NC}  •  ${RED}${FAIL} fail${NC}"
echo "${BOLD}${BLUE}=========================================================${NC}"

if [[ "$FAIL" -gt 0 ]]; then
    exit 1
fi
exit 0
