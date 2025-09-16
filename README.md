# LPU Live - Unofficial Flutter App

An unofficial Flutter application for LPU Live chat platform.

## Development Setup

### Prerequisites

- Flutter SDK (latest stable version)
- Dart SDK
- Git
- Python 3.7+ (for pre-commit hooks)

### Pre-commit Setup

This project uses pre-commit hooks to ensure code quality and consistency. Follow these steps to set up pre-commit:

#### 1. Install pre-commit

```bash
# Install pre-commit using pip
pip install pre-commit

# Or using conda
conda install -c conda-forge pre-commit

# Or using homebrew (macOS)
brew install pre-commit
```

#### 2. Install the hooks

Navigate to the project root directory and run:

```bash
pre-commit install
```

This will install the pre-commit hooks defined in `.pre-commit-config.yaml` into your git repository.

#### 3. Run hooks manually (optional)

To test the hooks on all files:

```bash
pre-commit run --all-files
```

To run hooks on staged files only:

```bash
pre-commit run
```

### Pre-commit Hooks Included

The following essential hooks are configured:

- **Dart formatter**: Ensures consistent code formatting using `dart format` (only on `lib/` files)
- **Dart import sorter**: Automatically sorts imports using `import_sorter` package (only on `lib/` files)
- **Trailing whitespace removal**: Removes unnecessary whitespace (only on `lib/` files)
- **End-of-file fixer**: Ensures files end with newline (only on `lib/` files)
- **YAML syntax check**: Validates YAML files in `lib/` directory
- **Version bumping**: Automatically bumps version in pubspec.yaml

**Import Sorting**: The `import_sorter` package organizes imports into groups:
1. Dart imports (dart: imports)
2. Flutter imports (package:flutter imports)
3. Project imports (relative imports)

Each group is sorted alphabetically and separated by comments.

**Scope**: All code quality hooks only process files in the `lib/` directory to avoid affecting test files, generated code, or other non-source files. This keeps the build process focused on your actual application code.

### Running the App

1. Ensure Flutter is installed and configured
2. Install dependencies:
   ```bash
   flutter pub get
   ```
3. Run the app:
   ```bash
   flutter run
   ```

### Development Workflow

1. Make your changes
2. Stage your files: `git add .`
3. Commit: `git commit -m "Your commit message"`
   - Pre-commit hooks will run automatically
   - If hooks fail, fix the issues and commit again
4. Push your changes: `git push`

### Troubleshooting Pre-commit

If pre-commit hooks fail:

1. **Formatting issues**: Run `flutter format .` to fix Dart formatting
2. **Import issues**: Run `flutter pub get` to update dependencies
3. **Manual fix**: Address the specific error messages shown
4. **Skip hooks temporarily**: Use `git commit --no-verify` (not recommended)

### Updating Pre-commit Hooks

To update to the latest versions of the hooks:

```bash
pre-commit autoupdate
pre-commit install
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Set up pre-commit hooks as described above
4. Make your changes
5. Ensure all pre-commit hooks pass
6. Submit a pull request

## License

This project is unofficial and not affiliated with LPU.
