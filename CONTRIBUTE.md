# Contributing to MNemoLink

Thank you for your interest in contributing to MNemoLink! This guide will help you understand the project structure, development workflow, and contribution process.

## Project Overview

MNemoLink is a Flutter desktop application that interfaces with MNemo v2 cave surveying devices. The application handles device communication, data transfer, processing, and export to various cave surveying formats.

## Getting Started

### Prerequisites

- **Flutter SDK 3.5.4+**: [Installation Guide](https://docs.flutter.dev/get-started/install)
- **Git**: Version control system
- **Platform-specific tools**: See [README.md](README.md) for platform requirements

### Development Environment Setup

1. **Clone the repository**:
   ```bash
   git clone https://github.com/SebKister/MNemoLink.git
   cd MNemoLink
   ```

2. **Install dependencies**:
   ```bash
   make install  # Or flutter pub get
   ```

3. **Verify setup**:
   ```bash
   flutter doctor
   flutter analyze
   ```

4. **Run the application**:
   ```bash
   make run  # Or flutter run
   ```

## Code Organization

### Directory Structure

```
lib/
├── main.dart                 # Application entry point
├── models/                   # Data models
│   ├── shot.dart            # Individual survey measurement
│   ├── section.dart         # Survey section containing shots
│   ├── section_list.dart    # Collection of sections
│   ├── survey_quality.dart  # Survey quality assessment
│   └── enums.dart           # Shared enumerations
├── services/                # Business logic layer
│   ├── device_communication_service.dart  # Serial device communication
│   ├── network_service.dart               # Network-based communication
│   ├── data_processing_service.dart       # DMP data parsing
│   ├── file_service.dart                  # File I/O operations
│   └── firmware_update_service.dart       # Update management
├── widgets/                 # UI components
│   ├── cli_interface.dart   # Command line interface
│   ├── connection_status_bar.dart         # Device status display
│   ├── data_toolbar.dart    # Data manipulation tools
│   └── sectioncard.dart     # Survey section visualization
└── exporters/               # Format-specific export modules
    ├── excelexport.dart     # Excel spreadsheet export
    ├── survexporter.dart    # Survex format export
    └── thexporter.dart      # Therion format export
```

### Architecture Principles

1. **Service-Oriented Architecture**: Business logic is separated into focused services
2. **Model-View Separation**: UI widgets consume data through well-defined models
3. **Platform Abstraction**: Device communication abstracts platform differences
4. **Export Modularity**: Each surveying format has its own export module

## Development Workflow

### 1. Issue Creation

- Check existing issues before creating new ones
- Use issue templates when available
- Provide clear reproduction steps for bugs
- Include system information (OS, Flutter version, device model)

### 2. Branch Strategy

- **Base branches**: Work from `master` or current development branch
- **Feature branches**: Use descriptive names: `feature/survey-quality-scoring`
- **Bug fixes**: Use format: `fix/depth-calculation-precision`
- **Documentation**: Use format: `docs/api-documentation-update`

### 3. Development Process

1. **Create feature branch**:
   ```bash
   git checkout -b feature/your-feature-name
   ```

2. **Make changes following our guidelines** (see sections below)

3. **Test thoroughly**:
   ```bash
   flutter test
   flutter analyze
   ```

4. **Commit with descriptive messages**:
   ```bash
   git commit -m "Add survey quality scoring algorithm
   
   - Implement depth consistency validation
   - Add LRUD measurement quality checks
   - Include shot angle variance analysis"
   ```

## Coding Standards

### Dart/Flutter Guidelines

1. **Follow Flutter style guide**: Use `flutter analyze` and address all warnings
2. **Documentation**: Document all public APIs with dartdoc comments
3. **Null safety**: Leverage Dart's null safety features consistently
4. **Error handling**: Use proper exception handling and user feedback

### Code Style

```dart
// ✅ Good: Clear class documentation
/// Service for processing MNemo binary data and converting to survey models
class DataProcessingService {
  /// Process raw binary transfer buffer into survey sections
  Future<DataProcessingResult> processTransferBuffer(
    List<int> transferBuffer, 
    UnitType unitType
  ) async {
    // Implementation...
  }
}

// ✅ Good: Descriptive variable names
final conversionFactor = unitType == UnitType.metric ? 1.0 : 3.28084;
final sectionResult = await _processSection(transferBuffer, cursor, conversionFactor);

// ❌ Avoid: Unclear abbreviations
final cf = unitType == UnitType.metric ? 1.0 : 3.28084;
final sr = await _processSection(tb, c, cf);
```

### File Organization

1. **Imports**: Group and order imports (Dart, Flutter, external packages, local)
2. **Class structure**: Constants, fields, constructors, public methods, private methods
3. **Method length**: Keep methods focused and under 50 lines when possible
4. **Single responsibility**: Each class should have one clear purpose

### Testing Guidelines

1. **Unit tests**: Test business logic in services and models
2. **Widget tests**: Test UI components in isolation
3. **Integration tests**: Test complete workflows (device communication, data processing)
4. **Test naming**: Use descriptive test names that explain the scenario

```dart
// ✅ Good test naming
test('should convert centimeters to meters when processing DMP data', () {
  // Test implementation
});

test('should detect corrupted shot data when magic bytes are invalid', () {
  // Test implementation  
});
```

### Performance Considerations

1. **Async operations**: Use async/await properly for I/O operations
2. **Memory management**: Dispose of resources (streams, controllers) properly
3. **Large data sets**: Handle large DMP files efficiently with streaming
4. **UI responsiveness**: Keep heavy processing off the main thread

## Pull Request Process

### Before Submitting

1. **Run all checks locally**:
   ```bash
   flutter analyze     # Static analysis
   flutter test        # Run test suite
   make build_linux    # Test build process
   ```

2. **Update documentation**:
   - Update relevant documentation files
   - Add dartdoc comments for new public APIs

3. **Verify CI requirements**:
   - All GitHub Actions checks must pass
   - No breaking changes without discussion

## GitHub Actions Workflow

Our CI/CD pipeline includes several checks that must pass:

### 1. Linter (Required)
- Runs `flutter analyze` for static code analysis
- Must pass before builds can run
- Enforces code style and catches potential issues

### 2. Build Matrix (Required)
- **Linux**: Ubuntu with GTK dependencies
- **macOS**: Latest macOS with Xcode
- **Windows**: Latest Windows with MSVC
- **iOS**: macOS with Xcode 16.4+
- **Android**: Ubuntu with Java 17

### 3. Build Requirements
- All platforms must build successfully
- No compilation errors or warnings
- Dependencies must resolve correctly

### Common CI Failures

| Issue | Solution |
|-------|----------|
| `flutter analyze` warnings | Fix all static analysis warnings |
| Missing dependencies | Update `pubspec.yaml` and run `flutter pub get` |
| Platform build failure | Test locally with `make build_[platform]` |
| Test failures | Run `flutter test` locally and fix failing tests |

## Contributing Guidelines

### Issue Reporting

**Bug Reports** should include:
- MNemoLink version
- Operating system and version
- Connected MNemo device model and firmware
- Steps to reproduce
- Expected vs actual behavior
- Relevant log output or error messages

**Feature Requests** should include:
- Clear use case description
- Proposed implementation approach
- Impact on existing functionality
- Cave surveying context and standards

### Code Contributions

1. **Start small**: Begin with documentation fixes or small bug fixes
2. **Discuss first**: Open an issue for significant changes before implementation
3. **Follow patterns**: Study existing code to understand established patterns
4. **Test thoroughly**: Include comprehensive tests for new functionality
5. **Document changes**: Update relevant documentation and comments

### Communication

- **Be respectful**: Maintain professional and inclusive communication
- **Be specific**: Provide concrete examples and clear explanations
- **Be patient**: Reviews and responses may take time
- **Ask questions**: Don't hesitate to ask for clarification or help

## Cave Surveying Context

Understanding cave surveying helps in making informed contributions:

### Core Concepts

- **Stations**: Survey points connected by shots
- **Shots**: Measurements between stations (distance, bearing, inclination)
- **LRUD**: Passage dimensions (Left, Right, Up, Down) from survey line

### Data Quality

- **Accuracy**: Cave surveys require high precision for mapping
- **Validation**: Check for measurement inconsistencies and errors
- **Standards**: Follow cave surveying conventions for data formats

### Export Formats

- **Survex (.svx)**: Open source cave surveying software format
- **Therion (.th)**: Cave mapping and 3D modeling software
- **Excel (.xlsx)**: General data analysis and visualization

## Resources

- **Flutter Documentation**: https://docs.flutter.dev/
- **Dart Style Guide**: https://dart.dev/guides/language/effective-dart/style
- **Cave Surveying**: https://caves.org/section/survey/
- **Project Issues**: https://github.com/SebKister/MNemoLink/issues
- **MNemo v2 Documentation**: https://github.com/SebKister/MNemoV2-Documentation

## Getting Help

- **Questions**: Open a GitHub issue with the "question" label
- **Bugs**: Follow the bug report template
- **Feature ideas**: Open a discussion or feature request issue
- **Code review**: Request review from maintainers in pull requests

Thank you for contributing to MNemoLink and supporting the cave surveying community!