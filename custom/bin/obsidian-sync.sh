#!/usr/bin/env bash
# =============================================================================
# Run official Obsidian Sync CLI inside the Hermes container.
#
# Uses obsidian-headless (`ob`) and intentionally does not implement its own
# sync logic. This script only performs optional non-interactive setup, then
# execs `ob sync --continuous`.
# =============================================================================
set -euo pipefail

VAULT_PATH="${OBSIDIAN_VAULT_PATH:-/workspace/obsidian}"
ENABLED="${OBSIDIAN_SYNC_ENABLED:-true}"
SYNC_ONESHOT="${OBSIDIAN_SYNC_ONESHOT:-false}"
REMOTE_VAULT="${OBSIDIAN_REMOTE_VAULT:-}"
CONFIG_DIR="${OBSIDIAN_CONFIG_DIR:-.obsidian}"
DEVICE_NAME="${OBSIDIAN_DEVICE_NAME:-hermes-suite}"
SYNC_MODE="${OBSIDIAN_SYNC_MODE:-}"
CONFLICT_STRATEGY="${OBSIDIAN_CONFLICT_STRATEGY:-}"

mkdir -p "$VAULT_PATH"

if [ "$ENABLED" != "true" ]; then
    echo "Obsidian Sync disabled: OBSIDIAN_SYNC_ENABLED=${ENABLED}"
    exec sleep infinity
fi

if ! command -v ob >/dev/null 2>&1; then
    echo "ERROR: obsidian-headless CLI not found on PATH" >&2
    exit 127
fi

# Optional non-interactive login. If credentials are absent, we assume the
# mounted HOME already contains a valid obsidian-headless login/session.
if [ -n "${OBSIDIAN_EMAIL:-}" ] && [ -n "${OBSIDIAN_PASSWORD:-}" ]; then
    login_args=(login --email "$OBSIDIAN_EMAIL" --password "$OBSIDIAN_PASSWORD")
    if [ -n "${OBSIDIAN_MFA:-}" ]; then
        login_args+=(--mfa "$OBSIDIAN_MFA")
    fi
    ob "${login_args[@]}"
fi

# If vault is already configured, do not re-run setup.
if ob sync-status --path "$VAULT_PATH" >/dev/null 2>&1; then
    echo "Obsidian Sync already configured for ${VAULT_PATH}"
else
    if [ -z "$REMOTE_VAULT" ]; then
        echo "Obsidian Sync is not configured for ${VAULT_PATH}."
        echo "Set OBSIDIAN_REMOTE_VAULT, or preconfigure the mounted vault with:"
        echo "  ob sync-setup --vault <id-or-name> --path ${VAULT_PATH}"
        exec sleep infinity
    fi

    setup_args=(sync-setup --vault "$REMOTE_VAULT" --path "$VAULT_PATH" --device-name "$DEVICE_NAME" --config-dir "$CONFIG_DIR")
    if [ -n "${OBSIDIAN_E2EE_PASSWORD:-}" ]; then
        setup_args+=(--password "$OBSIDIAN_E2EE_PASSWORD")
    fi
    ob "${setup_args[@]}"
fi

# Optional mode/config tuning after setup.
config_args=(sync-config --path "$VAULT_PATH")
if [ -n "$SYNC_MODE" ]; then
    config_args+=(--mode "$SYNC_MODE")
fi
if [ -n "$CONFLICT_STRATEGY" ]; then
    config_args+=(--conflict-strategy "$CONFLICT_STRATEGY")
fi
if [ ${#config_args[@]} -gt 3 ]; then
    ob "${config_args[@]}"
fi

if [ "$SYNC_ONESHOT" = "true" ]; then
    exec ob sync --path "$VAULT_PATH"
fi

exec ob sync --path "$VAULT_PATH" --continuous
