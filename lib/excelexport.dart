import 'dart:io';

import 'package:intl/intl.dart';
import 'package:excel/excel.dart';
import 'models/models.dart';


void writeHeaderOnSheet(Sheet sheet, int rowNumber) {
  var ls = [
    "A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M", "N", "O", "P", "Q", "R", "S"
  ];
  int index = 0;

  var cell = sheet.cell(CellIndex.indexByString("${ls[index++]}$rowNumber"));
  cell.value = TextCellValue("TypeShot");

  cell = sheet.cell(CellIndex.indexByString("${ls[index++]}$rowNumber"));
  cell.value = TextCellValue("Length");

  cell = sheet.cell(CellIndex.indexByString("${ls[index++]}$rowNumber"));
  cell.value = TextCellValue("Depth IN");

  cell = sheet.cell(CellIndex.indexByString("${ls[index++]}$rowNumber"));
  cell.value = TextCellValue("Depth OUT");

  cell = sheet.cell(CellIndex.indexByString("${ls[index++]}$rowNumber"));
  cell.value = TextCellValue("Heading IN");

  cell = sheet.cell(CellIndex.indexByString("${ls[index++]}$rowNumber"));
  cell.value = TextCellValue("Heading OUT");

  cell = sheet.cell(CellIndex.indexByString("${ls[index++]}$rowNumber"));
  cell.value = TextCellValue("Pitch IN");

  cell = sheet.cell(CellIndex.indexByString("${ls[index++]}$rowNumber"));
  cell.value = TextCellValue("Pitch OUT");

  cell = sheet.cell(CellIndex.indexByString("${ls[index++]}$rowNumber"));
  cell.value = TextCellValue("Left");

  cell = sheet.cell(CellIndex.indexByString("${ls[index++]}$rowNumber"));
  cell.value = TextCellValue("Right");

  cell = sheet.cell(CellIndex.indexByString("${ls[index++]}$rowNumber"));
  cell.value = TextCellValue("Up");

  cell = sheet.cell(CellIndex.indexByString("${ls[index++]}$rowNumber"));
  cell.value = TextCellValue("Down");

  cell = sheet.cell(CellIndex.indexByString("${ls[index++]}$rowNumber"));
  cell.value = TextCellValue("Temperature");

  cell = sheet.cell(CellIndex.indexByString("${ls[index++]}$rowNumber"));
  cell.value = TextCellValue("Time");

  cell = sheet.cell(CellIndex.indexByString("${ls[index++]}$rowNumber"));
  cell.value = TextCellValue("Marker");

  cell = sheet.cell(CellIndex.indexByString("${ls[index++]}$rowNumber"));
  cell.value = TextCellValue("Lidar Yaw");

  cell = sheet.cell(CellIndex.indexByString("${ls[index++]}$rowNumber"));
  cell.value = TextCellValue("Lidar Pitch");

  cell = sheet.cell(CellIndex.indexByString("${ls[index++]}$rowNumber"));
  cell.value = TextCellValue("Lidar Distance");

  cell = sheet.cell(CellIndex.indexByString("${ls[index++]}$rowNumber"));
  cell.value = TextCellValue("Comments");
}


int writeRowOnSheet(Section section, Shot data, Sheet sheet, int startRowNumber) {
  var ls = [
    "A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M", "N", "O", "P", "Q", "R", "S"
  ];

  final cellStyleWithNumberFormatForNumber = CellStyle(
    numberFormat: NumFormat.standard_0,
  );

  int currentRow = startRowNumber;

  // Write the main shot data row
  int index = 0;
  var cell = sheet.cell(CellIndex.indexByString("${ls[index++]}$currentRow"));
  cell.value = TextCellValue(data.typeShot.name);

  cell = sheet.cell(CellIndex.indexByString("${ls[index++]}$currentRow"));
  cell.value = DoubleCellValue(data.getCalculatedLength());
  cell.cellStyle = cellStyleWithNumberFormatForNumber;

  cell = sheet.cell(CellIndex.indexByString("${ls[index++]}$currentRow"));
  cell.value = DoubleCellValue(data.depthIn);
  cell.cellStyle = cellStyleWithNumberFormatForNumber;

  cell = sheet.cell(CellIndex.indexByString("${ls[index++]}$currentRow"));
  cell.value = DoubleCellValue(data.depthOut);
  cell.cellStyle = cellStyleWithNumberFormatForNumber;

  cell = sheet.cell(CellIndex.indexByString("${ls[index++]}$currentRow"));
  cell.value = DoubleCellValue(data.headingIn);
  cell.cellStyle = cellStyleWithNumberFormatForNumber;

  cell = sheet.cell(CellIndex.indexByString("${ls[index++]}$currentRow"));
  cell.value = DoubleCellValue(data.headingOut);
  cell.cellStyle = cellStyleWithNumberFormatForNumber;

  cell = sheet.cell(CellIndex.indexByString("${ls[index++]}$currentRow"));
  cell.value = DoubleCellValue(data.pitchIn);
  cell.cellStyle = cellStyleWithNumberFormatForNumber;

  cell = sheet.cell(CellIndex.indexByString("${ls[index++]}$currentRow"));
  cell.value = DoubleCellValue(data.pitchOut);
  cell.cellStyle = cellStyleWithNumberFormatForNumber;

  cell = sheet.cell(CellIndex.indexByString("${ls[index++]}$currentRow"));
  cell.value = DoubleCellValue(data.left);
  cell.cellStyle = cellStyleWithNumberFormatForNumber;

  cell = sheet.cell(CellIndex.indexByString("${ls[index++]}$currentRow"));
  cell.value = DoubleCellValue(data.right);
  cell.cellStyle = cellStyleWithNumberFormatForNumber;

  cell = sheet.cell(CellIndex.indexByString("${ls[index++]}$currentRow"));
  cell.value = DoubleCellValue(data.up);
  cell.cellStyle = cellStyleWithNumberFormatForNumber;

  cell = sheet.cell(CellIndex.indexByString("${ls[index++]}$currentRow"));
  cell.value = DoubleCellValue(data.down);
  cell.cellStyle = cellStyleWithNumberFormatForNumber;

  cell = sheet.cell(CellIndex.indexByString("${ls[index++]}$currentRow"));
  cell.value = DoubleCellValue(data.temperature);
  cell.cellStyle = cellStyleWithNumberFormatForNumber;

  cell = sheet.cell(CellIndex.indexByString("${ls[index++]}$currentRow"));
  cell.value = TextCellValue(DateTime(
          section.dateSurvey.year,
          section.dateSurvey.month,
          section.dateSurvey.day,
          data.hr,
          data.min,
          data.sec)
      .toIso8601String());

  cell = sheet.cell(CellIndex.indexByString("${ls[index++]}$currentRow"));
  cell.value = IntCellValue(data.markerIndex);
  cell.cellStyle = cellStyleWithNumberFormatForNumber;

  // Leave Lidar columns empty for main shot row
  index += 3; // Skip Lidar Yaw, Pitch, Distance columns

  cell = sheet.cell(CellIndex.indexByString("${ls[index++]}$currentRow"));
  cell.value = TextCellValue(data.usesCalculatedLength()
      ? "Length calculated from depth change and inclination (original measurement was insufficient)"
      : "");

  currentRow++;

  // Write Lidar data rows if available
  if (data.hasLidarData() && data.lidarData != null) {
    for (final lidarPoint in data.lidarData!.points) {
      // Clear all columns for Lidar-only rows
      index = 0;

      // Skip all main shot data columns (15 columns)
      index += 15;

      // Write Lidar data
      cell = sheet.cell(CellIndex.indexByString("${ls[index++]}$currentRow"));
      cell.value = DoubleCellValue(lidarPoint.yaw);
      cell.cellStyle = cellStyleWithNumberFormatForNumber;

      cell = sheet.cell(CellIndex.indexByString("${ls[index++]}$currentRow"));
      cell.value = DoubleCellValue(lidarPoint.pitch);
      cell.cellStyle = cellStyleWithNumberFormatForNumber;

      cell = sheet.cell(CellIndex.indexByString("${ls[index++]}$currentRow"));
      cell.value = DoubleCellValue(lidarPoint.distance);
      cell.cellStyle = cellStyleWithNumberFormatForNumber;

      currentRow++;
    }
  }

  return currentRow;
}


void writeTitleOnSheet(Sheet sheet, Section s, UnitType unitType) {
  var cell = sheet.cell(CellIndex.indexByString("A1"));
  cell.value = TextCellValue(s.getName());

  cell = sheet.cell(CellIndex.indexByString("A2"));
  cell.value = TextCellValue("Direction: ${s.direction.name}");

  cell = sheet.cell(CellIndex.indexByString("B2"));
  cell.value = TextCellValue("Unit: ${unitType.name}");

  cell = sheet.cell(CellIndex.indexByString("A3"));
  cell.value =
      TextCellValue("Date: ${DateFormat('yyyy-MM-dd').format(s.dateSurvey)}");
}

void exportAsExcel(SectionList sectionList, File file, UnitType unitType) {
  var excel =
      Excel.createExcel(); // automatically creates 1 empty sheet: Sheet1

  for (var element in sectionList.sections) {
    var sheetNameCandidate = element.name
        .replaceAll(":", "_")
        .replaceAll(";", "_")
        .replaceAll("<", "_")
        .replaceAll("=", "_")
        .replaceAll(">", "_")
        .replaceAll("?", "_")
        .replaceAll("@", "_")
        .replaceAll(" ", "X");
    int counter = 2;
    var finaleSheetName = sheetNameCandidate;
    while (excel.sheets.containsKey(finaleSheetName)) {
      finaleSheetName = "$sheetNameCandidate($counter)";
      counter++;
    }

    Sheet sheet = excel[finaleSheetName];

    writeTitleOnSheet(sheet, element, unitType);

    int rownum = 5;

    // Check if this section has Lidar data and add a note if so
    bool hasLidarData = element.getShots().any((shot) => shot.hasLidarData());
    if (hasLidarData) {
      var cell = sheet.cell(CellIndex.indexByString("A4"));
      cell.value = TextCellValue("Survey includes Lidar data");
    }

    writeHeaderOnSheet(sheet, rownum++);
    for (final data in element.getShots()) {
      rownum = writeRowOnSheet(element, data, sheet, rownum);
    }
  }

  excel.delete("Sheet1");

  var onValue = excel.encode();
  if (onValue != null) {
    file
      ..createSync(recursive: true)
      ..writeAsBytesSync(onValue);
  }
}
