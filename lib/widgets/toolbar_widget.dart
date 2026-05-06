import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/record.dart';
import '../providers/records_provider.dart';
import '../theme/app_theme.dart';

/// 底部操作工具栏
class ToolbarWidget extends ConsumerWidget {
  const ToolbarWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedRecord = ref.watch(selectedRecordProvider);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: AppTheme.shadowColor.withValues(alpha: 0.1),
            offset: const Offset(0, -2),
            blurRadius: 8,
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // 新增按钮
            Expanded(
              child: _ToolbarButton(
                icon: Icons.add,
                label: '新增',
                color: AppTheme.primaryColor,
                onPressed: () => _showAddDialog(context, ref),
              ),
            ),
            const SizedBox(width: 12),

            // 修改按钮
            Expanded(
              child: _ToolbarButton(
                icon: Icons.edit_outlined,
                label: '修改',
                color: selectedRecord != null
                    ? AppTheme.warningColor
                    : AppTheme.textHint,
                enabled: selectedRecord != null,
                onPressed: selectedRecord != null
                    ? () => _showEditDialog(context, ref, selectedRecord)
                    : null,
              ),
            ),
            const SizedBox(width: 12),

            // 删除按钮
            Expanded(
              child: _ToolbarButton(
                icon: Icons.delete_outline,
                label: '删除',
                color: selectedRecord != null
                    ? AppTheme.dangerColor
                    : AppTheme.textHint,
                enabled: selectedRecord != null,
                onPressed: selectedRecord != null
                    ? () => _showDeleteConfirm(context, ref, selectedRecord)
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddDialog(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _RecordFormSheet(
        title: '新增记录',
        onSave: (record) async {
          await ref.read(allRecordsProvider.notifier).addRecord(record);
          if (context.mounted) {
            Navigator.pop(context);
            _showSuccessSnackBar(context, '添加成功');
          }
        },
      ),
    );
  }

  void _showEditDialog(
      BuildContext context, WidgetRef ref, HealthRecord record) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _RecordFormSheet(
        title: '修改记录',
        initialRecord: record,
        onSave: (updated) async {
          await ref.read(allRecordsProvider.notifier).updateRecord(updated);
          ref.read(selectedRecordProvider.notifier).state = null;
          if (context.mounted) {
            Navigator.pop(context);
            _showSuccessSnackBar(context, '修改成功');
          }
        },
      ),
    );
  }

  void _showDeleteConfirm(
      BuildContext context, WidgetRef ref, HealthRecord record) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text(
          '确定要删除这条记录吗？\n\n'
          '日期: ${DateFormat('yyyy-MM-dd').format(record.testTime)}\n'
          '指标: ${record.indicatorName}\n'
          '数值: ${record.indicatorValue}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              if (record.id != null) {
                await ref
                    .read(allRecordsProvider.notifier)
                    .deleteRecord(record.id!);
                ref.read(selectedRecordProvider.notifier).state = null;
                if (context.mounted) {
                  _showSuccessSnackBar(context, '删除成功');
                }
              }
            },
            style: TextButton.styleFrom(foregroundColor: AppTheme.dangerColor),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  void _showSuccessSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.successColor,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

/// 工具栏按钮
class _ToolbarButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool enabled;
  final VoidCallback? onPressed;

  const _ToolbarButton({
    required this.icon,
    required this.label,
    required this.color,
    this.enabled = true,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onPressed : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: enabled ? color.withValues(alpha: 0.1) : AppTheme.backgroundColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.2),
                    offset: const Offset(0, 2),
                    blurRadius: 4,
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 20,
              color: enabled ? color : AppTheme.textHint,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: enabled ? color : AppTheme.textHint,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 记录表单弹窗
class _RecordFormSheet extends StatefulWidget {
  final String title;
  final HealthRecord? initialRecord;
  final Future<void> Function(HealthRecord) onSave;

  const _RecordFormSheet({
    required this.title,
    this.initialRecord,
    required this.onSave,
  });

  @override
  State<_RecordFormSheet> createState() => _RecordFormSheetState();
}

class _RecordFormSheetState extends State<_RecordFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _dateController;
  late TextEditingController _indicatorController;
  late TextEditingController _valueController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _dateController = TextEditingController(
      text: widget.initialRecord != null
          ? DateFormat('yyyy-MM-dd').format(widget.initialRecord!.testTime)
          : DateFormat('yyyy-MM-dd').format(DateTime.now()),
    );
    _indicatorController = TextEditingController(
      text: widget.initialRecord?.indicatorName ?? '',
    );
    _valueController = TextEditingController(
      text: widget.initialRecord?.indicatorValue.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _dateController.dispose();
    _indicatorController.dispose();
    _valueController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 标题栏
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // 日期选择
              _buildDateField(),
              const SizedBox(height: 16),

              // 指标名称
              _buildIndicatorField(),
              const SizedBox(height: 16),

              // 数值
              _buildValueField(),
              const SizedBox(height: 24),

              // 保存按钮
              ElevatedButton(
                onPressed: _isSaving ? null : _handleSave,
                child: _isSaving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('保存'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDateField() {
    return TextFormField(
      controller: _dateController,
      readOnly: true,
      decoration: const InputDecoration(
        labelText: '日期',
        prefixIcon: Icon(Icons.calendar_today),
      ),
      onTap: () async {
        final date = await showDatePicker(
          context: context,
          initialDate: DateTime.tryParse(_dateController.text) ?? DateTime.now(),
          firstDate: DateTime(2000),
          lastDate: DateTime.now(),
        );
        if (date != null) {
          _dateController.text = DateFormat('yyyy-MM-dd').format(date);
        }
      },
      validator: (value) {
        if (value == null || value.isEmpty) {
          return '请选择日期';
        }
        if (DateTime.tryParse(value) == null) {
          return '日期格式不正确';
        }
        return null;
      },
    );
  }

  Widget _buildIndicatorField() {
    // 常用指标选项
    final commonIndicators =
        IndicatorGroup.presets.map((g) => g.name).toList();

    return Autocomplete<String>(
      initialValue: TextEditingValue(text: _indicatorController.text),
      optionsBuilder: (textEditingValue) {
        if (textEditingValue.text.isEmpty) {
          return commonIndicators;
        }
        return commonIndicators.where((name) =>
            name.toLowerCase().contains(textEditingValue.text.toLowerCase()));
      },
      onSelected: (selection) {
        _indicatorController.text = selection;
      },
      fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
        // 同步控制器
        if (controller.text.isEmpty && _indicatorController.text.isNotEmpty) {
          controller.text = _indicatorController.text;
        }
        return TextFormField(
          controller: controller,
          focusNode: focusNode,
          decoration: const InputDecoration(
            labelText: '指标名称',
            prefixIcon: Icon(Icons.science_outlined),
          ),
          onChanged: (value) => _indicatorController.text = value,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return '请输入指标名称';
            }
            return null;
          },
        );
      },
    );
  }

  Widget _buildValueField() {
    return TextFormField(
      controller: _valueController,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: const InputDecoration(
        labelText: '数值',
        prefixIcon: Icon(Icons.numbers),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return '请输入数值';
        }
        if (double.tryParse(value) == null) {
          return '请输入有效数字';
        }
        return null;
      },
    );
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final record = HealthRecord(
        id: widget.initialRecord?.id,
        testTime: DateTime.parse(_dateController.text),
        indicatorName: _indicatorController.text,
        indicatorValue: double.parse(_valueController.text),
      );

      await widget.onSave(record);
    } catch (e) {
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
