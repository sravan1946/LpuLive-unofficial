#!/bin/bash
# Script to sort imports in Dart files for pre-commit hook

# Get the list of staged Dart files in lib/ directory only
dart_files=$(git diff --cached --name-only --diff-filter=ACM | grep '^lib/.*\.dart$')

if [ -z "$dart_files" ]; then
    exit 0
fi

# Run import sorter on all staged files in lib/
echo "Sorting imports for staged Dart files in lib/..."
flutter pub run import_sorter:main $dart_files

# Check if any files were modified
if [ $? -eq 0 ]; then
    echo "Import sorting completed successfully"
    exit 0
else
    echo "Import sorting failed"
    exit 1
fi
