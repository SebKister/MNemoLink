# GitHub releases #
Mnemolink has software and firmware update mechanism integrated. In order for them to work properly the release of both firmware on
[Mnemo-v2](https://github.com/SebKister/Mnemo-V2) repository and software on this repo has to follow these rules: 

## Software ##

The update mechanism of the application is expecting to find the JSON describing the latest release at 
 this URL [https://api.github.com/repos/SebKister/Mnemo-V2/releases/latest](https://api.github.com/repos/SebKister/Mnemo-V2/releases/latest)
Further requirements are :
 
**Tag:**

    v{Major}.{Minor}.{Patch}
    Example: v1.3.2

**Assets:**

The order of the asset is important :
1. linux package
2. mac package
3. windows package

## Firmware ##

The update mechanism of the application is expecting to find a JSON file describing the latest release at this URL
[https://api.github.com/repos/SebKister/MnemoLink/releases/latest](https://api.github.com/repos/SebKister/MnemoLink/releases/latest)

Further requirements are :


**Tag:**

    v{Major}.{Minor}.{Patch}
    Example: v2.5.2

**Assets:**
One unique file containing the uncompressed UF2 file of the firmware.


