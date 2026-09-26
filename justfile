# Recall — tasks for the dev shell (`nix develop`, or direnv with .envrc).
# The iOS app itself only builds on GitHub Actions (.github/workflows/ios.yml).

set shell := ["bash", "-euo", "pipefail", "-c"]

latest_run := "gh run list --workflow ios.yml --limit 1 --json databaseId --jq '.[0].databaseId'"
latest_ok := "gh run list --workflow ios.yml --status success --limit 1 --json databaseId --jq '.[0].databaseId'"

default:
    @just --list

# Build and test RecallCore (pure Swift) on this machine
core-test:
    #!/usr/bin/env bash
    set -euo pipefail
    if [[ "$(uname)" == Linux ]]; then
        # nixpkgs' Swift can't discover XCTest cases (no libIndexStore), so the
        # tests run as an executable with a generated entry point instead.
        ios/scripts/linux-test-main.sh
        swift run --package-path ios/RecallCore RecallCoreTests
    else
        swift test --package-path ios/RecallCore
    fi

# Format the Swift sources
fmt:
    swiftformat ios --config ios/.swiftformat

# Check formatting and the GitHub workflow
lint:
    swiftformat --lint ios --config ios/.swiftformat
    actionlint

# Start a CI build of a branch (default: the current one)
ci branch="":
    gh workflow run ios.yml --ref "{{ if branch == "" { `git branch --show-current` } else { branch } }}"

# Follow the most recent CI run until it finishes
watch:
    gh run watch "$({{latest_run}})" --exit-status

# Print the failing steps of the most recent CI run
logs:
    gh run view "$({{latest_run}})" --log-failed | tail -n 400

# One-time: allow gh to push GitHub Actions workflows, push, and follow the build
publish:
    gh auth refresh -h github.com -s workflow
    git push
    sleep 8
    just watch

# Download the newest successfully built IPA into dist/
ipa:
    rm -rf dist && mkdir -p dist
    gh run download "$({{latest_ok}})" --name Recall-ipa --dir dist
    ls -lh dist

# Pull crash reports from a USB-connected iPhone into crashes/
crashes:
    mkdir -p crashes && idevicecrashreport -e crashes && ls -lt crashes | head
