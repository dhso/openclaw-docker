#!/usr/bin/env bash
set -euo pipefail

OPENCLAW_HOME=${OPENCLAW_HOME:-/root/.openclaw}
EXTRA_STATE_DIR=${OPENCLAW_EXTRA_STATE_DIR:-/usr/local/share/openclaw-docker/extra-deps}
APT_CACHE_DIR=${OPENCLAW_APT_CACHE_DIR:-/root/.cache/apt}
PIP_CACHE_DIR=${PIP_CACHE_DIR:-/root/.cache/pip}
UV_CACHE_DIR=${UV_CACHE_DIR:-/root/.cache/uv}
npm_config_cache=${npm_config_cache:-/root/.cache/npm}
PLAYWRIGHT_BROWSERS_PATH=${PLAYWRIGHT_BROWSERS_PATH:-/root/.cache/ms-playwright}
BUN_INSTALL=${BUN_INSTALL:-/root/.bun}
BUN_INSTALL_CACHE_DIR=${BUN_INSTALL_CACHE_DIR:-/root/.cache/bun/install}
BUN_RUNTIME_TRANSPILER_CACHE_PATH=${BUN_RUNTIME_TRANSPILER_CACHE_PATH:-/root/.cache/bun/transpiler}
SKIP_INSTALL=${SKIP_INSTALL:-${OPENCLAW_SKIP_INSTALL:-}}
PATH="${BUN_INSTALL}/bin:${PATH}"

export PIP_CACHE_DIR UV_CACHE_DIR npm_config_cache PLAYWRIGHT_BROWSERS_PATH BUN_INSTALL BUN_INSTALL_CACHE_DIR BUN_RUNTIME_TRANSPILER_CACHE_PATH PATH

mkdir -p \
  "${OPENCLAW_HOME}/workspace" \
  "${OPENCLAW_HOME}/extensions" \
  "${OPENCLAW_HOME}/.extra-deps" \
  "${EXTRA_STATE_DIR}" \
  "${PIP_CACHE_DIR}" \
  "${UV_CACHE_DIR}" \
  "${npm_config_cache}" \
  "${PLAYWRIGHT_BROWSERS_PATH}" \
  "${BUN_INSTALL}/bin" \
  "${BUN_INSTALL_CACHE_DIR}" \
  "${BUN_RUNTIME_TRANSPILER_CACHE_PATH}" \
  "${APT_CACHE_DIR}/archives/partial" \
  "${APT_CACHE_DIR}/lists/partial"

touch \
  "${OPENCLAW_HOME}/apt.txt" \
  "${OPENCLAW_HOME}/requirement.txt" \
  "${OPENCLAW_HOME}/npm.txt" \
  "${OPENCLAW_HOME}/bun.txt" \
  "${OPENCLAW_HOME}/openclaw-plugins.txt"

trim_line() {
  local line=$1
  line="${line#"${line%%[![:space:]]*}"}"
  line="${line%"${line##*[![:space:]]}"}"
  if [[ "${line}" == \#* ]]; then
    line=""
  fi
  printf '%s\n' "${line}"
}

collect_entries() {
  local substitute_version=$1
  shift

  local file line entry
  for file in "$@"; do
    [ -f "${file}" ] || continue

    while IFS= read -r line || [ -n "${line}" ]; do
      entry=$(trim_line "${line}")
      [ -n "${entry}" ] || continue

      if [ "${substitute_version}" = "true" ]; then
        entry=${entry//\$\{OPENCLAW_VERSION\}/${OPENCLAW_VERSION:-}}
      fi

      printf '%s\n' "${entry}"
    done < "${file}"
  done
}

entries_hash() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum | awk '{print $1}'
  else
    shasum -a 256 | awk '{print $1}'
  fi
}

is_truthy() {
  case "${1:-}" in
    1 | true | TRUE | yes | YES | on | ON)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

run_once_for_hash() {
  local marker=$1
  local current_hash=$2
  shift 2

  if [ -f "${marker}" ] && [ "$(cat "${marker}")" = "${current_hash}" ]; then
    return 0
  fi

  "$@"
  printf '%s' "${current_hash}" > "${marker}"
}

install_extra_apt() {
  local marker="${EXTRA_STATE_DIR}/apt.sha256"
  local current_hash package package_name
  local packages=()

  while IFS= read -r package; do
    packages+=("${package}")
  done < <(collect_entries false "${OPENCLAW_HOME}/apt.txt" "${OPENCLAW_HOME}/apt-packages.txt")
  [ "${#packages[@]}" -gt 0 ] || return 0

  current_hash=$(printf '%s\n' "${packages[@]}" | entries_hash)
  if [ -f "${marker}" ] && [ "$(cat "${marker}")" = "${current_hash}" ]; then
    for package in "${packages[@]}"; do
      package_name=${package%%=*}
      if ! dpkg-query -W -f='${Status}' "${package_name}" 2>/dev/null | grep -q 'install ok installed'; then
        rm -f "${marker}"
        break
      fi
    done
  fi

  run_once_for_hash "${marker}" "${current_hash}" install_extra_apt_packages "${packages[@]}"
}

install_extra_apt_packages() {
  apt-get update \
    -o Dir::State::lists="${APT_CACHE_DIR}/lists"
  apt-get install -y --no-install-recommends \
    -o Dir::State::lists="${APT_CACHE_DIR}/lists" \
    -o Dir::Cache::archives="${APT_CACHE_DIR}/archives" \
    "$@"
}

install_extra_python() {
  local marker="${EXTRA_STATE_DIR}/python.sha256"
  local current_hash
  local files=("${OPENCLAW_HOME}/requirement.txt" "${OPENCLAW_HOME}/requirements.txt")

  current_hash=$(collect_entries false "${files[@]}" | entries_hash)
  if [ "${current_hash}" = "$(printf '' | entries_hash)" ]; then
    return 0
  fi

  run_once_for_hash "${marker}" "${current_hash}" install_extra_python_packages "${files[@]}"
}

install_extra_python_packages() {
  local files=()
  local file

  for file in "$@"; do
    if [ -f "${file}" ] && grep -Eq '^[[:space:]]*[^#[:space:]]' "${file}"; then
      files+=("-r" "${file}")
    fi
  done

  [ "${#files[@]}" -gt 0 ] || return 0

  if command -v uv >/dev/null 2>&1; then
    uv pip install --system "${files[@]}"
  else
    python3 -m pip install "${files[@]}"
  fi
}

install_extra_npm() {
  local marker="${EXTRA_STATE_DIR}/npm.sha256"
  local current_hash package
  local packages=()

  while IFS= read -r package; do
    packages+=("${package}")
  done < <(collect_entries true "${OPENCLAW_HOME}/npm.txt" "${OPENCLAW_HOME}/npm-globals.txt")
  [ "${#packages[@]}" -gt 0 ] || return 0

  current_hash=$(printf '%s\n' "${packages[@]}" | entries_hash)
  run_once_for_hash "${marker}" "${current_hash}" npm install -g "${packages[@]}"
}

install_extra_bun() {
  local marker="${EXTRA_STATE_DIR}/bun.sha256"
  local current_hash package
  local packages=()

  command -v bun >/dev/null 2>&1 || return 0

  while IFS= read -r package; do
    packages+=("${package}")
  done < <(collect_entries true "${OPENCLAW_HOME}/bun.txt" "${OPENCLAW_HOME}/bun-globals.txt")
  [ "${#packages[@]}" -gt 0 ] || return 0

  current_hash=$(printf '%s\n' "${packages[@]}" | entries_hash)
  run_once_for_hash "${marker}" "${current_hash}" bun install -g "${packages[@]}"
}

install_extra_openclaw_plugins() {
  local marker="${OPENCLAW_HOME}/.extra-deps/openclaw-plugins.sha256"
  local current_hash plugin
  local plugins=()

  while IFS= read -r plugin; do
    plugins+=("${plugin}")
  done < <(collect_entries true "${OPENCLAW_HOME}/openclaw-plugins.txt" "${OPENCLAW_HOME}/plugins.txt")
  [ "${#plugins[@]}" -gt 0 ] || return 0
  command -v openclaw >/dev/null 2>&1 || return 0

  current_hash=$(printf '%s\n' "${plugins[@]}" | entries_hash)
  if [ -f "${marker}" ] && [ "$(cat "${marker}")" = "${current_hash}" ]; then
    return 0
  fi

  for plugin in "${plugins[@]}"; do
    timeout 300 openclaw plugins install "${plugin}"
  done

  printf '%s' "${current_hash}" > "${marker}"
}

if ! is_truthy "${SKIP_INSTALL}"; then
  install_extra_apt
  install_extra_python
  install_extra_npm
  install_extra_bun
  install_extra_openclaw_plugins
fi

exec "$@"
