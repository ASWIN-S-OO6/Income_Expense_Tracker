import 'dart:io';
import 'package:excel/excel.dart';

void main() {
  var excel = Excel.createExcel();
  var sheet = excel.sheets[excel.getDefaultSheet() as String];
  sheet!.cell(CellIndex.indexByString("A1")).value = TextCellValue("Hello");
  sheet.cell(CellIndex.indexByString("A2")).value = IntCellValue(123);
  sheet.cell(CellIndex.indexByString("A3")).value = DoubleCellValue(45.67);
  sheet.cell(CellIndex.indexByString("A4")).value = DateCellValue(year: 2023, month: 10, day: 25);

  for (var row in sheet.rows) {
    for (var cell in row) {
      if (cell == null) continue;
      final val = cell.value;
      if (val is TextCellValue) {
        print("Text: ${val.value.text}");
      } else if (val is DoubleCellValue) {
        print("Double: ${val.value}");
      } else if (val is IntCellValue) {
        print("Int: ${val.value}");
      } else if (val is DateCellValue) {
        print("Date: ${val.year}-${val.month}-${val.day}");
      }
      print('value: ${val?.toString()}, type: ${val.runtimeType}');
    }
  }
}
