#!/usr/bin/env bash
# prepare-paper-repo.sh
# Copies figures from docs/ into paper/figures/ and commits + pushes
# the paper to its private GitHub repository for Overleaf sync.
#
# Usage:
#   bash scripts/prepare-paper-repo.sh
#
# Prerequisites:
#   - paper/ must already be a git repo with remote "origin" set to the
#     private GitHub repository (tcp-ecn-paper or similar).
#   - Run from the root of tcp-ecn-lab.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PAPER_DIR="$REPO_ROOT/paper"
DOCS_DIR="$REPO_ROOT/docs"
FIGS_DIR="$PAPER_DIR/figures"

FIGURES=(
  t01-loss-sweep.png
  t04-rtt-sweep.png
  t05-buffer-sweep.png
  t06-multiflow-sweep.png
)

# ---------- 1. copy figures ----------
echo "==> Copying figures to $FIGS_DIR"
mkdir -p "$FIGS_DIR"
for fig in "${FIGURES[@]}"; do
  src="$DOCS_DIR/$fig"
  if [[ ! -f "$src" ]]; then
    echo "  [WARN] $fig not found in docs/ — skipping"
    continue
  fi
  cp "$src" "$FIGS_DIR/$fig"
  echo "  copied $fig"
done

# ---------- 2. update graphicspath in main.tex ----------
# Overleaf resolves paths relative to main.tex, so figures/ works directly.
# Replace ../docs/ with figures/ if not already done.
if grep -q '\\graphicspath{{\.\.\/docs\/}}' "$PAPER_DIR/main.tex"; then
  sed -i '' 's|\\graphicspath{{\.\.\/docs\/}}|\\graphicspath{{figures/}}|' \
      "$PAPER_DIR/main.tex"
  echo "==> Updated \\graphicspath to {figures/} in main.tex"
else
  echo "==> \\graphicspath already updated (or not ../docs/) — skipping"
fi

# ---------- 3. commit and push ----------
echo "==> Committing and pushing to private repo"
cd "$PAPER_DIR"

git add main.tex references.bib .gitignore figures/
git diff --cached --quiet && { echo "Nothing to commit."; exit 0; }

TIMESTAMP="$(date '+%Y-%m-%d %H:%M')"
git commit -m "Sync paper and figures — $TIMESTAMP"
git push origin main

echo ""
echo "Done! Open Overleaf → your project → Menu → GitHub → Pull to sync."
