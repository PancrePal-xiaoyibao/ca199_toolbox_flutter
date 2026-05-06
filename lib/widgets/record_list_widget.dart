import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/record.dart';
import '../providers/records_provider.dart';
import '../theme/app_theme.dart';

/// 分页记录列表组件
class RecordListWidget extends ConsumerStatefulWidget {
  const RecordListWidget({super.key});

  @override
  ConsumerState<RecordListWidget> createState() => _RecordListWidgetState();
}

class _RecordListWidgetState extends ConsumerState<RecordListWidget> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pagination = ref.watch(paginationProvider);
    final selectedRecord = ref.watch(selectedRecordProvider);

    // 监听分页记录
    final paginatedAsync = ref.watch(paginatedRecordsProvider);
    final totalAsync = ref.watch(totalRecordsProvider);

    return Column(
      children: [
        // 列表头部
        _buildListHeader(),
        const SizedBox(height: 4),

        // 列表内容
        Expanded(
          child: paginatedAsync.when(
            data: (records) {
              if (records.isEmpty) {
                return _buildEmptyState();
              }

              return ListView.builder(
                controller: _scrollController,
                padding: EdgeInsets.zero,
                itemCount: records.length,
                itemBuilder: (context, index) {
                  final record = records[index];
                  final isSelected = selectedRecord?.id == record.id;

                  return _buildRecordItem(record, isSelected, index);
                },
              );
            },
            loading: () => const Center(
              child: CircularProgressIndicator(),
            ),
            error: (e, _) => Center(
              child: Text('加载失败: $e'),
            ),
          ),
        ),

        const SizedBox(height: 4),

        // 分页控件
        totalAsync.when(
          data: (total) {
            final totalPages = (total / pagination.pageSize).ceil();
            if (totalPages <= 1) return const SizedBox.shrink();

            return _buildPagination(totalPages, pagination.page);
          },
          loading: () => const SizedBox.shrink(),
          error: (e, s) => const SizedBox.shrink(),
        ),
      ],
    );
  }

  Widget _buildListHeader() {
    final pagination = ref.watch(paginationProvider);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.backgroundColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          const Expanded(
            flex: 2,
            child: Text(
              '日期',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
          const Expanded(
            flex: 2,
            child: Text(
              '指标',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
          const Expanded(
            child: Text(
              '数值',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 32), // 状态图标占位

          // 分页条数选择器
          _buildPageSizeSelector(pagination.pageSize),
        ],
      ),
    );
  }

  Widget _buildPageSizeSelector(int currentSize) {
    return DropdownButtonHideUnderline(
      child: DropdownButton<int>(
        value: currentSize,
        isDense: true,
        style: const TextStyle(
          fontSize: 11,
          color: AppTheme.textSecondary,
        ),
        items: kPageSizeOptions.map((size) {
          return DropdownMenuItem(
            value: size,
            child: Text('$size条/页'),
          );
        }).toList(),
        onChanged: (newSize) {
          if (newSize != null) {
            ref.read(paginationProvider.notifier).state =
                PaginationState(page: 1, pageSize: newSize);
          }
        },
      ),
    );
  }

  Widget _buildRecordItem(HealthRecord record, bool isSelected, int index) {
    final group = IndicatorGroup.findByName(record.indicatorName);
    final isNormal = group?.isNormal(record.indicatorValue) ?? true;
    final dateFormat = DateFormat('yyyy-MM-dd');

    return GestureDetector(
      onTap: () => _selectRecord(record),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.symmetric(vertical: 1),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryColor.withValues(alpha: 0.1)
              : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: isSelected
              ? Border.all(color: AppTheme.primaryColor, width: 1.5)
              : null,
          boxShadow: [
            BoxShadow(
              color: AppTheme.shadowColor.withValues(alpha: isSelected ? 0.1 : 0.03),
              offset: const Offset(0, 1),
              blurRadius: 2,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Text(
                    dateFormat.format(record.testTime),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    group?.displayName ?? record.indicatorName,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppTheme.textSecondary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        record.indicatorValue.toStringAsFixed(1),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isNormal
                              ? AppTheme.textPrimary
                              : AppTheme.dangerColor,
                        ),
                      ),
                      if (group != null)
                        Text(
                          group.unit,
                          style: const TextStyle(
                            fontSize: 9,
                            color: AppTheme.textHint,
                          ),
                        ),
                    ],
                  ),
                ),
                SizedBox(
                  width: 32,
                  child: Icon(
                    isNormal ? Icons.check_circle : Icons.warning,
                    size: 16,
                    color: isNormal ? AppTheme.successColor : AppTheme.warningColor,
                  ),
                ),
              ],
            ),
            // 显示备注
            _buildRecordRemark(record),
          ],
        ),
      ),
    );
  }

  Widget _buildRecordRemark(HealthRecord record) {
    if (record.remark == null || record.remark!.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.note, size: 12, color: AppTheme.primaryColor),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              record.remark!,
              style: const TextStyle(
                fontSize: 11,
                color: AppTheme.textSecondary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
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
            size: 48,
            color: AppTheme.textHint.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          const Text(
            '暂无数据',
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '请先导入 CSV 文件',
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.textHint,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPagination(int totalPages, int currentPage) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 上一页
          IconButton(
            onPressed: currentPage > 1
                ? () => _goToPage(currentPage - 1)
                : null,
            icon: const Icon(Icons.chevron_left, size: 20),
            color: AppTheme.primaryColor,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),

          // 页码
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              '$currentPage / $totalPages',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
          ),

          // 下一页
          IconButton(
            onPressed: currentPage < totalPages
                ? () => _goToPage(currentPage + 1)
                : null,
            icon: const Icon(Icons.chevron_right, size: 20),
            color: AppTheme.primaryColor,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  void _selectRecord(HealthRecord record) {
    final current = ref.read(selectedRecordProvider);
    if (current?.id == record.id) {
      // 取消选中
      ref.read(selectedRecordProvider.notifier).state = null;
    } else {
      // 选中
      ref.read(selectedRecordProvider.notifier).state = record;
    }
  }

  void _goToPage(int page) {
    ref.read(paginationProvider.notifier).state =
        ref.read(paginationProvider).copyWith(page: page);
  }
}
