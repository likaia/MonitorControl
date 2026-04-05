#!/bin/zsh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_FILE="${ROOT_DIR}/MonitorControl.xcodeproj/project.pbxproj"
RELEASE_TEMPLATE="${ROOT_DIR}/RELEASE_TEMPLATE.md"

version="${1:-}"

if [[ -z "${version}" ]]; then
  printf "Enter the new version (for example 1.1.0): "
  read -r version
fi

if [[ ! "${version}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Invalid version: ${version}"
  echo "Expected format: MAJOR.MINOR.PATCH"
  exit 1
fi

if [[ ! -f "${PROJECT_FILE}" ]]; then
  echo "Could not find project file: ${PROJECT_FILE}"
  exit 1
fi

perl -0pi -e "s/MARKETING_VERSION = [^;]+;/MARKETING_VERSION = ${version};/g" "${PROJECT_FILE}"

if [[ -f "${RELEASE_TEMPLATE}" ]]; then
  perl -0pi -e 's/`LumaGlass [^`]+`/`LumaGlass '"${version}"'`/' "${RELEASE_TEMPLATE}"
fi

echo "Updated MARKETING_VERSION to ${version}"
echo "Project file: ${PROJECT_FILE}"
