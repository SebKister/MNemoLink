import 'dart:io';

import 'package:intl/intl.dart';
import 'package:mnemolink/sectionlist.dart';
import 'package:excel/excel.dart';
import './section.dart';
import './sectionlist.dart';
import './shot.dart';

void writeHeaderOnSheet(Sheet sheet, int rowNumber) {
  var ls = ["A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L"];
  int index = 0;

  var cell = sheet.cell(CellIndex.indexByString("${ls[index++]}$rowNumber"));
  cell.value = "TypeShot";

  cell = sheet.cell(CellIndex.indexByString("${ls[index++]}$rowNumber"));
  cell.value = "Length";

  cell = sheet.cell(CellIndex.indexByString("${ls[index++]}$rowNumber"));
  cell.value = "Depth IN";

  cell = sheet.cell(CellIndex.indexByString("${ls[index++]}$rowNumber"));
  cell.value = "Depth OUT";

  cell = sheet.cell(CellIndex.indexByString("${ls[index++]}$rowNumber"));
  cell.value = "Heading IN";

  cell = sheet.cell(CellIndex.indexByString("${ls[index++]}$rowNumber"));
  cell.value = "Heading OUT";

  cell = sheet.cell(CellIndex.indexByString("${ls[index++]}$rowNumber"));
  cell.value = "Pitch IN";

  cell = sheet.cell(CellIndex.indexByString("${ls[index++]}$rowNumber"));
  cell.value = "Pitch OUT";

  cell = sheet.cell(CellIndex.indexByString("${ls[index++]}$rowNumber"));
  cell.value = "Temperature";

  cell = sheet.cell(CellIndex.indexByString("${ls[index++]}$rowNumber"));
  cell.value = "Time";

  cell = sheet.cell(CellIndex.indexByString("${ls[index++]}$rowNumber"));
  cell.value = "Marker";
}

void writeRowOnSheet(Section section, Shot data, Sheet sheet, int rowNumber) {
  var ls = ["A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L"];
  int index = 0;

  var cell = sheet.cell(CellIndex.indexByString("${ls[index++]}$rowNumber"));
  cell.value = data.typeShot.name;

  cell = sheet.cell(CellIndex.indexByString("${ls[index++]}$rowNumber"));
  cell.value = data.length;

  cell = sheet.cell(CellIndex.indexByString("${ls[index++]}$rowNumber"));
  cell.value = data.depthIn;

  cell = sheet.cell(CellIndex.indexByString("${ls[index++]}$rowNumber"));
  cell.value = data.depthOut;

  cell = sheet.cell(CellIndex.indexByString("${ls[index++]}$rowNumber"));
  cell.value = data.headingIn / 10.0;

  cell = sheet.cell(CellIndex.indexByString("${ls[index++]}$rowNumber"));
  cell.value = data.headingOut / 10.0;

  cell = sheet.cell(CellIndex.indexByString("${ls[index++]}$rowNumber"));
  cell.value = data.pitchIn / 10.0;

  cell = sheet.cell(CellIndex.indexByString("${ls[index++]}$rowNumber"));
  cell.value = data.pitchOut / 10.0;

  cell = sheet.cell(CellIndex.indexByString("${ls[index++]}$rowNumber"));
  cell.value = data.temperature / 10.0;

  cell = sheet.cell(CellIndex.indexByString("${ls[index++]}$rowNumber"));
  cell.value = DateTime(section.dateSurvey.year, section.dateSurvey.month,
      section.dateSurvey.day, data.hr, data.min, data.sec).toIso8601String();

  cell = sheet.cell(CellIndex.indexByString("${ls[index++]}$rowNumber"));
  cell.value = data.markerIndex;
}

void writeTitleOnSheet(Sheet sheet, Section s, UnitType unitType) {
  var cell = sheet.cell(CellIndex.indexByString("A1"));
  cell.value = s.getName();

  cell = sheet.cell(CellIndex.indexByString("A2"));
  cell.value = "Direction: ${s.direction.name}";

  cell = sheet.cell(CellIndex.indexByString("B2"));
  cell.value = "Unit: ${unitType.name}";

  cell = sheet.cell(CellIndex.indexByString("A3"));
  cell.value = "Date: ${DateFormat('yyyy-MM-dd').format(s.dateSurvey)}";
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
