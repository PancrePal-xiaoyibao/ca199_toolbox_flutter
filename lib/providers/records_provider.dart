import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/record.dart';
import '../services/csv_service.dart';
import '../services/database_service.dart';

/// 数据库服务 Provider

/// 数据库服务 Provider
final databaseServiceProvider = Provider<DatabaseService>((ref) {
  return DatabaseService();
});

/// 所有记录 Provider
final allRecordsProvider =
    StateNotifierProvider<RecordsNotifier, AsyncValue<List<HealthRecord>>>(
        (ref) {
  return RecordsNotifier(ref.watch(databaseServiceProvider));
});

/// 当前选中的指标名称
final selectedIndicatorProvider = StateProvider<String?>((ref) => null);

/// 当前选中的记录（用于修改/删除）
final selectedRecordProvider = StateProvider<HealthRecord?>((ref) => null);

/// 分页状态
final paginationProvider = StateProvider<PaginationState>((ref) {
  return const PaginationState(page: 1, pageSize: 20);
});

/// 分页状态类
class PaginationState {
  final int page;
  final int pageSize;

  const PaginationState({
    required this.page,
    required this.pageSize,
  });

  int get offset => (page - 1) * pageSize;

  PaginationState copyWith({int? page, int? pageSize}) {
    return PaginationState(
      page: page ?? this.page,
      pageSize: pageSize ?? this.pageSize,
    );
  }

  @override
  String toString() => 'PaginationState(page: $page, pageSize: $pageSize)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PaginationState &&
          page == other.page &&
          pageSize == other.pageSize;

  @override
  int get hashCode => Object.hash(page, pageSize);
}

/// 可用的分页大小选项
const List<int> kPageSizeOptions = [10, 20, 50, 100];

/// 指标设置 Provider
final indicatorSettingsProvider =
    StateNotifierProvider<IndicatorSettingsNotifier, Map<String, IndicatorRange>>((ref) {
  return IndicatorSettingsNotifier();
});

/// 指标设置管理
class IndicatorSettingsNotifier extends StateNotifier<Map<String, IndicatorRange>> {
  IndicatorSettingsNotifier() : super({}) {
    _loadSettings();
  }

  /// 获取设置文件路径
  Future<File> _getSettingsFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/indicator_settings.json');
  }

  /// 从本地存储加载设置
  Future<void> _loadSettings() async {
    try {
      final file = await _getSettingsFile();
      if (await file.exists()) {
        final content = await file.readAsString();
        final Map<String, dynamic> decoded = jsonDecode(content);
        final settings = decoded.map((key, value) =>
            MapEntry(key, IndicatorRange.fromMap(value)));
        state = settings;
      }
    } catch (e) {
      debugPrint('加载指标设置失败: $e');
    }
  }

  /// 更新设置
  Future<void> updateSettings(Map<String, IndicatorRange> settings) async {
    try {
      state = settings;

      final file = await _getSettingsFile();
      final encoded = settings.map((key, value) =>
          MapEntry(key, value.toMap()));
      await file.writeAsString(jsonEncode(encoded));
    } catch (e) {
      debugPrint('保存指标设置失败: $e');
    }
  }
}

/// 过滤后的记录（根据选中的指标名称）
final filteredRecordsProvider =
    FutureProvider<List<HealthRecord>>((ref) async {
  final recordsAsync = ref.watch(allRecordsProvider);
  final selectedIndicator = ref.watch(selectedIndicatorProvider);

  return recordsAsync.when(
    data: (records) {
      if (selectedIndicator == null) return records;
      return records
          .where((r) => r.indicatorName == selectedIndicator)
          .toList();
    },
    loading: () => [],
    error: (_, _) => [],
  );
});

/// 分页记录 Provider
final paginatedRecordsProvider =
    FutureProvider<List<HealthRecord>>((ref) async {
  // 监听 allRecordsProvider，当数据变化时自动刷新
  final _ = ref.watch(allRecordsProvider);
  final dbService = ref.watch(databaseServiceProvider);
  final pagination = ref.watch(paginationProvider);
  final selectedIndicator = ref.watch(selectedIndicatorProvider);

  return dbService.getRecordsPaginated(
    page: pagination.page,
    pageSize: pagination.pageSize,
    indicatorName: selectedIndicator,
  );
});

/// 记录总数 Provider
final totalRecordsProvider = FutureProvider<int>((ref) async {
  // 监听 allRecordsProvider，当数据变化时自动刷新
  final _ = ref.watch(allRecordsProvider);
  final dbService = ref.watch(databaseServiceProvider);
  final selectedIndicator = ref.watch(selectedIndicatorProvider);
  return dbService.getTotalCount(indicatorName: selectedIndicator);
});

/// 所有指标名称 Provider
final indicatorNamesProvider = FutureProvider<List<String>>((ref) async {
  // 监听 allRecordsProvider，当数据变化时自动刷新
  ref.watch(allRecordsProvider);
  final dbService = ref.watch(databaseServiceProvider);
  return dbService.getAllIndicatorNames();
});

/// 记录管理 Notifier
class RecordsNotifier extends StateNotifier<AsyncValue<List<HealthRecord>>> {
  final DatabaseService _dbService;
  bool _hasImportedData = false;

  RecordsNotifier(this._dbService) : super(const AsyncValue.loading()) {
    _loadRecords(syncCsv: false);
  }

  /// 从数据库加载记录
  Future<void> _loadRecords({bool syncCsv = true}) async {
    try {
      state = const AsyncValue.loading();
      final records = await _dbService.getAllRecords();
      state = AsyncValue.data(records);
      // 导入数据后才自动同步CSV
      if (syncCsv && _hasImportedData && records.isNotEmpty) {
        await _exportToCsv(records);
      }
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// 导出CSV文件到应用文档目录
  Future<String?> _exportToCsv(List<HealthRecord> records) async {
    try {
      final filePath = await CsvService.saveToCsvFile(records);
      debugPrint('CSV已保存到: $filePath');
      return filePath;
    } catch (e) {
      debugPrint('导出CSV失败: $e');
      return null;
    }
  }

  /// 从 CSV 文件导入
  Future<void> importFromCsv() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        withData: true, // 支持 web
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        Uint8List? bytes;

        if (kIsWeb) {
          bytes = file.bytes;
        } else {
          // 非 web 平台从路径读取
          if (file.path != null) {
            // 使用默认方式（已在 withData 中获取）
          }
          bytes = file.bytes;
        }

        if (bytes != null) {
          await _importFromBytes(bytes);
        }
      }
    } catch (e) {
      debugPrint('导入 CSV 失败: $e');
      rethrow;
    }
  }

  /// 从字节数据导入
  Future<void> _importFromBytes(Uint8List bytes) async {
    try {
      // 解析 CSV
      final records = CsvService.parseBytes(bytes);

      if (records.isEmpty) {
        throw Exception('未能解析到有效数据');
      }

      // 清空旧数据
      await _dbService.clearAll();

      // 插入新数据
      await _dbService.insertRecords(records);

      // 标记已导入数据
      _hasImportedData = true;

      // 重新加载
      await _loadRecords(syncCsv: true);
    } catch (e) {
      debugPrint('解析 CSV 失败: $e');
      rethrow;
    }
  }

  /// 添加记录
  Future<void> addRecord(HealthRecord record) async {
    try {
      await _dbService.insertRecords([record]);
      await _loadRecords();
    } catch (e) {
      debugPrint('添加记录失败: $e');
      rethrow;
    }
  }

  /// 更新记录
  Future<void> updateRecord(HealthRecord record) async {
    try {
      await _dbService.updateRecord(record);
      await _loadRecords();
    } catch (e) {
      debugPrint('更新记录失败: $e');
      rethrow;
    }
  }

  /// 删除记录
  Future<void> deleteRecord(int id) async {
    try {
      await _dbService.deleteRecord(id);
      await _loadRecords();
    } catch (e) {
      debugPrint('删除记录失败: $e');
      rethrow;
    }
  }

  /// 刷新数据
  Future<void> refresh() async {
    await _loadRecords();
  }
}
