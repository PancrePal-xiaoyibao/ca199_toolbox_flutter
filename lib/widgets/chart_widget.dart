import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../models/record.dart';
import '../providers/records_provider.dart';
import '../theme/app_theme.dart';

/// 图表组件
class ChartWidget extends ConsumerStatefulWidget {
  final List<HealthRecord> records;
  final String indicatorName;

  const ChartWidget({
    super.key,
    required this.records,
    required this.indicatorName,
  });

  @override
  ConsumerState<ChartWidget> createState() => ChartWidgetState();
}

class ChartWidgetState extends ConsumerState<ChartWidget> {
  final GlobalKey _chartKey = GlobalKey();
  bool _isSaving = false;

  /// 获取保存时使用的直角装饰器（无圆角）
  BoxDecoration _getSaveDecoration() {
    return BoxDecoration(
      color: Colors.white,
      boxShadow: [
        BoxShadow(
          color: AppTheme.shadowColor.withValues(alpha: 0.08),
          offset: const Offset(0, 1),
          blurRadius: 2,
        ),
      ],
    );
  }

  /// 获取显示用的圆角装饰器
  BoxDecoration _getDisplayDecoration() {
    return FlatCardDecoration(
      color: Colors.white,
      elevation: 1,
    );
  }

  /// 获取分组信息
  IndicatorGroup? get _group => IndicatorGroup.findByName(widget.indicatorName);

  /// 过滤并排序记录（按时间升序，用于图表）
  List<HealthRecord> get _sortedRecords {
    final filtered = widget.records
        .where((r) => r.indicatorName == widget.indicatorName)
        .toList();
    filtered.sort((a, b) => a.testTime.compareTo(b.testTime));
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final records = _sortedRecords;
    final settings = ref.watch(indicatorSettingsProvider);

    if (records.isEmpty) {
      return _buildEmptyState();
    }

    // 获取有效范围（用户设置或默认值）
    final effectiveRange = IndicatorGroup.getEffectiveRange(
      widget.indicatorName,
      settings,
    );

    return Column(
      children: [
        // 图表区域
        Expanded(
          child: RepaintBoundary(
            key: _chartKey,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: _isSaving ? _getSaveDecoration() : _getDisplayDecoration(),
              child: _buildChart(records, effectiveRange),
            ),
          ),
        ),

        const SizedBox(height: 8),

        // 保存按钮
        _buildSaveButton(),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: FlatCardDecoration(color: Colors.white),
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.show_chart, size: 48, color: AppTheme.textHint),
            SizedBox(height: 16),
            Text(
              '暂无数据',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChart(List<HealthRecord> records, IndicatorRange? effectiveRange) {
    final group = _group;

    // 计算 Y 轴范围
    double minY = records.map((r) => r.indicatorValue).reduce((a, b) => a < b ? a : b);
    double maxY = records.map((r) => r.indicatorValue).reduce((a, b) => a > b ? a : b);

    // 添加边距
    final yMargin = (maxY - minY) * 0.1;
    minY = (minY - yMargin).clamp(0, double.infinity);
    maxY = maxY + yMargin;

    // 如果值都相同，添加一些边距
    if (minY == maxY) {
      minY = minY * 0.8;
      maxY = maxY * 1.2;
    }

    // 判断是否在正常范围内
    bool isInNormalRange(double value) {
      if (effectiveRange != null) {
        return value >= effectiveRange.normalMin && value <= effectiveRange.normalMax;
      }
      return group?.isNormal(value) ?? true;
    }

    // 获取正常范围
    final normalMin = effectiveRange?.normalMin ?? group?.normalMin ?? 0;
    final normalMax = effectiveRange?.normalMax ?? group?.normalMax ?? 100;

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: (maxY - minY) / 4,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: AppTheme.textHint.withValues(alpha: 0.2),
              strokeWidth: 1,
            );
          },
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 45,
              getTitlesWidget: (value, meta) {
                return Text(
                  value.toStringAsFixed(0),
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 10,
                  ),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              interval: records.length > 6 ? (records.length / 4).ceilToDouble() : 1,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= records.length) {
                  return const SizedBox.shrink();
                }
                final date = records[index].testTime;
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    '${date.month}/${date.day}',
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 10,
                    ),
                  ),
                );
              },
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        minX: 0,
        maxX: (records.length - 1).toDouble(),
        minY: minY,
        maxY: maxY,
        extraLinesData: (group != null || effectiveRange != null)
            ? ExtraLinesData(
                horizontalLines: [
                  // 正常范围上限
                  HorizontalLine(
                    y: normalMax,
                    color: AppTheme.successColor.withValues(alpha: 0.5),
                    strokeWidth: 1,
                    dashArray: [5, 5],
                  ),
                  // 正常范围下限
                  HorizontalLine(
                    y: normalMin,
                    color: AppTheme.successColor.withValues(alpha: 0.5),
                    strokeWidth: 1,
                    dashArray: [5, 5],
                  ),
                ],
              )
            : null,
        lineBarsData: [
          LineChartBarData(
            spots: records.asMap().entries.map((entry) {
              return FlSpot(entry.key.toDouble(), entry.value.indicatorValue);
            }).toList(),
            isCurved: true,
            curveSmoothness: 0.3,
            color: AppTheme.primaryColor,
            barWidth: 3,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) {
                final value = spot.y;
                final normal = isInNormalRange(value);
                return FlDotCirclePainter(
                  radius: 4,
                  color: normal ? AppTheme.primaryColor : AppTheme.dangerColor,
                  strokeWidth: 2,
                  strokeColor: Colors.white,
                );
              },
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppTheme.primaryColor.withValues(alpha: 0.3),
                  AppTheme.primaryColor.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        ],
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                final record = records[spot.x.toInt()];
                final dateStr =
                    '${record.testTime.year}-${record.testTime.month.toString().padLeft(2, '0')}-${record.testTime.day.toString().padLeft(2, '0')}';
                return LineTooltipItem(
                  '$dateStr\n${spot.y.toStringAsFixed(2)} ${group?.unit ?? ''}',
                  const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                );
              }).toList();
            },
          ),
        ),
      ),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _isSaving ? null : _saveImage,
        icon: _isSaving
            ? const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.save_alt, size: 16),
        label: Text(_isSaving ? '保存中...' : '保存图表'),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 8),
        ),
      ),
    );
  }

  /// 在图片底部添加检查项信息
  Future<Uint8List> _addInfoToImage(Uint8List originalBytes) async {
    // 解码原始图片
    final codec = await ui.instantiateImageCodec(originalBytes);
    final frame = await codec.getNextFrame();
    final originalImage = frame.image;

    // 获取指标信息
    final group = _group;
    final infoText = group != null
        ? '${group.displayName}  |  正常范围: ${group.normalMin} - ${group.normalMax} ${group.unit}'
        : widget.indicatorName;

    // 创建新的图片（原始高度 + 底部信息区域）
    const infoHeight = 50.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // 绘制原始图片
    canvas.drawImage(originalImage, Offset.zero, Paint());

    // 绘制底部信息背景
    final infoRect = Rect.fromLTWH(
      0,
      originalImage.height.toDouble(),
      originalImage.width.toDouble(),
      infoHeight,
    );
    canvas.drawRect(infoRect, Paint()..color = const Color(0xFFF5F5F5));

    // 绘制分割线
    canvas.drawLine(
      Offset(0, originalImage.height.toDouble()),
      Offset(originalImage.width.toDouble(), originalImage.height.toDouble()),
      Paint()
        ..color = const Color(0xFFE0E0E0)
        ..strokeWidth = 1,
    );

    // 绘制文字
    final textPainter = TextPainter(
      text: TextSpan(
        text: infoText,
        style: const TextStyle(
          color: Color(0xFF666666),
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout(maxWidth: originalImage.width.toDouble() - 32);
    textPainter.paint(
      canvas,
      Offset(
        16,
        originalImage.height.toDouble() + (infoHeight - textPainter.height) / 2,
      ),
    );

    // 完成绘制并转换为图片
    final picture = recorder.endRecording();
    final newImage = await picture.toImage(
      originalImage.width,
      originalImage.height + infoHeight.toInt(),
    );
    final newByteData = await newImage.toByteData(format: ui.ImageByteFormat.png);

    if (newByteData == null) {
      return originalBytes; // 如果失败，返回原始图片
    }

    return newByteData.buffer.asUint8List();
  }

  Future<void> _saveImage() async {
    setState(() => _isSaving = true);

    try {
      // 等待下一帧渲染完成
      await Future.delayed(const Duration(milliseconds: 100));

      final boundary = _chartKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;

      if (boundary == null) {
        throw Exception('无法获取图表渲染对象');
      }

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

      if (byteData == null) {
        throw Exception('无法生成图片数据');
      }

      // 添加检查项信息到图片
      final Uint8List pngBytes = await _addInfoToImage(byteData.buffer.asUint8List());
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'chart_${widget.indicatorName}_$timestamp.png';

      if (kIsWeb) {
        // Web 平台：使用下载方式
        // ignore: avoid_print
        print('Web 平台：图片已生成，大小 ${pngBytes.length} bytes');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('图片已生成（Web 下载功能开发中）')),
          );
        }
      } else if (Platform.isIOS || Platform.isAndroid) {
        // iOS/Android：保存到相册
        final tempDir = await getTemporaryDirectory();
        final filePath = '${tempDir.path}/$fileName';
        final file = File(filePath);
        await file.writeAsBytes(pngBytes);

        await Gal.putImage(filePath, album: 'CA199监测');
        // 清理临时文件
        await file.delete();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('图片已保存到相册'),
              backgroundColor: AppTheme.successColor,
            ),
          );
        }
      } else {
        // macOS/Windows：保存到下载文件夹
        Directory? downloadDir;

        if (Platform.isMacOS) {
          // macOS: 从环境变量获取下载目录
          final homeDir = Platform.environment['HOME'];
          if (homeDir != null) {
            downloadDir = Directory('$homeDir/Downloads');
          }
        } else if (Platform.isWindows) {
          // Windows: 从用户目录获取下载文件夹
          final userProfile = Platform.environment['USERPROFILE'];
          if (userProfile != null) {
            downloadDir = Directory('$userProfile\\Downloads');
          }
        }

        // 备用方案：使用应用文档目录
        downloadDir ??= await getApplicationDocumentsDirectory();

        if (!await downloadDir.exists()) {
          await downloadDir.create(recursive: true);
        }

        final filePath = '${downloadDir.path}/$fileName';
        final file = File(filePath);
        await file.writeAsBytes(pngBytes);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('图片已保存到: ${downloadDir.path}'),
              backgroundColor: AppTheme.successColor,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('保存图片失败: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('保存失败: $e'),
            backgroundColor: AppTheme.dangerColor,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }
}
