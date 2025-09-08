# MNemoLink

MNemoLink is a Flutter desktop application that interfaces with MNemo v2 cave surveying devices. It handles device communication, data transfer, processing, and export to various cave surveying formats.

## Features

- **Device Communication**: Connect to MNemo devices via USB serial or WiFi network
- **Data Processing**: Parse and validate DMP (Data Memory Package) files from MNemo devices
- **Multiple Export Formats**: Export survey data to Excel (.xlsx), Survex (.svx), and Therion (.th) formats
- **Real-time CLI Interface**: Direct command-line interface for device control and data retrieval
- **Cross-platform Support**: Full functionality on Windows, Linux, and macOS; limited functionality on Android and iOS
- **Firmware Updates**: Manage MNemo device firmware updates directly from the application

## Architecture Overview

The application follows a service-oriented architecture with clear separation between UI, business logic, and device communication:

### Core Components

- **models/** - Data models (Shot, Section, SectionList, SurveyQuality, Enums)
- **services/** - Business logic services for device communication, networking, data processing, file operations, and firmware updates
- **widgets/** - UI components including CLI interface, connection status, network panels, and data visualization

### Key Services

1. **DeviceCommunicationService** - Handles serial communication with MNemo devices
2. **NetworkService** - Manages network-based device discovery and data transfer
3. **DataProcessingService** - Processes raw survey data into structured sections
4. **FileService** - Handles DMP file operations and exports to Excel/Survex/Therion formats
5. **FirmwareUpdateService** - Manages firmware and software update operations

### Data Flow

1. Device connection via serial or network
2. Raw data transfer from MNemo device (DMP format)
3. Data processing into survey sections with shots
4. Export to various cave surveying formats

## Getting Started

### Prerequisites

- **Flutter SDK 3.5.4+**: [Installation Guide](https://docs.flutter.dev/get-started/install)
- **Platform-specific tools**: See platform sections below for detailed requirements

### Quick Start

1. **Clone the repository**:
   ```bash
   git clone https://github.com/SebKister/MNemoLink.git
   cd MNemoLink
   ```

2. **Install dependencies**:
   ```bash
   make install  # Or flutter pub get
   ```

3. **Run the application**:
   ```bash
   make run      # Or flutter run
   ```


## Platform-Specific Setup

### Windows

Follow the [Flutter Windows installation guide](https://docs.flutter.dev/get-started/install/windows/desktop) for desktop development.

For Android development, follow [this guide](https://docs.flutter.dev/get-started/install/windows/mobile?tab=vscode).

**Build Commands:**
```bash
make build_windows       # Build Windows release
make build_androidFatAPK # Build Android fat APK
make build_androidAPK    # Build Android split APKs
make build_appBundle     # Build Android app bundle
```

### Linux / Windows 11 + WSL2

We provide a VS Code devcontainer for consistent development environments. Requirements:
- VS Code
- Docker
- Devcontainer Extension (`ms-vscode-remote.remote-containers`)

**Setup:**
```bash
git clone https://github.com/SebKister/MNemoLink.git
cd MNemoLink
code -n $(pwd)  # Open in VSCode
```

Then `Ctrl+P` → "Dev Containers: Rebuild and Reopen in Container"

**Build Commands:**
```bash
make build_linux    # Build Linux release
```

### macOS

Follow the [Flutter macOS installation guide](https://docs.flutter.dev/get-started/install/macos/desktop) for desktop development.

For mobile development:
- [Android guide](https://docs.flutter.dev/get-started/install/macos/mobile-android?tab=vscode)
- [iOS guide](https://docs.flutter.dev/get-started/install/macos/mobile-ios)

**Build Commands:**
```bash
make build_macos     # Build macOS release
make build_iosRelease # Build iOS release
```

## Development Commands

### Setup and Dependencies
```bash
make install         # Install Flutter dependencies and perform cleanup
make clean          # Remove build artifacts and Flutter cache
```

### Code Quality
```bash
flutter analyze     # Run static analysis (uses flutter_lints)
flutter test        # Run tests
```

## Testing

Tests are located in the `test/` directory.

Run tests with:
```bash
flutter test
```

## Device Communication

The application communicates with MNemo devices through:
- **Serial communication** (USB connection)
- **Network communication** (WiFi connection via IP address)
- **CLI command interface** for device control and data retrieval

## Export Formats

The application supports multiple cave surveying export formats:
- **DMP** - Native MNemo format
- **Excel (.xlsx)** - Spreadsheet format for data analysis
- **Survex (.svx)** - Open source cave surveying software format
- **Therion (.th)** - Cave mapping and 3D modeling software format

## Contributing

Please read [CONTRIBUTE.md](CONTRIBUTE.md) for detailed guidelines on:
- Code organization and architecture
- Development workflow and standards
- Pull request process
- GitHub Actions CI/CD pipeline

## Documentation

- **Project Documentation**: See [CONTRIBUTE.md](CONTRIBUTE.md) for comprehensive development guidelines
- **DMP File Format**: See `doc/MNemo DMP File Format - Complete Documentation.md` for technical specification
- **MNemo v2 Hardware**: [MNemo V2 Documentation](https://github.com/SebKister/MNemoV2-Documentation)

