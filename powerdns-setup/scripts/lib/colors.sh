#!/usr/bin/env bash
# Simple ANSI color helpers and title borders

bold() { tput bold 2>/dev/null || true; }
normal() { tput sgr0 2>/dev/null || true; }
red() { tput setaf 1 2>/dev/null || true; }
green() { tput setaf 2 2>/dev/null || true; }
yellow() { tput setaf 3 2>/dev/null || true; }
blue() { tput setaf 4 2>/dev/null || true; }

reset_color() { tput sgr0 2>/dev/null || true; }

# Decorative borders/lines
_title_border_cache=""

title_border() {
  if [[ -n "$_title_border_cache" ]]; then
    echo "$_title_border_cache"; return
  fi
  local width=60
  local border=""; for _ in $(seq 1 $width); do border+="═"; done
  _title_border_cache="╔${border}╗"
  echo "$_title_border_cache"
}

title_line() {
  local width=60
  local spaces=""; for _ in $(seq 1 $width); do spaces+=" "; done
  echo "║${spaces}║"
}
