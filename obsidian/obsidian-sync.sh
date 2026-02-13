#!/bin/bash

cd "$HOME/Documents/obsidian-vaults/" || exit

if ! git diff --quiet; then
  echo "There's changes, stashing it..."
  git add .
  git stash push -q .
fi

echo "Pulling new notes"
git pull

git stash pop -q

if  git diff --quiet; then
  echo "Nothing to sync, exiting..."
  exit
fi

echo "There's changes, syncing"
git add .
TIMESTAMP=$(date +"%m-%d-%Y %H-%M-%S")
echo "sync: $TIMESTAMP"

git add .
git commit -m "sync: $TIMESTAMP"
git push -q

echo "Sync was a success"

