import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/admin_schedule_service.dart';
import '../../../config/schedule_config.dart';
import '../../../core/utils/date_helper.dart';

class AdminScheduleScreen extends StatefulWidget {
  const AdminScheduleScreen({super.key});

  @override
  State<AdminScheduleScreen> createState() => _AdminScheduleScreenState();
}

class _AdminScheduleScreenState extends State<AdminScheduleScreen> {
  final AdminScheduleService _scheduleService = AdminScheduleService();
  DateTime _startDate = DateTime.now();
  List<DateTimeRange> _holidays = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    final config = await _scheduleService.getScheduleConfig();
    setState(() {
      _startDate = config.startDate;
      _holidays = List.from(config.holidays);
      _holidays.sort((a, b) => a.start.compareTo(b.start));
      _isLoading = false;
    });
  }

  Future<void> _saveConfig() async {
    setState(() => _isLoading = true);
    try {
      final config = ScheduleConfigData(
        startDate: _startDate,
        holidays: _holidays,
      );
      await _scheduleService.saveScheduleConfig(config);

      // 전역 설정 업데이트 (즉시 반영)
      ScheduleConfig.dynamicConfig = config;

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('일정 설정이 저장되었습니다.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('저장 실패: $e')));
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _selectStartDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2024),
      lastDate: DateTime(2027),
    );
    if (picked != null && picked != _startDate) {
      setState(() {
        _startDate = picked;
      });
    }
  }

  Future<void> _addHoliday() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime(2027),
      saveText: '추가',
      helpText: '휴일 범위 선택',
    );

    if (picked != null) {
      setState(() {
        _holidays.add(picked);
        _holidays.sort((a, b) => a.start.compareTo(b.start));
      });
    }
  }

  void _removeHoliday(int index) {
    setState(() {
      _holidays.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('일정 관리'),
        actions: [
          IconButton(
            onPressed: _isLoading ? null : _saveConfig,
            icon: const Icon(Icons.save),
          ),
        ],
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '통독 시작일 설정',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ListTile(
                      title: Text(
                        DateFormat('yyyy-MM-dd (EEEE)').format(_startDate),
                      ),
                      trailing: const Icon(Icons.calendar_today),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(color: Colors.grey.shade300),
                      ),
                      onTap: _selectStartDate,
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          '휴일 관리',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          onPressed: _addHoliday,
                          icon: const Icon(
                            Icons.add_circle,
                            color: Colors.indigo,
                          ),
                        ),
                      ],
                    ),
                    const Text(
                      '등록된 날짜는 통독 일정에서 제외(건너뜀)됩니다.',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child:
                          _holidays.isEmpty
                              ? const Center(child: Text('등록된 휴일이 없습니다.'))
                              : ListView.builder(
                                itemCount: _holidays.length,
                                itemBuilder: (context, index) {
                                  final range = _holidays[index];
                                  final isSingleDay = DateHelper.isSameDate(
                                    range.start,
                                    range.end,
                                  );
                                  return Card(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    child: ListTile(
                                      title: Text(
                                        isSingleDay
                                            ? DateFormat(
                                              'yyyy-MM-dd (E)',
                                            ).format(range.start)
                                            : '${DateFormat('MM-dd').format(range.start)} ~ ${DateFormat('MM-dd').format(range.end)}',
                                      ),
                                      trailing: IconButton(
                                        icon: const Icon(
                                          Icons.delete,
                                          color: Colors.red,
                                        ),
                                        onPressed: () => _removeHoliday(index),
                                      ),
                                    ),
                                  );
                                },
                              ),
                    ),
                  ],
                ),
              ),
    );
  }
}
