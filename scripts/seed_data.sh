#!/usr/bin/env bash
# =============================================================================
# seed_data.sh — Crea 5 items iniciales para que la demo no muestre BD vacía.
# Útil correrlo justo después de terraform apply, antes de grabar.
#
# Uso:
#   ./scripts/seed_data.sh                  # auto-detecta ALB DNS
#   ./scripts/seed_data.sh <alb-dns>
#   BASE_URL=http://localhost:8000 ./scripts/seed_data.sh
# =============================================================================
set -uo pipefail

if [[ -t 1 ]]; then
    GREEN=$'\033[0;32m'; RED=$'\033[0;31m'; BOLD=$'\033[1m'; NC=$'\033[0m'
else
    GREEN=""; RED=""; BOLD=""; NC=""
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
INFRA_DIR="$PROJECT_ROOT/infra"

resolve_base_url() {
    if [[ -n "${BASE_URL:-}" ]]; then echo "$BASE_URL"; return; fi
    if [[ -n "${1:-}" ]]; then echo "http://$1"; return; fi
    if [[ -d "$INFRA_DIR/.terraform" ]]; then
        local dns
        dns=$(cd "$INFRA_DIR" && terraform output -raw alb_dns_name 2>/dev/null)
        [[ -n "$dns" ]] && echo "http://$dns" && return
    fi
    echo ""
}

BASE_URL=$(resolve_base_url "${1:-}")
if [[ -z "$BASE_URL" ]]; then
    echo "${RED}✗ ERROR:${NC} no se pudo resolver el ALB DNS." >&2
    exit 1
fi

echo "${BOLD}Sembrando datos en:${NC} $BASE_URL"
echo

items=(
    '{"name":"Laptop Dell XPS 13","description":"Intel i7, 16GB RAM, 512GB NVMe"}'
    '{"name":"Monitor LG UltraFine 4K","description":"27 pulgadas USB-C"}'
    '{"name":"Teclado Keychron K2","description":"Mecánico inalámbrico hot-swap"}'
    '{"name":"Mouse Logitech MX Master 3S","description":"Ergonómico de precisión"}'
    '{"name":"Webcam Logitech Brio","description":"4K UHD para streaming"}'
)

OK=0
FAIL=0
for body in "${items[@]}"; do
    status=$(curl -sS -o /dev/null -w "%{http_code}" \
                  -X POST "$BASE_URL/api/items" \
                  -H "Content-Type: application/json" \
                  -d "$body" \
                  --max-time 10)
    name=$(echo "$body" | sed -n 's/.*"name":"\([^"]*\)".*/\1/p')
    if [[ "$status" == "201" ]]; then
        echo "  ${GREEN}✓${NC} 201  $name"
        OK=$((OK + 1))
    else
        echo "  ${RED}✗${NC} $status  $name"
        FAIL=$((FAIL + 1))
    fi
done

echo
echo "Creados: ${GREEN}$OK${NC} | Fallidos: ${RED}$FAIL${NC}"
[[ "$FAIL" -gt 0 ]] && exit 1
exit 0
