import 'dart:convert';
import 'dart:io';
import 'package:csv/csv.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../models/record.dart';

/// CSV 文件解析服务
class CsvService {
  /// 解析 CSV 文本内容
  static List<HealthRecord> parseCsv(String csvContent) {
    final List<HealthRecord> records = [];

    try {
      // 使用 csv 包解析
      final rows = const CsvToListConverter(
        eol: '\n',
        shouldParseNumbers: false,
      ).convert(csvContent);

      // 跳过表头（第一行）
      for (var i = 1; i < rows.length; i++) {
        final row = rows[i];
        if (row.length >= 3) {
          try {
            final record = HealthRecord(
              testTime: DateTime.parse(row[0].toString().trim()),
              indicatorName: row[1].toString().trim(),
              indicatorValue:
                  double.tryParse(row[2].toString().trim()) ?? 0.0,
              remark: row.length > 3 ? row[3].toString().trim() : null,
            );
            records.add(record);
          } catch (e) {
            debugPrint('解析行 $i 失败: $e');
          }
        }
      }
    } catch (e) {
      debugPrint('CSV 解析失败: $e');
    }

    return records;
  }

  /// 解析字节数据（用于 web 平台）
  static List<HealthRecord> parseBytes(Uint8List bytes) {
    final content = utf8.decode(bytes, allowMalformed: true);
    return parseCsv(content);
  }

  /// 将记录导出为 CSV 字符串
  static String exportToCsv(List<HealthRecord> records) {
    final List<List<dynamic>> rows = [
      ['testTime', 'indicatorName', 'indicatorValue', 'remark'],
      ...records.map((r) => [
            r.testTime.toIso8601String().split('T')[0],
            r.indicatorName,
            r.indicatorValue,
            r.remark ?? '',
          ]),
    ];
    return const ListToCsvConverter().convert(rows);
  }

  /// 将记录保存到 CSV 文件
  static Future<String> saveToCsvFile(List<HealthRecord> records) async {
    final csvString = exportToCsv(records);
    final dir = await getApplicationDocumentsDirectory();
    final filePath = '${dir.path}/ca199_data.csv';
    final file = File(filePath);
    await file.writeAsString(csvString);
    return filePath;
  }
}
