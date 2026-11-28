#!/usr/bin/env bash
set -euo pipefail
umask 077
scratch=$(mktemp -d)
exec 3>&1
stage=inputs
cleanup() {
  rc=$?
  rm -rf -- "$scratch" || rc=1
  if (( rc != 0 )); then echo "::error::Private source verification failed at $stage" >&3; fi
  exit "$rc"
}
trap cleanup EXIT
exec >"$scratch/fetch.log" 2>&1
[[ "$SOURCE_REPO" =~ ^[A-Za-z0-9-]+/[A-Za-z0-9_.-]+$ ]]
[[ "$SOURCE_REF" =~ ^[A-Za-z0-9][A-Za-z0-9._/-]*$ ]]
[[ "$SOURCE_REF" != *..* ]]
[[ "$SOURCE_SHA" =~ ^[0-9a-f]{40}$ ]]
test -n "$SOURCE_DEPLOY_KEY"
printf '%s\n' "$SOURCE_DEPLOY_KEY" > "$scratch/key"
unset SOURCE_DEPLOY_KEY
stage=host-verification
# GitHub's published Ed25519 host key. Pin it rather than depending on a second API call.
printf '%s\n' 'github.com ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl' > "$scratch/known_hosts"
export GIT_SSH_COMMAND="ssh -i '$scratch/key' -o BatchMode=yes -o IdentitiesOnly=yes -o StrictHostKeyChecking=yes -o UserKnownHostsFile='$scratch/known_hosts' -o HostKeyAlgorithms=ssh-ed25519 -o ConnectTimeout=15"
export GIT_TERMINAL_PROMPT=0
export GIT_CONFIG_NOSYSTEM=1
export GIT_CONFIG_GLOBAL=/dev/null
stage=source-directory
mkdir "$RUNNER_TEMP/natter-src"
cd "$RUNNER_TEMP/natter-src"
git init -q .
stage=fetch
for attempt in 1 2 3; do
  if git -c core.hooksPath=/dev/null fetch --depth=1 --no-tags "git@github.com:${SOURCE_REPO}.git" "refs/heads/${SOURCE_REF}"; then break; fi
  if (( attempt == 3 )); then exit 1; fi
  sleep "$attempt"
done
stage='commit-verification'
commit=$(git rev-parse FETCH_HEAD)
test "$commit" = "$SOURCE_SHA"
git checkout -q --detach "$commit"
rm -rf -- .git
printf '%s\n' "$commit" > "$RUNNER_TEMP/natter-source-commit"
echo 'Verified pinned private commit' >&3
