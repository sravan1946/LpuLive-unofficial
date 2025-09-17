#!/bin/bash
# Script to sort imports in Dart files for pre-commit hook

# Run import sorter on all Dart files in lib/ directory
echo "Sorting imports for all Dart files in lib/..."
flutter pub run import_sorter:main lib/

# Check if any files were modified
if [ $? -eq 0 ]; then
    echo "Import sorting completed successfully"
    exit 0
else
    echo "Import sorting failed"
    exit 1
fi
