#!/usr/bin/env bash
set -euo pipefail

mapfile -t forbidden_files < <(
  git ls-files | awk '
    /(^|\/)\.terraform(\/|$)/ ||
    /\.tfstate($|\.)/ ||
    /\.(tfplan|plan)$/ ||
    /(^|\/)terraform\.tfvars(\.json)?$/ ||
    /\.auto\.tfvars(\.json)?$/ && !/\.example$/ ||
    /(^|\/)personal\./ && !/\.example$/ ||
    /(^|\/)crash(\..*)?\.log$/ {
      print
    }
  '
)

if ((${#forbidden_files[@]} > 0)); then
  printf 'Forbidden local or sensitive files are tracked:\n' >&2
  printf '  %s\n' "${forbidden_files[@]}" >&2
  exit 1
fi

echo "Repository hygiene check passed."
