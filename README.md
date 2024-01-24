# mnemolink

Computer interface software for MNemo v2

## Getting Started

This project is a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.


## BUILD AND DEBUG

### Windows

On Windows, you can find precise indication on installation requirements [here](https://docs.flutter.dev/get-started/install/windows/desktop).

Following those steps and getting a `flutter doctor` result similar to the one shown is enough to build and run the MNemoLink project.

To build the Android app you'll additionaly need to follow [this guide](https://docs.flutter.dev/get-started/install/windows/mobile?tab=vscode)

### Linux or Windows 11 + WSL2
On Linux and Windows 11 + WSL2, we offer a `VS CODE` devcontainer https://code.visualstudio.com/docs/devcontainers/containers to improve the speed and portability of the development environment.

It requires `VS Code`, Docker and Devcontainer Extension (`ms-vscode-remote.remote-containers`) installed.

Then follow the instructions:

```bash
`git clone https://github.com/SebKister/MNemoLink.git`
cd MnemoLink
code -n $(pwd)  # Open current directory in VSCode
```

Then `CTRL + P` and select `Dev Containers: Rebuild and Reopen in Container`

This operation will take some time to build and launch a new environment. Once the environment is started, open a new terminal and type:

```bash
make install  # install all dependencies
make run      # run the application in debug mode
```

### MAC OS
On Mac, you can find precise indication on installation requirements [here](https://docs.flutter.dev/get-started/install/macos/desktop).

Following those steps and getting a `flutter doctor` result similar to the one shown is enough to build and run the MNemoLink project.

To build the Android app you'll additionaly need to follow [this guide](https://docs.flutter.dev/get-started/install/macos/mobile-android?tab=vscode)
## DOCUMENTATION
There's no separate documentation existing for MNemolink.

Features requiring documentation should be added to the [MNemo V2 Documenation](https://github.com/SebKister/MNemoV2-Documentation) repository.

### Building for Android - All Platform

See https://github.com/SebKister/MNemoLink/issues/63#issuecomment-1901120588 to solve compilation issue of libserialport