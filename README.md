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

### Linux
On Linux, we offer a `VS CODE` devcontainer https://code.visualstudio.com/docs/devcontainers/containers to improve the speed and portability of the development environment.

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
