# MNemo v2 DMP File Format - Complete Documentation

## Overview

The DMP (Data Memory Package) file format is the native binary format used by MNemo v2 cave surveying instruments to store survey data. This document provides complete technical specification of the file format, including all versions and implementation details.

## File Format Evolution

The DMP format has evolved through several versions:
- **Version 2**: Basic format with core measurements
- **Version 3**: Added temperature and timestamp data
- **Version 4**: Added LRUD (Left/Right/Up/Down) passage measurements  
- **Version 5**: Added magic byte validation for data integrity (firmware 2.6.0+)

## File Structure

DMP files have **NO GLOBAL HEADER** and consist of multiple sections, each containing:
1. Section Header (13 bytes)
2. Variable number of Shot Records (35 bytes each)
3. Section Terminator (35 bytes with EOC shot type)

### Endianness and Data Types
- **Byte Order**: Little-endian for multi-byte values
- **Integers**: 16-bit signed integers (2 bytes)
- **Measurements**: Stored as integers * 100 (e.g., 1.25m stored as 125)
- **Angles**: Stored as degrees * 10 (e.g., 45.6° stored as 456)

## Section Header Format (13 bytes)

| Offset | Size | Field | Description |
|--------|------|-------|-------------|
| 0 | 1 | File Version | Format version (2, 3, 4, or 5) |
| 1 | 1 | Magic Byte A | 68 (0x44) - Version 5+ only |
| 2 | 1 | Magic Byte B | 89 (0x59) - Version 5+ only |
| 3 | 1 | Magic Byte C | 101 (0x65) - Version 5+ only |
| 4 | 1 | Year | Year offset from 2000 (e.g., 24 = 2024) |
| 5 | 1 | Month | Month (1-12) |
| 6 | 1 | Day | Day of month (1-31) |
| 7 | 1 | Hour | Hour (0-23) |
| 8 | 1 | Minute | Minute (0-59) |
| 9 | 1 | Name Char 1 | First character of section name |
| 10 | 1 | Name Char 2 | Second character of section name |
| 11 | 1 | Name Char 3 | Third character of section name |
| 12 | 1 | Direction | Survey direction: 0=IN, 1=OUT |

**Notes:**
- Magic bytes (68, 89, 101) provide data integrity validation in version 5+
- Section names are exactly 3 ASCII characters
- Direction indicates survey flow: IN=going into cave, OUT=coming out

## Shot Record Format (35 bytes)

### Magic Bytes and Shot Type (4 bytes)
| Offset | Size | Field | Description |
|--------|------|-------|-------------|
| 0 | 1 | Magic Byte A | 57 (0x39) - Version 5+ only |
| 1 | 1 | Magic Byte B | 67 (0x43) - Version 5+ only |
| 2 | 1 | Magic Byte C | 77 (0x4D) - Version 5+ only |
| 3 | 1 | Shot Type | 0=CSA, 1=CSB, 2=STD, 3=EOC |

### Core Measurements (14 bytes)
| Offset | Size | Field | Description |
|--------|------|-------|-------------|
| 4 | 2 | Heading IN | Compass bearing entering station (degrees * 10) |
| 6 | 2 | Heading OUT | Compass bearing leaving station (degrees * 10) |
| 8 | 2 | Length | Shot length in cm |
| 10 | 2 | Depth IN | Depth at entering station in cm |
| 12 | 2 | Depth OUT | Depth at leaving station in cm |
| 14 | 2 | Pitch IN | Inclination entering station (degrees * 10) |
| 16 | 2 | Pitch OUT | Inclination leaving station (degrees * 10) |

### LRUD Data (8 bytes) - Version 4+ only
| Offset | Size | Field | Description |
|--------|------|-------|-------------|
| 18 | 2 | Left | Passage width to left in cm |
| 20 | 2 | Right | Passage width to right in cm |
| 22 | 2 | Up | Passage height up in cm |
| 24 | 2 | Down | Passage height down in cm |

### Environmental & Time Data (5 bytes) - Version 3+ only
| Offset | Size | Field | Description |
|--------|------|-------|-------------|
| 26 | 2 | Temperature | Temperature reading (device units) |
| 28 | 1 | Hour | Hour when shot was taken (0-23) |
| 29 | 1 | Minute | Minute when shot was taken (0-59) |
| 30 | 1 | Second | Second when shot was taken (0-59) |

### Metadata (4 bytes)
| Offset | Size | Field | Description |
|--------|------|-------|-------------|
| 31 | 1 | Marker Index | Station marker identifier |
| 32 | 1 | End Magic A | 95 (0x5F) - Version 5+ only |
| 33 | 1 | End Magic B | 25 (0x19) - Version 5+ only |
| 34 | 1 | End Magic C | 35 (0x23) - Version 5+ only |

## Shot Types

| Value | Enum | Description |
|-------|------|-------------|
| 0 | CSA | Compass Shot A - First reading of measurement |
| 1 | CSB | Compass Shot B - Second reading of measurement |
| 2 | STD | Standard Shot - Normal survey measurement |
| 3 | EOC | End of Cave/Section - Marks section termination |

## Section Termination

Each section ends with a special shot record containing:
- Shot type = 3 (EOC)
- All measurement fields = 0
- Proper magic bytes for version 5+
- Format: `57 67 77 3 [28 bytes of zeros] 95 25 35`

## Data Conversion

### Distance Measurements
- **Storage**: Integer centimeters
- **Conversion**: divide by 100 for meters
- **Imperial**: multiply by 3.28084/100 for feet

### Angular Measurements  
- **Storage**: Integer degrees * 10
- **Conversion**: divide by 10 for degrees
- **Range**: 0-3599 (0.0° to 359.9°)

### Temperature
- **Storage**: Raw device units
- **Conversion**: Device-specific calibration required

## File Processing Algorithm

1. **Start at file beginning** (no global header)
2. **For each section:**
   - Scan for valid file version byte (2, 3, 4, or 5)
   - Validate magic bytes if version 5+
   - Read section metadata (date, name, direction)
   - Process shots until EOC type found
   - Validate shot magic bytes if version 5+
3. **Continue until end of file**

## Error Handling

### Broken Segments
- Invalid magic bytes indicate data corruption
- Parser should attempt recovery by scanning for next valid section
- Sections with broken segments should be flagged for user review

### Data Validation
- Shot lengths must be positive and reasonable
- Angles must be within valid ranges (0-3599)
- Depth changes should correlate with shot lengths and inclinations

### Problematic Shots
A shot is considered problematic if:
- Length < |depth_out - depth_in| 
- This indicates measurement errors or data corruption
- MNemoLink can calculate corrected lengths using trigonometry

## Version Compatibility

| Feature | Version 2 | Version 3 | Version 4 | Version 5 |
|---------|-----------|-----------|-----------|-----------|
| Core measurements | ✓ | ✓ | ✓ | ✓ |
| Temperature/Time | ✗ | ✓ | ✓ | ✓ |
| LRUD data | ✗ | ✗ | ✓ | ✓ |
| Magic byte validation | ✗ | ✗ | ✗ | ✓ |

## Implementation Notes

### Parser Considerations
- Always validate buffer bounds before reading
- Handle corrupted data gracefully
- Support version detection and appropriate field parsing
- Implement little-endian integer reading
- Preserve original data for re-export

### Memory Layout
- File data is stored sequentially without padding
- Multi-byte values use little-endian byte order
- No alignment requirements for field boundaries

### Export Compatibility
The DMP format can be converted to standard cave surveying formats:
- **Survex (.svx)**: Station-to-station measurements
- **Therion (.th)**: Complete cave map data
- **Excel (.xlsx)**: Tabular data for analysis

## Example Binary Data

### Section Header (Version 5)
```
05 44 59 65 18 0C 0F 0E 1E 41 42 43 00
│  │  │  │  │  │  │  │  │  │  │  │  └─ Direction: IN
│  │  │  │  │  │  │  │  │  │  │  └─ Name: 'C'  
│  │  │  │  │  │  │  │  │  │  └─ Name: 'B'
│  │  │  │  │  │  │  │  │  └─ Name: 'A'
│  │  │  │  │  │  │  │  └─ Minute: 30
│  │  │  │  │  │  │  └─ Hour: 14
│  │  │  │  │  │  └─ Day: 15
│  │  │  │  │  └─ Month: 12
│  │  │  │  └─ Year: 24 (2024)
│  │  │  └─ Magic C: 101
│  │  └─ Magic B: 89  
│  └─ Magic A: 68
└─ Version: 5
```

### Standard Shot Record (Version 5)
```
39 43 4D 02 68 01 70 01 2C 01 90 01 94 01 F4 00 E8 00
│  │  │  │  │     │     │     │     │     │     │     └─ LRUD data...
│  │  │  │  │     │     │     │     │     │     └─ Pitch OUT: 40.0°
│  │  │  │  │     │     │     │     │     └─ Pitch IN: 40.4°  
│  │  │  │  │     │     │     │     └─ Depth OUT: 4.00m
│  │  │  │  │     │     │     └─ Depth IN: 3.68m
│  │  │  │  │     │     └─ Length: 3.00m
│  │  │  │  │     └─ Heading OUT: 36.8°
│  │  │  │  └─ Heading IN: 36.0°
│  │  │  └─ Shot Type: STD
│  │  └─ Magic C: 77
│  └─ Magic B: 67
└─ Magic A: 57
```

This documentation provides complete technical details for implementing DMP file parsers and ensuring compatibility with MNemo v2 devices across all firmware versions.