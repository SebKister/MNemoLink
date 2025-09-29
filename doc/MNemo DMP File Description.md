# Mnemo v2 DMP File Format #

## File Version 5 (Standard Format)

**[No File Header]**

**[Per Section Header]** _(13 Bytes)_

    Fileversion; ( 5 for firmware >2.6.0)

    68;

    89;

    101;

    Year;

    Month;

    Day ;

    Hour ;

    Minute ;

    NameChar1;

    NameChar2;

    NameChar3;

    Direction ; ( 0=IN,1=OUT)

**[Per Shot]** _(35 Bytes)_

    57;

    67;

    77;

    Typeshot ; (0=CSA,1=CSB,2=STD,3=EOL)

    HeadingIN LSB;

    HeadingIN MSB;

    HeadingOUT LSB;

    HeadingOUT MSB;

    Length LSB;

    Length MSB;

    DepthIN LSB;

    DepthIN MSB;

    DepthOUT LSB;

    DepthOUT MSB;

    PitchIN LSB;

    PitchIN MSB;

    PitchOUT LSB;

    PitchOUT MSB;

    Left LSB;

    Left MSB;

    Right LSB;

    Right MSB;

    Up LSB;

    Up MSB;

    Down LSB;

    Down MSB;

    Temperature LSB;

    Temperature MSB;

    Hour;

    Minute;

    Second;

    MarkerIdx;

    95;

    25;

    35;

**[Section Termination]** _(35 Bytes)_

    57;67;77;3; [28 times 0;]95;25;35;

---

## File Version 6 (Dry Caving Device with Lidar Support)

**IMPORTANT**: File Version 6 is identical to Version 5 for all common fields, with only optional Lidar data added.

**[No File Header]**

**[Per Section Header]** _(13 Bytes - Same as V5)_

    Fileversion; ( 6 for dry caving devices with Lidar support)

    68;

    89;

    101;

    Year;

    Month;

    Day ;

    Hour ;

    Minute ;

    NameChar1;

    NameChar2;

    NameChar3;

    Direction ; ( 0=IN,1=OUT)

**[Per Shot]** _(35 Bytes - Same as V5 + Optional Lidar Data)_

    57;

    67;

    77;

    Typeshot ; (0=CSA,1=CSB,2=STD,3=EOL)

    HeadingIN LSB;

    HeadingIN MSB;

    HeadingOUT LSB;

    HeadingOUT MSB;

    Length LSB;

    Length MSB;

    DepthIN LSB;

    DepthIN MSB;

    DepthOUT LSB;

    DepthOUT MSB;

    PitchIN LSB;

    PitchIN MSB;

    PitchOUT LSB;

    PitchOUT MSB;

    Left LSB;

    Left MSB;

    Right LSB;

    Right MSB;

    Up LSB;

    Up MSB;

    Down LSB;

    Down MSB;

    Temperature LSB;

    Temperature MSB;

    Hour;

    Minute;

    Second;

    MarkerIdx;

    95;

    25;

    35;

**[Optional Lidar Data]** _(Variable Length)_

    32;         # VOLSTART_VALA

    33;         # VOLSTART_VALB

    34;         # VOLSTART_VALC

    DataLength LSB;
    DataLength MSB;

    # Repeat for DataLength/6 triplet entries:
    YAW LSB;    # (uint16_t) 1/100th of degree to magnetic north (0 = north)
    YAW MSB;

    PITCH LSB;  # (int16_t) 1/100th of degree
    PITCH MSB;

    DISTANCE LSB; # (uint16_t) cm
    DISTANCE MSB;

**[Section Termination]** _(35 Bytes)_

    57;67;77;3; [28 times 0;]95;25;35;

## Format Notes

- **File Version 5**: Standard format for wet caving devices
- **File Version 6**: Enhanced format for dry caving devices with optional Lidar data
- **Byte Order**: Both V5 and V6 use little-endian (LSB first) for all 16-bit values
- **Compatibility**: V6 is fully backward compatible with V5 for all common fields
- **Lidar Data**: Only present in V6 format when device captures 3D point cloud data.
- **Magic Bytes**: Used for data validation and format detection
- **Data Length**: Specifies the total bytes of Lidar data (must be divisible by 6)
