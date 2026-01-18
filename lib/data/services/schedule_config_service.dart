import '../../config/schedule_config.dart';
import '../../core/utils/logger_util.dart';
import '../repositories/schedule_config_repository.dart';

class ScheduleConfigService {
  static final ScheduleConfigService _instance =
      ScheduleConfigService._internal();
  final ScheduleConfigRepository _repository;

  factory ScheduleConfigService() {
    return _instance;
  }

  ScheduleConfigService._internal()
    : _repository = ScheduleConfigRepository();

  Future<void> loadRemoteConfigs() async {
    try {
      final List<ScheduleConfigEntry> entries =
          await _repository.fetchScheduleConfigs();
      if (entries.isEmpty) {
        LoggerUtil.info('No remote schedule configs found.');
        return;
      }
      ScheduleConfig.updateFromRemote(entries);
      LoggerUtil.info('Remote schedule configs applied.');
    } catch (e, stackTrace) {
      LoggerUtil.error('Failed to load remote schedule configs', e, stackTrace);
    }
  }
}

