#!/bin/sh
set -e

PUBSPEC="pubspec.yaml"

# Check if user already changed version
STAGED_VERSION=$(git diff --cached -- $PUBSPEC | grep '^+version:' | awk '{print $2}')

if [ -n "$STAGED_VERSION" ]; then
  echo "Version manually updated to $STAGED_VERSION, skipping auto-bump."
  exit 0
fi

# Extract current version
VERSION=$(grep '^version:' $PUBSPEC | awk '{print $2}')
BASE=$(echo $VERSION | cut -d'+' -f1)
BUILD=$(echo $VERSION | cut -d'+' -f2)

if [ -z "$BUILD" ]; then
  BUILD=0
fi

NEW_BUILD=$((BUILD + 1))
NEW_VERSION="$BASE+$NEW_BUILD"

# Update pubspec.yaml
sed -i "s/^version: .*/version: $NEW_VERSION/" $PUBSPEC

# Stage updated pubspec.yaml
git add $PUBSPEC

echo "Auto-bumped version to $NEW_VERSION"
