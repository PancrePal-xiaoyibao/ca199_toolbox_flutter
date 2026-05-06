import 'package:flutter/foundation.dart';

/// 指标范围设置
class IndicatorRange {
  final double normalMin;
  final double normalMax;

  const IndicatorRange({
    required this.normalMin,
    required this.normalMax,
  });

  Map<String, dynamic> toMap() => {
    'normalMin': normalMin,
    'normalMax': normalMax,
  };

  factory IndicatorRange.fromMap(Map<String, dynamic> map) {
    return IndicatorRange(
      normalMin: (map['normalMin'] as num).toDouble(),
      normalMax: (map['normalMax'] as num).toDouble(),
    );
  }
}

/// 健康记录数据模型
@immutable
class HealthRecord {
  final int? id;
  final DateTime testTime;
  final String indicatorName;
  final double indicatorValue;
  final String? remark;

  const HealthRecord({
    this.id,
    required this.testTime,
    required this.indicatorName,
    required this.indicatorValue,
    this.remark,
  });

  /// 从 CSV 行创建记录
  factory HealthRecord.fromCsv(List<dynamic> row) {
    return HealthRecord(
      testTime: DateTime.parse(row[0].toString()),
      indicatorName: row[1].toString(),
      indicatorValue: double.tryParse(row[2].toString()) ?? 0.0,
      remark: row.length > 3 ? row[3]?.toString() : null,
    );
  }

  /// 复制并修改
  HealthRecord copyWith({
    int? id,
    DateTime? testTime,
    String? indicatorName,
    double? indicatorValue,
    String? remark,
  }) {
    return HealthRecord(
      id: id ?? this.id,
      testTime: testTime ?? this.testTime,
      indicatorName: indicatorName ?? this.indicatorName,
      indicatorValue: indicatorValue ?? this.indicatorValue,
      remark: remark ?? this.remark,
    );
  }

  /// 转为 Map（用于数据库存储）
  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'testTime': testTime.toIso8601String(),
      'indicatorName': indicatorName,
      'indicatorValue': indicatorValue,
      if (remark != null) 'remark': remark,
    };
  }

  /// 从 Map 创建
  factory HealthRecord.fromMap(Map<String, dynamic> map) {
    return HealthRecord(
      id: map['id'] as int?,
      testTime: DateTime.parse(map['testTime'] as String),
      indicatorName: map['indicatorName'] as String,
      indicatorValue: (map['indicatorValue'] as num).toDouble(),
      remark: map['remark'] as String?,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HealthRecord &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          testTime == other.testTime &&
          indicatorName == other.indicatorName &&
          indicatorValue == other.indicatorValue &&
          remark == other.remark;

  @override
  int get hashCode =>
      id.hashCode ^
      testTime.hashCode ^
      indicatorName.hashCode ^
      indicatorValue.hashCode ^
      remark.hashCode;

  @override
  String toString() =>
      'HealthRecord(id: $id, testTime: $testTime, indicatorName: $indicatorName, indicatorValue: $indicatorValue, remark: $remark)';
}

/// 指标分组（用于分类显示）
class IndicatorGroup {
  final String name;
  final String displayName;
  final double normalMin;
  final double normalMax;
  final String unit;

  const IndicatorGroup({
    required this.name,
    required this.displayName,
    required this.normalMin,
    required this.normalMax,
    required this.unit,
  });

  /// 获取指标的有效范围（优先使用用户设置）
  static IndicatorRange? getEffectiveRange(String name, Map<String, IndicatorRange>? settings) {
    final group = findByName(name);
    if (group == null) {
      if (settings != null && settings.containsKey(name)) {
        return settings[name];
      }
      return null;
    }

    if (settings != null && settings.containsKey(name)) {
      return settings[name];
    }

    return IndicatorRange(
      normalMin: group.normalMin,
      normalMax: group.normalMax,
    );
  }

  /// 预定义的指标分组
  static const List<IndicatorGroup> presets = [
    IndicatorGroup(
      name: 'ALT',
      displayName: '谷丙转氨酶 (ALT)',
      normalMin: 9,
      normalMax: 50,
      unit: 'U/L',
    ),
    IndicatorGroup(
      name: 'AST',
      displayName: '谷草转氨酶 (AST)',
      normalMin: 15,
      normalMax: 40,
      unit: 'U/L',
    ),
    IndicatorGroup(
      name: 'ALP',
      displayName: '碱性磷酸酶 (ALP)',
      normalMin: 45,
      normalMax: 125,
      unit: 'U/L',
    ),
    IndicatorGroup(
      name: '尿酸',
      displayName: '尿酸 (UA)',
      normalMin: 208,
      normalMax: 428,
      unit: 'μmol/L',
    ),
    IndicatorGroup(
      name: '肌酐',
      displayName: '肌酐 (Cr)',
      normalMin: 57,
      normalMax: 111,
      unit: 'μmol/L',
    ),
    IndicatorGroup(
      name: '血糖',
      displayName: '空腹血糖 (GLU)',
      normalMin: 3.9,
      normalMax: 6.1,
      unit: 'mmol/L',
    ),
    IndicatorGroup(
      name: '总胆红素',
      displayName: '总胆红素 (TBIL)',
      normalMin: 5.1,
      normalMax: 22.2,
      unit: 'μmol/L',
    ),
    IndicatorGroup(
      name: '甘油三酯',
      displayName: '甘油三酯 (TG)',
      normalMin: 0.0,
      normalMax: 1.7,
      unit: 'mmol/L',
    ),
    IndicatorGroup(
      name: '胆固醇',
      displayName: '总胆固醇 (TC)',
      normalMin: 2.85,
      normalMax: 5.7,
      unit: 'mmol/L',
    ),
    IndicatorGroup(
      name: 'CA199',
      displayName: 'CA199 肿瘤标志物',
      normalMin: 0,
      normalMax: 37,
      unit: 'U/mL',
    ),
    IndicatorGroup(
      name: '白蛋白',
      displayName: '白蛋白 (ALB)',
      normalMin: 35,
      normalMax: 52,
      unit: 'g/L',
    ),
    IndicatorGroup(
      name: '血红蛋白',
      displayName: '血红蛋白 (HGB)',
      normalMin: 115,
      normalMax: 175,
      unit: 'g/L',
    ),
    IndicatorGroup(
      name: 'C反应蛋白',
      displayName: 'C反应蛋白 (CRP)',
      normalMin: 0,
      normalMax: 10,
      unit: 'mg/L',
    ),
    IndicatorGroup(
      name: '体重',
      displayName: '体重',
      normalMin: 0,
      normalMax: 200,
      unit: 'kg',
    ),
  ];

  /// 根据指标名称查找分组
  static IndicatorGroup? findByName(String name) {
    try {
      return presets.firstWhere((g) => g.name == name);
    } catch (_) {
      return null;
    }
  }

  /// 判断值是否在正常范围
  bool isNormal(double value) => value >= normalMin && value <= normalMax;

  /// 计算偏离正常范围的程度
  double deviationLevel(double value) {
    if (value < normalMin) {
      return (normalMin - value) / normalMin;
    } else if (value > normalMax) {
      return (value - normalMax) / normalMax;
    }
    return 0;
  }
}
