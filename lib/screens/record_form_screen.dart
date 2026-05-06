import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/record.dart';
import '../providers/records_provider.dart';
import '../theme/app_theme.dart';

/// 添加/编辑记录页面
class RecordFormScreen extends ConsumerStatefulWidget {
  final HealthRecord? record; // 如果是编辑模式，传入现有记录

  const RecordFormScreen({super.key, this.record});

  @override
  ConsumerState<RecordFormScreen> createState() => _RecordFormScreenState();
}

class _RecordFormScreenState extends ConsumerState<RecordFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late DateTime _testTime;
  String? _selectedIndicator;
  final _valueController = TextEditingController();
  final _remarkController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.record != null) {
      // 编辑模式：填充现有数据
      _testTime = widget.record!.testTime;
      _selectedIndicator = widget.record!.indicatorName;
      _valueController.text = widget.record!.indicatorValue.toString();
      _remarkController.text = widget.record!.remark ?? '';
    } else {
      _testTime = DateTime.now();
    }
  }

  @override
  void dispose() {
    _valueController.dispose();
    _remarkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.record != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? '编辑记录' : '添加记录'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: _saveRecord,
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // 日期选择
            _buildDateField(),
            const SizedBox(height: 16),

            // 指标选择
            _buildIndicatorField(),
            const SizedBox(height: 16),

            // 数值输入
            _buildValueField(),
            const SizedBox(height: 16),

            // 备注输入
            _buildRemarkField(),
          ],
        ),
      ),
    );
  }

  Widget _buildDateField() {
    return InkWell(
      onTap: _pickDate,
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: '检测日期',
          border: OutlineInputBorder(),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${_testTime.year}-${_testTime.month.toString().padLeft(2, '0')}-${_testTime.day.toString().padLeft(2, '0')}',
              style: const TextStyle(fontSize: 16),
            ),
            const Icon(Icons.calendar_today, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildIndicatorField() {
    final indicatorsAsync = ref.watch(indicatorNamesProvider);

    return indicatorsAsync.when(
      data: (indicators) {
        return DropdownButtonFormField<String>(
          initialValue: _selectedIndicator,
          decoration: const InputDecoration(
            labelText: '指标类型',
            border: OutlineInputBorder(),
          ),
          items: indicators.map((name) {
            final group = IndicatorGroup.findByName(name);
            return DropdownMenuItem(
              value: name,
              child: Text(group?.displayName ?? name),
            );
          }).toList(),
          onChanged: (value) {
            setState(() => _selectedIndicator = value);
          },
          validator: (value) {
            if (value == null || value.isEmpty) {
              return '请选择指标类型';
            }
            return null;
          },
        );
      },
      loading: () => const LinearProgressIndicator(),
      error: (e, _) => const Text('加载指标失败'),
    );
  }

  Widget _buildValueField() {
    return TextFormField(
      controller: _valueController,
      decoration: const InputDecoration(
        labelText: '指标数值',
        border: OutlineInputBorder(),
        suffixText: '数值',
      ),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return '请输入指标数值';
        }
        if (double.tryParse(value) == null) {
          return '请输入有效的数字';
        }
        return null;
      },
    );
  }

  Widget _buildRemarkField() {
    return TextFormField(
      controller: _remarkController,
      decoration: const InputDecoration(
        labelText: '备注 (可选)',
        border: OutlineInputBorder(),
        hintText: '输入备注信息...',
      ),
      maxLines: 3,
      maxLength: 200,
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _testTime,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      setState(() => _testTime = picked);
    }
  }

  Future<void> _saveRecord() async {
    if (!_formKey.currentState!.validate()) return;

    final record = HealthRecord(
      id: widget.record?.id,
      testTime: _testTime,
      indicatorName: _selectedIndicator!,
      indicatorValue: double.parse(_valueController.text),
      remark: _remarkController.text.isEmpty ? null : _remarkController.text,
    );

    try {
      if (widget.record != null) {
        await ref.read(allRecordsProvider.notifier).updateRecord(record);
      } else {
        await ref.read(allRecordsProvider.notifier).addRecord(record);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.record != null ? '记录已更新' : '记录已添加'),
            backgroundColor: AppTheme.successColor,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('保存失败: $e'),
            backgroundColor: AppTheme.dangerColor,
          ),
        );
      }
    }
  }
}
