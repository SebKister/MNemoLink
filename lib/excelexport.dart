import 'dart:io';

import 'package:intl/intl.dart';
import 'package:excel/excel.dart';
import 'models/models.dart';

void writeHeaderOnSheet(Sheet sheet, int rowNumber) {
  var ls = [
    "A",
    "B",
    "C",
    "D",
    "E",
    "F",
    "G",
    "H",
    "I",
    "J",
    "K",
    "L",
    "M",
    "N",
    "O"
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
}

void writeRowOnSheet(Section section, Shot data, Sheet sheet, int rowNumber) {
  var ls = [
    "A",
    "B",
    "C",
    "D",
    "E",
    "F",
    "G",
    "H",
    "I",
    "J",
    "K",
    "L",
    "M",
    "N",
    "O"
  ];
  int index = 0;

  final cellStyleWithNumberFormatForNumber = CellStyle(
    numberFormat: NumFormat.standard_0,
  );

  var cell = sheet.cell(CellIndex.indexByString("${ls[index++]}$rowNumber"));
  cell.value = TextCellValue(data.typeShot.name);

  cell = sheet.cell(CellIndex.indexByString("${ls[index++]}$rowNumber"));
  cell.value = DoubleCellValue(data.length);
  cell.cellStyle = cellStyleWithNumberFormatForNumber;

  cell = sheet.cell(CellIndex.indexByString("${ls[index++]}$rowNumber"));
  cell.value = DoubleCellValue(data.depthIn);
  cell.cellStyle = cellStyleWithNumberFormatForNumber;

  cell = sheet.cell(CellIndex.indexByString("${ls[index++]}$rowNumber"));
  cell.value = DoubleCellValue(data.depthOut);
  cell.cellStyle = cellStyleWithNumberFormatForNumber;

  cell = sheet.cell(CellIndex.indexByString("${ls[index++]}$rowNumber"));
  cell.value = DoubleCellValue(data.headingIn / 10.0);
  cell.cellStyle = cellStyleWithNumberFormatForNumber;

  cell = sheet.cell(CellIndex.indexByString("${ls[index++]}$rowNumber"));
  cell.value = DoubleCellValue(data.headingOut / 10.0);
  cell.cellStyle = cellStyleWithNumberFormatForNumber;

  cell = sheet.cell(CellIndex.indexByString("${ls[index++]}$rowNumber"));
  cell.value = DoubleCellValue(data.pitchIn / 10.0);
  cell.cellStyle = cellStyleWithNumberFormatForNumber;

  cell = sheet.cell(CellIndex.indexByString("${ls[index++]}$rowNumber"));
  cell.value = DoubleCellValue(data.pitchOut / 10.0);
  cell.cellStyle = cellStyleWithNumberFormatForNumber;

  cell = sheet.cell(CellIndex.indexByString("${ls[index++]}$rowNumber"));
  cell.value = DoubleCellValue(data.left);
  cell.cellStyle = cellStyleWithNumberFormatForNumber;

  cell = sheet.cell(CellIndex.indexByString("${ls[index++]}$rowNumber"));
  cell.value = DoubleCellValue(data.right);
  cell.cellStyle = cellStyleWithNumberFormatForNumber;

  cell = sheet.cell(CellIndex.indexByString("${ls[index++]}$rowNumber"));
  cell.value = DoubleCellValue(data.up);
  cell.cellStyle = cellStyleWithNumberFormatForNumber;

  cell = sheet.cell(CellIndex.indexByString("${ls[index++]}$rowNumber"));
  cell.value = DoubleCellValue(data.down);
  cell.cellStyle = cellStyleWithNumberFormatForNumber;

  cell = sheet.cell(CellIndex.indexByString("${ls[index++]}$rowNumber"));
  cell.value = DoubleCellValue(data.temperature / 10.0);
  cell.cellStyle = cellStyleWithNumberFormatForNumber;

  cell = sheet.cell(CellIndex.indexByString("${ls[index++]}$rowNumber"));
  cell.value = TextCellValue(DateTime(
          section.dateSurvey.year,
          section.dateSurvey.month,
          section.dateSurvey.day,
          data.hr,
          data.min,
          data.sec)
      .toIso8601String());

  cell = sheet.cell(CellIndex.indexByString("${ls[index++]}$rowNumber"));
  cell.value = IntCellValue(data.markerIndex);
  cell.cellStyle = cellStyleWithNumberFormatForNumber;
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

    writeHeaderOnSheet(sheet, rownum++);
    element.getShots().forEach((data) {
      writeRowOnSheet(element, data, sheet, rownum++);
    });
  }

  excel.delete("Sheet1");

  var onValue = excel.encode();
  if (onValue != null) {
    file
      ..createSync(recursive: true)
      ..writeAsBytesSync(onValue);
  }
}
