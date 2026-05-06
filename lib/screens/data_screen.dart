import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/record.dart';
import '../providers/records_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/chart_widget.dart';
import '../widgets/record_list_widget.dart';
import '../widgets/toolbar_widget.dart';

/// 数据页面：图表 + 列表 + 工具栏
class DataScreen extends ConsumerStatefulWidget {
  const DataScreen({super.key});

  @override
  ConsumerState<DataScreen> createState() => _DataScreenState();
}

class _DataScreenState extends ConsumerState<DataScreen> {
  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final allRecordsAsync = ref.watch(allRecordsProvider);
    final selectedIndicator = ref.watch(selectedIndicatorProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('健康数据'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(allRecordsProvider.notifier).refresh(),
          ),
        ],
      ),
      body: allRecordsAsync.when(
        data: (records) {
          if (records.isEmpty) {
            return _buildEmptyState();
          }

          // 获取所有指标名称
          final indicatorNames =
              records.map((r) => r.indicatorName).toSet().toList()..sort();

          // 如果没有选中指标，自动选中第一个
          if (selectedIndicator == null && indicatorNames.isNotEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              ref.read(selectedIndicatorProvider.notifier).state =
                  indicatorNames.first;
            });
          }

          // 获取当前选中指标的分页数据（用于图表和列表）
          final paginatedAsync = ref.watch(paginatedRecordsProvider);
          final paginatedRecords = paginatedAsync.value ?? [];

          return SafeArea(
            child: Column(
              children: [
                // 图表区域
                _buildChartSection(records, indicatorNames, paginatedRecords, selectedIndicator),

                const SizedBox(height: 8),

                // 列表区域
                const Expanded(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: RecordListWidget(),
                  ),
                ),

                // 底部工具栏
                const ToolbarWidget(),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline,
                  size: 48, color: AppTheme.dangerColor),
              const SizedBox(height: 16),
              Text('加载失败: $e'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.inbox_outlined,
            size: 64,
            color: AppTheme.textHint.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          const Text(
            '暂无数据',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '请先在首页导入 CSV 文件',
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChartSection(
      List<HealthRecord> records,
      List<String> indicatorNames,
      List<HealthRecord> paginatedRecords,
      String? selectedIndicator) {
    if (indicatorNames.isEmpty) {
      return const SizedBox.shrink();
    }

    // 根据当前选中的指标筛选数据（与列表同步）
    List<HealthRecord> chartRecords = [];
    if (selectedIndicator != null) {
      // 使用分页数据中该指标的数据（与列表同步）
      chartRecords = paginatedRecords
          .where((r) => r.indicatorName == selectedIndicator)
          .toList();

      // 如果分页数据为空，则从全部数据中获取（首次加载时）
      if (chartRecords.isEmpty) {
        chartRecords = records
            .where((r) => r.indicatorName == selectedIndicator)
            .toList()
          ..sort((a, b) => a.testTime.compareTo(b.testTime));
      }
    }

    return Column(
      children: [
        // 指标选择器
        _buildIndicatorSelector(indicatorNames, selectedIndicator),

        // 图表
        SizedBox(
          height: 200,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: ChartWidget(
              key: ValueKey('chart_${selectedIndicator}_${chartRecords.length}'),
              records: chartRecords,
              indicatorName: selectedIndicator ?? '',
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildIndicatorSelector(List<String> indicatorNames, String? selectedIndicator) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: indicatorNames.map((name) {
            final group = IndicatorGroup.findByName(name);
            final isSelected = selectedIndicator == name;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () {
                  ref.read(selectedIndicatorProvider.notifier).state = name;
                  ref.read(paginationProvider.notifier).state =
                      ref.read(paginationProvider).copyWith(page: 1);
                  ref.read(selectedRecordProvider.notifier).state = null;
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSelected ? AppTheme.primaryColor : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.shadowColor.withValues(alpha: isSelected ? 0.15 : 0.05),
                        offset: const Offset(0, 1),
                        blurRadius: 2,
                      ),
                    ],
                  ),
                  child: Text(
                    group?.displayName ?? name,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      color: isSelected ? Colors.white : AppTheme.textSecondary,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
