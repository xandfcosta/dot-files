#!/bin/bash
cd "$HOME/Documents/obsidian-vaults/" || exit

has_changes() {
  git status --porcelain | grep -q "."
}

if has_changes; then
  echo "There's local changes, stashing..."
  git add .
  git stash push -q
fi

echo "Pulling new notes..."
git pull origin

git stash pop -q 2>/dev/null

if ! has_changes; then
  echo "Nothing to sync, exiting..."
  exit
fi

echo "There's changes, syncing..."
TIMESTAMP=$(date +"%m-%d-%Y %H-%M-%S")
git add .
git commit -m "sync: $TIMESTAMP"
git push -q
echo "Sync was a success"
