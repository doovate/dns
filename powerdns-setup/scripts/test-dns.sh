#!/usr/bin/env bash
set -euo pipefail
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"
load_env

info "Pruebas de DNS"

# Test 1: recursor responde en puerto ${RECURSOR_PORT}
if dig +short @127.0.0.1 -p ${RECURSOR_PORT} google.com A >/dev/null; then
  success "Recursor responde (consulta pública)"
else
  warn "Recursor no respondió a consulta pública"
fi

# Test 2: resolución de zona interna
if [[ "$(dig +short @127.0.0.1 -p ${RECURSOR_PORT} dns.${DNS_ZONE} A)" == "${DNS_SERVER_IP}" ]]; then
  success "Zona interna resuelve dns.${DNS_ZONE} -> ${DNS_SERVER_IP}"
else
  warn "Fallo al resolver dns.${DNS_ZONE}"
fi

# Test 3: registros adicionales
for rec in sv-vpn dv-vpn; do
  out=$(dig +short @127.0.0.1 -p ${RECURSOR_PORT} ${rec}.${DNS_ZONE} A || true)
  if [[ -n "$out" ]]; then
    success "${rec}.${DNS_ZONE} -> $out"
  else
    warn "No se resolvió ${rec}.${DNS_ZONE}"
  fi
done

# Test 4: API de PowerDNS
if curl -fsS -H "X-API-Key: ${PDNS_API_KEY}" http://127.0.0.1:${PDNS_API_PORT}/api/v1/servers localhost >/dev/null; then
  success "API de PowerDNS disponible en puerto ${PDNS_API_PORT}"
else
  warn "API de PowerDNS no accesible"
fi

# Test 5: Interfaz de PowerDNS-Admin detrás de nginx
if curl -kfsS -H "Host: ${PDNSA_FQDN}" https://127.0.0.1 >/dev/null; then
  success "Nginx/PowerDNS-Admin responde en https://${PDNSA_FQDN} (via 127.0.0.1)"
else
  warn "Nginx/PowerDNS-Admin no respondió"
fi
