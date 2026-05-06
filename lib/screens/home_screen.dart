import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/record.dart';
import '../providers/records_provider.dart';
import '../theme/app_theme.dart';

/// 首页：文件导入
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _isImporting = false;
  String? _errorMessage;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Logo / 图标
              Container(
                width: 120,
                height: 120,
                decoration: NeumorphicDecoration(
                  borderRadius: 30,
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                ),
                child: const Icon(
                  Icons.health_and_safety_outlined,
                  size: 60,
                  color: AppTheme.primaryColor,
                ),
              ),
              const SizedBox(height: 32),

              // 标题
              const Text(
                'CA199 健康指标监测',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '导入您的健康数据，开始监测',
                style: TextStyle(
                  fontSize: 14,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 48),

              // 导入按钮
              _buildImportButton(),
              const SizedBox(height: 16),

              // 设置按钮
              _buildSettingsButton(),

              // 错误提示
              if (_errorMessage != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.dangerColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline,
                          color: AppTheme.dangerColor, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(
                            color: AppTheme.dangerColor,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 48),

              // 数据统计预览
              _buildDataPreview(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImportButton() {
    return GestureDetector(
      onTap: _isImporting ? null : _handleImport,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: NeumorphicDecoration(
          borderRadius: 16,
          color: _isImporting
              ? AppTheme.primaryColor.withValues(alpha: 0.5)
              : AppTheme.primaryColor,
        ),
        child: Center(
          child: _isImporting
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.upload_file, color: Colors.white),
                    SizedBox(width: 8),
                    Text(
                      '导入 CSV 文件',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildSettingsButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () => _showSettingsDialog(),
        icon: const Icon(Icons.settings_outlined),
        label: const Text('设置'),
      ),
    );
  }

  void _showSettingsDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _SettingsSheet(),
    );
  }

  Widget _buildDataPreview() {
    final recordsAsync = ref.watch(allRecordsProvider);

    return recordsAsync.when(
      data: (records) {
        if (records.isEmpty) {
          return const SizedBox.shrink();
        }

        // 统计指标数量
        final indicatorCount = records.map((r) => r.indicatorName).toSet().length;
        final dateRange = records.length > 1
            ? '${records.last.testTime.toString().split(' ')[0]} ~ ${records.first.testTime.toString().split(' ')[0]}'
            : records.first.testTime.toString().split(' ')[0];

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: FlatCardDecoration(
            color: AppTheme.backgroundColor,
            elevation: 1,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '已导入数据',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatItem('记录数', '${records.length}'),
                  _buildStatItem('指标数', '$indicatorCount'),
                  _buildStatItem('时间范围', dateRange),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => context.go('/data'),
                  icon: const Icon(Icons.arrow_forward),
                  label: const Text('查看数据'),
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppTheme.primaryColor,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppTheme.textSecondary,
          ),
        ),
      ],
    );
  }

  Future<void> _handleImport() async {
    setState(() {
      _isImporting = true;
      _errorMessage = null;
    });

    try {
      await ref.read(allRecordsProvider.notifier).importFromCsv();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('导入成功'),
            backgroundColor: AppTheme.successColor,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = '导入失败: ${e.toString()}';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isImporting = false;
        });
      }
    }
  }
}

/// 设置页面底部弹窗
class _SettingsSheet extends ConsumerStatefulWidget {
  @override
  ConsumerState<_SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends ConsumerState<_SettingsSheet> {
  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // 顶部拖动条和标题
            Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    '指标正常范围设置',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // 说明
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: AppTheme.primaryColor.withValues(alpha: 0.1),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: AppTheme.primaryColor),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '设置各指标的正常值范围，超出范围的数据将显示警告',
                      style: TextStyle(fontSize: 12, color: AppTheme.primaryColor),
                    ),
                  ),
                ],
              ),
            ),

            // 指标列表
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: IndicatorGroup.presets.length,
                itemBuilder: (context, index) {
                  final group = IndicatorGroup.presets[index];
                  return _buildIndicatorSetting(group);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIndicatorSetting(IndicatorGroup group) {
    final settings = ref.watch(indicatorSettingsProvider);
    final currentMin = settings.containsKey(group.name)
        ? settings[group.name]!.normalMin
        : group.normalMin;
    final currentMax = settings.containsKey(group.name)
        ? settings[group.name]!.normalMax
        : group.normalMax;
    final isCustom = settings.containsKey(group.name);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCustom ? AppTheme.primaryColor : Colors.grey[200]!,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 指标名称
          Row(
            children: [
              Expanded(
                child: Text(
                  group.displayName,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              if (isCustom)
                GestureDetector(
                  onTap: () => _resetToDefault(group.name),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      '重置',
                      style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // 范围输入
          Row(
            children: [
              const Text('最小值:', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
              const SizedBox(width: 8),
              SizedBox(
                width: 80,
                child: TextField(
                  controller: TextEditingController(text: currentMin.toString()),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    isDense: true,
                  ),
                  style: const TextStyle(fontSize: 14),
                  onChanged: (value) => _updateMin(group.name, value),
                ),
              ),
              const SizedBox(width: 16),
              const Text('最大值:', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
              const SizedBox(width: 8),
              SizedBox(
                width: 80,
                child: TextField(
                  controller: TextEditingController(text: currentMax.toString()),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    isDense: true,
                  ),
                  style: const TextStyle(fontSize: 14),
                  onChanged: (value) => _updateMax(group.name, value),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                group.unit,
                style: const TextStyle(fontSize: 12, color: AppTheme.textHint),
              ),
            ],
          ),

          // 原始值提示
          if (!isCustom)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '默认值: ${group.normalMin} - ${group.normalMax} ${group.unit}',
                style: TextStyle(fontSize: 11, color: Colors.grey[500]),
              ),
            ),
        ],
      ),
    );
  }

  void _updateMin(String name, String value) {
    final settings = Map<String, IndicatorRange>.from(
      ref.read(indicatorSettingsProvider),
    );
    final group = IndicatorGroup.findByName(name);
    if (group == null) return;

    final current = settings[name] ?? IndicatorRange(
      normalMin: group.normalMin,
      normalMax: group.normalMax,
    );

    final minValue = double.tryParse(value);
    if (minValue != null) {
      settings[name] = IndicatorRange(
        normalMin: minValue,
        normalMax: current.normalMax,
      );
      ref.read(indicatorSettingsProvider.notifier).updateSettings(settings);
    }
  }

  void _updateMax(String name, String value) {
    final settings = Map<String, IndicatorRange>.from(
      ref.read(indicatorSettingsProvider),
    );
    final group = IndicatorGroup.findByName(name);
    if (group == null) return;

    final current = settings[name] ?? IndicatorRange(
      normalMin: group.normalMin,
      normalMax: group.normalMax,
    );

    final maxValue = double.tryParse(value);
    if (maxValue != null) {
      settings[name] = IndicatorRange(
        normalMin: current.normalMin,
        normalMax: maxValue,
      );
      ref.read(indicatorSettingsProvider.notifier).updateSettings(settings);
    }
  }

  void _resetToDefault(String name) {
    final settings = Map<String, IndicatorRange>.from(
      ref.read(indicatorSettingsProvider),
    );
    settings.remove(name);
    ref.read(indicatorSettingsProvider.notifier).updateSettings(settings);
  }
}
