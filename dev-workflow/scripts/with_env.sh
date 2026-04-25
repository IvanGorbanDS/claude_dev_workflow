#!/usr/bin/env bash
# with_env.sh — load shell rc files for non-interactive subshells, then exec.
#
# Claude Code spawns non-interactive bash subshells that skip ~/.zshrc / ~/.bashrc,
# so ANTHROPIC_API_KEY (and other user env vars) are not available to summarize_for_human.py.
# This wrapper detects the user's $SHELL, sources the matching rc file idempotently,
# then execs the rest of argv.
#
# Idempotent: if ANTHROPIC_API_KEY is already set, skips sourcing.
set -eu

if [ -z "${ANTHROPIC_API_KEY:-}" ]; then
  case "${SHELL:-/bin/sh}" in
    */zsh)
      (. "$HOME/.zshrc") >/dev/null 2>&1 || true
      # shellcheck source=/dev/null
      [ -f "$HOME/.zshrc" ] && . "$HOME/.zshrc" 2>/dev/null || true
      ;;
    */bash)
      (. "$HOME/.bashrc") >/dev/null 2>&1 || true
      # shellcheck source=/dev/null
      [ -f "$HOME/.bashrc" ] && . "$HOME/.bashrc" 2>/dev/null || true
      ;;
    *)
      (. "$HOME/.profile") >/dev/null 2>&1 || true
      # shellcheck source=/dev/null
      [ -f "$HOME/.profile" ] && . "$HOME/.profile" 2>/dev/null || true
      ;;
  esac
fi

exec "$@"
