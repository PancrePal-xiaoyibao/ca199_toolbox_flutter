import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/record.dart';

/// 本地数据库服务（支持除 Web 外的全平台）
/// Web 平台使用 localStorage 替代
class DatabaseService {
  static Database? _database;
  static const String _tableName = 'health_records';

  /// 获取数据库实例
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  /// 初始化数据库
  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'ca199_toolbox.db');

    return openDatabase(
      path,
      version: 2,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $_tableName (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            testTime TEXT NOT NULL,
            indicatorName TEXT NOT NULL,
            indicatorValue REAL NOT NULL,
            remark TEXT
          )
        ''');

        // 创建索引以加速查询
        await db.execute('''
          CREATE INDEX idx_indicator ON $_tableName (indicatorName)
        ''');
        await db.execute('''
          CREATE INDEX idx_time ON $_tableName (testTime)
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          // 添加 remark 列
          await db.execute('ALTER TABLE $_tableName ADD COLUMN remark TEXT');
        }
      },
    );
  }

  /// 批量插入记录
  Future<void> insertRecords(List<HealthRecord> records) async {
    final db = await database;
    final batch = db.batch();

    for (final record in records) {
      batch.insert(
        _tableName,
        {
          'testTime': record.testTime.toIso8601String(),
          'indicatorName': record.indicatorName,
          'indicatorValue': record.indicatorValue,
          if (record.remark != null) 'remark': record.remark,
        },
      );
    }

    await batch.commit(noResult: true);
  }

  /// 清空所有记录
  Future<void> clearAll() async {
    final db = await database;
    await db.delete(_tableName);
  }

  /// 获取所有记录
  Future<List<HealthRecord>> getAllRecords() async {
    final db = await database;
    final maps = await db.query(
      _tableName,
      orderBy: 'testTime DESC, indicatorName ASC',
    );
    return maps.map((m) => HealthRecord.fromMap(m)).toList();
  }

  /// 按指标名称获取记录
  Future<List<HealthRecord>> getRecordsByIndicator(String indicatorName) async {
    final db = await database;
    final maps = await db.query(
      _tableName,
      where: 'indicatorName = ?',
      whereArgs: [indicatorName],
      orderBy: 'testTime DESC',
    );
    return maps.map((m) => HealthRecord.fromMap(m)).toList();
  }

  /// 分页获取记录
  Future<List<HealthRecord>> getRecordsPaginated({
    required int page,
    required int pageSize,
    String? indicatorName,
  }) async {
    final db = await database;
    final offset = (page - 1) * pageSize;

    final maps = await db.query(
      _tableName,
      where: indicatorName != null ? 'indicatorName = ?' : null,
      whereArgs: indicatorName != null ? [indicatorName] : null,
      orderBy: 'testTime DESC, indicatorName ASC',
      limit: pageSize,
      offset: offset,
    );

    return maps.map((m) => HealthRecord.fromMap(m)).toList();
  }

  /// 获取记录总数
  Future<int> getTotalCount({String? indicatorName}) async {
    final db = await database;
    final result = await db.rawQuery(
      indicatorName != null
          ? 'SELECT COUNT(*) as count FROM $_tableName WHERE indicatorName = ?'
          : 'SELECT COUNT(*) as count FROM $_tableName',
      indicatorName != null ? [indicatorName] : null,
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// 更新记录
  Future<void> updateRecord(HealthRecord record) async {
    if (record.id == null) return;
    final db = await database;
    final data = record.toMap();
    // 移除 id，因为 WHERE 子句会处理它
    data.remove('id');
    await db.update(
      _tableName,
      data,
      where: 'id = ?',
      whereArgs: [record.id],
    );
  }

  /// 删除记录
  Future<void> deleteRecord(int id) async {
    final db = await database;
    await db.delete(
      _tableName,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// 获取所有指标名称
  Future<List<String>> getAllIndicatorNames() async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT DISTINCT indicatorName FROM $_tableName ORDER BY indicatorName',
    );
    return result.map((r) => r['indicatorName'] as String).toList();
  }

  /// 关闭数据库
  Future<void> close() async {
    final db = await database;
    await db.close();
    _database = null;
  }
}
