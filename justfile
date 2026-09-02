# Matriarch Command -- CMPU 4031 Autonomous Agents
# Mae Capacite, C21348423

# --path is used everywhere rather than cd, so a recipe works from any
# directory and cannot leave the shell somewhere unexpected.
godot := "godot --headless --path godot"
build_dir := "godot/build"

# List the recipes.
default:
    @just --list

# Export both platforms.
build: build-linux build-windows
    @just artefacts

# Export the Linux release.
build-linux:
    # mkdir first: Godot's export does not create a missing output directory,
    # it just fails to write the binary and still reports success.
    mkdir -p {{ build_dir }}/linux
    {{ godot }} --export-release "Linux"

# Export the Windows release.
build-windows:
    mkdir -p {{ build_dir }}/windows
    {{ godot }} --export-release "Windows Desktop"

# Reimport assets and rebuild the global class-name cache.
import:
    # Run after `check`: --check-only does not maintain the project-wide
    # class_name registry, and a stale one fails as "Identifier not declared".
    {{ godot }} --import

# Parse-check every script, then repair the class-name cache.
check:
    #!/usr/bin/env bash
    set -euo pipefail
    failed=0
    for f in $(find godot/scripts -name '*.gd' | sort); do
        out=$({{ godot }} --check-only --script "res://${f#godot/}" 2>&1 \
            | grep -E 'Parse Error|SCRIPT ERROR|Compile Error' || true)
        if [ -n "$out" ]; then
            echo "[FAIL] $f"
            echo "$out"
            failed=1
        fi
    done
    just import
    if [ "$failed" -eq 0 ]; then echo "[OK] all scripts parse"; else exit 1; fi

# Run one headless probe script, e.g. `just probe path/to/probe_blast.gd`.
probe script:
    {{ godot }} --script {{ script }}

# What the builds are, and when they were made.
artefacts:
    @ls -la {{ build_dir }}/linux {{ build_dir }}/windows 2>/dev/null || echo "no builds yet"

# Line and comment counts across the scripts.
stats:
    @echo "files:    $(find godot/scripts -name '*.gd' | wc -l)"
    @echo "lines:    $(find godot/scripts -name '*.gd' -exec cat {} + | wc -l)"
    @echo "comments: $(find godot/scripts -name '*.gd' -exec cat {} + | grep -cE '^\s*#')"

# Remove the exported binaries.
clean:
    # Leaves .godot/ alone: deleting directories Godot expects has broken an
    # export before.
    rm -rf {{ build_dir }}/linux {{ build_dir }}/windows
