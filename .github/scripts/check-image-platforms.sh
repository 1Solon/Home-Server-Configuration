#!/usr/bin/env bash
# Usage: check-image-platforms.sh <images.json> <report.md>
# Warns about images whose index is empty or has no linux/arm64 build. Never fails.
set -uo pipefail

images_file=$1
report=$2
problems=()

while IFS= read -r image; do
  [[ -z $image ]] && continue
  if ! raw=$(docker buildx imagetools inspect --raw "$image" 2>&1); then
    problems+=("| \`$image\` | couldn't inspect: $(head -n1 <<<"$raw") |")
    continue
  fi

  media_type=$(jq -r '.mediaType // empty' <<<"$raw")
  if jq -e '.manifests' >/dev/null <<<"$raw"; then
    platforms=$(jq -r '[.manifests[]
      | select((.annotations["vnd.docker.reference.type"] // "") != "attestation-manifest")
      | select(.platform.os != "unknown")
      | "\(.platform.os)/\(.platform.architecture)"] | unique | join(", ")' <<<"$raw")
  else
    platforms=$(docker buildx imagetools inspect "$image" --format '{{json .Image}}' 2>/dev/null \
      | jq -r '"\(.os)/\(.architecture)"')
  fi

  if [[ -z $platforms ]]; then
    problems+=("| \`$image\` | index lists no platforms (${media_type:-unknown media type}) |")
  elif [[ ",${platforms// /}," != *",linux/arm64,"* ]]; then
    problems+=("| \`$image\` | no linux/arm64 build (has: $platforms) |")
  fi
done < <(jq -r '.[]' "$images_file")

if ((${#problems[@]} == 0)); then
  echo "All changed images have a linux/arm64 build."
  exit 0
fi

{
  echo "### Image platform check"
  echo
  echo "kube1-4 are arm64. Ignore these if the workload only runs on kube5 (amd64)."
  echo
  echo "| Image | Problem |"
  echo "| --- | --- |"
  printf '%s\n' "${problems[@]}"
} >"$report"

cat "$report"
for line in "${problems[@]}"; do
  echo "::warning title=Image platform check::$(sed -E 's/^\| `([^`]+)` \| (.*) \|$/\1: \2/' <<<"$line")"
done
exit 0
