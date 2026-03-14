import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/date_helper.dart';
import '../../calendar/screens/calendar_screen.dart';
import '../models/team.dart';
import '../services/team_service.dart';

/// 팀 대시보드 화면 (팀장·팀원 통합)
///
/// 팀원 목록 및 주간 진행상황을 표시합니다.
/// [isReadOnly]가 true이면 완료 처리 기능이 비활성화됩니다.
class TeamLeaderScreen extends StatefulWidget {
  final Team team;

  /// true: 조회 전용 (팀원 뷰). false: 완료 처리 가능 (팀장 뷰).
  final bool isReadOnly;

  const TeamLeaderScreen({
    super.key,
    required this.team,
    this.isReadOnly = false,
  });

  @override
  State<TeamLeaderScreen> createState() => _TeamLeaderScreenState();
}

class _TeamLeaderScreenState extends State<TeamLeaderScreen> {
  final TeamService _teamService = TeamService();
  List<TeamMemberSummary> _members = [];
  bool _isLoading = true;
  bool _isBreakWeek = false;
  late String _teamName;

  @override
  void initState() {
    super.initState();
    _teamName = widget.team.name;
    _isBreakWeek = DateHelper.isBreakWeek(DateTime.now());
    _loadTeamMembers();
  }

  Future<void> _loadTeamMembers() async {
    setState(() => _isLoading = true);
    final members = await _teamService.getTeamMembersWithProgress(
      teamId: widget.team.teamId,
    );
    if (mounted) {
      setState(() {
        _members = members;
        _isLoading = false;
      });
    }
  }

  Future<void> _showRenameDialog() async {
    final controller = TextEditingController(text: _teamName);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('팀 이름 변경'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: '새 팀 이름'),
          onSubmitted: (_) => Navigator.pop(ctx, true),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('변경'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final newName = controller.text.trim();
    if (newName.isEmpty || newName == _teamName) return;

    final ok = await _teamService.renameTeam(
      teamId: widget.team.teamId,
      newName: newName,
    );
    if (ok && mounted) setState(() => _teamName = newName);
  }

  Future<void> _refreshTeamMembersSilently() async {
    final members = await _teamService.getTeamMembersWithProgress(
      teamId: widget.team.teamId,
    );
    if (mounted) setState(() => _members = members);
  }

  // 완료 기준: weeklyTotalDays > 0 이고 weeklyCompletedDays >= weeklyTotalDays
  // (future 일수는 weeklyTotalDays에 포함되지 않으므로 자연스럽게 제외됨)
  bool _isWeekDone(TeamMemberSummary m) {
    if (m.isBreakWeek || m.weeklyTotalDays == 0) return false;
    return m.weeklyCompletedDays >= m.weeklyTotalDays;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(_teamName),
        backgroundColor: AppColors.background,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        actions: widget.isReadOnly
            ? null
            : [
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 20),
                  onPressed: _showRenameDialog,
                  tooltip: '팀 이름 변경',
                ),
              ],
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                onRefresh: _loadTeamMembers,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
                  children: [
                    _buildHeroCard(),
                    const SizedBox(height: 20),
                    Text(
                      _isBreakWeek ? '팀원 목록' : '팀원 진행상황',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (_members.isEmpty)
                      _buildEmptyState()
                    else
                      ..._members.map(_buildMemberCard),
                  ],
                ),
              ),
    );
  }

  // ---------------------------------------------------------------------------
  // 히어로 카드 (이번 주 완료 현황)
  // ---------------------------------------------------------------------------

  Widget _buildHeroCard() {
    if (_isBreakWeek) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            const Text('☕', style: TextStyle(fontSize: 24)),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.team.name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const Text(
                  '이번 주는 휴식 주간입니다',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    final int totalMembers = _members.length;
    final int completedCount = _members.where(_isWeekDone).length;
    final double rate = totalMembers > 0 ? completedCount / totalMembers : 0.0;
    final bool allDone = completedCount == totalMembers && totalMembers > 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: allDone ? AppColors.completedLight : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: allDone ? AppColors.completedBorder : AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '이번 주 완료',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: allDone
                  ? AppColors.completed
                  : AppColors.textTertiary,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '$completedCount',
                style: TextStyle(
                  fontSize: 44,
                  fontWeight: FontWeight.w800,
                  color: allDone
                      ? AppColors.completed
                      : AppColors.textPrimary,
                  height: 1,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                '/ $totalMembers명',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: rate,
              minHeight: 6,
              backgroundColor: AppColors.surfaceGray,
              valueColor: AlwaysStoppedAnimation<Color>(
                allDone ? AppColors.completed : AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 팀원 카드
  // ---------------------------------------------------------------------------

  Widget _buildMemberCard(TeamMemberSummary member) {
    final bool done = _isWeekDone(member);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: done ? AppColors.completedLight : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: done ? AppColors.completedBorder : AppColors.border,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: (_isBreakWeek || widget.isReadOnly)
            ? null
            : () => _showMemberWeeklyDetail(member),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              // 아바타
              CircleAvatar(
                radius: 18,
                backgroundColor:
                    done
                        ? AppColors.completedSubtle
                        : AppColors.primary.withValues(alpha: 0.1),
                child:
                    member.isTeamLeader
                        ? Icon(
                          Icons.star_rounded,
                          size: 16,
                          color:
                              done ? AppColors.completed : AppColors.primary,
                        )
                        : Text(
                          member.name.isNotEmpty ? member.name[0] : '?',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color:
                                done
                                    ? AppColors.completed
                                    : AppColors.primary,
                          ),
                        ),
              ),
              const SizedBox(width: 12),
              // 이름 + dot row
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          member.name,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        if (member.isTeamLeader) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              '팀장',
                              style: TextStyle(
                                fontSize: 10,
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 7),
                    _buildDotRow(member),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              // 전체 완료일
              Text(
                '${member.totalCompletedDays}일',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textTertiary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (!_isBreakWeek) ...[
                const SizedBox(width: 4),
                const Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: AppColors.textTertiary,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// 주간 dot row: 완료(채움) / 미완료(빈 원) / future(회색)
  /// weeklyTotalDays = 오늘까지 active 일수 (future 미포함)
  /// weeklyCompletedDays = 그 중 완료한 일수
  /// 6 - weeklyTotalDays = 아직 오지 않은 날 수
  Widget _buildDotRow(TeamMemberSummary member) {
    if (member.isBreakWeek) {
      return const Text(
        '휴식 주간',
        style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
      );
    }

    const int totalSlots = 6; // 월~토
    const List<String> dayLabels = ['월', '화', '수', '목', '금', '토'];
    final int activeDays = member.weeklyTotalDays.clamp(0, totalSlots);
    final int completedDays = member.weeklyCompletedDays.clamp(0, activeDays);
    final bool allDone = activeDays > 0 && completedDays >= activeDays;

    return Row(
      children: List.generate(totalSlots, (i) {
        final bool isDone = i < completedDays;
        final bool isFuture = i >= activeDays;

        return Container(
          width: 24,
          height: 24,
          margin: const EdgeInsets.only(right: 4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isDone
                ? (allDone
                    ? AppColors.completedSubtle
                    : AppColors.primaryLighter)
                : isFuture
                    ? AppColors.surfaceGray
                    : Colors.transparent,
            border: (!isDone && !isFuture)
                ? Border.all(color: AppColors.border, width: 1.5)
                : null,
          ),
          child: Center(
            child: Text(
              dayLabels[i],
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: isDone
                    ? (allDone
                        ? AppColors.completed
                        : AppColors.primary)
                    : isFuture
                        ? AppColors.disabled
                        : AppColors.textTertiary,
              ),
            ),
          ),
        );
      }),
    );
  }

  // ---------------------------------------------------------------------------
  // 빈 상태
  // ---------------------------------------------------------------------------

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: const [
          Icon(Icons.group_off, size: 40, color: AppColors.textTertiary),
          SizedBox(height: 12),
          Text(
            '아직 팀원이 없습니다',
            style: TextStyle(fontSize: 15, color: AppColors.textSecondary),
          ),
          SizedBox(height: 6),
          Text(
            '관리자에게 팀원 배정을 요청해주세요',
            style: TextStyle(fontSize: 13, color: AppColors.textTertiary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 팀원 주간 상세 바텀시트
  // ---------------------------------------------------------------------------

  Future<void> _showMemberWeeklyDetail(TeamMemberSummary member) async {
    List<MemberDayDetail> details = [];
    bool isDetailLoading = true;

    final int scheduleYear = DateHelper.getScheduleYear(DateTime.now());

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            if (isDetailLoading) {
              _teamService
                  .getWeeklyDetailForMember(memberUid: member.uid)
                  .then((result) {
                    setSheetState(() {
                      details = result;
                      isDetailLoading = false;
                    });
                  });
            }

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 핸들
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.disabled,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // 헤더
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor:
                              AppColors.primary.withValues(alpha: 0.1),
                          child:
                              member.isTeamLeader
                                  ? const Icon(
                                    Icons.star_rounded,
                                    color: AppColors.primary,
                                    size: 16,
                                  )
                                  : Text(
                                    member.name.isNotEmpty
                                        ? member.name[0]
                                        : '?',
                                    style: const TextStyle(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                    ),
                                  ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          member.name,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '전체 ${member.totalCompletedDays}일',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Divider(height: 1, color: AppColors.surfaceGray),
                    const SizedBox(height: 14),
                    const Text(
                      '이번 주 진행상황',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      widget.isReadOnly
                          ? '완료 처리는 팀장만 할 수 있습니다'
                          : '탭하여 읽음 처리를 대신해줄 수 있습니다',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textTertiary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (isDetailLoading)
                      const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (details.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(
                          child: Text(
                            '이번 주 일정이 없습니다',
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                        ),
                      )
                    else
                      ...details.map(
                        (detail) => _buildDayRow(
                          detail: detail,
                          isFuture: detail.date.isAfter(DateTime.now()),
                          scheduleYear: scheduleYear,
                          memberUid: member.uid,
                          setSheetState: setSheetState,
                          details: details,
                        ),
                      ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(sheetContext);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => CalendarScreen(
                                viewingUserId: member.uid,
                                viewingUserName: member.name,
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.calendar_month, size: 17),
                        label: const Text('전체 캘린더 보기'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: BorderSide(
                            color: AppColors.primary.withValues(alpha: 0.3),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    _refreshTeamMembersSilently();
  }

  Widget _buildDayRow({
    required MemberDayDetail detail,
    required bool isFuture,
    required int scheduleYear,
    required String memberUid,
    required StateSetter setSheetState,
    required List<MemberDayDetail> details,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(9),
        onTap:
            (isFuture || widget.isReadOnly)
                ? null
                : () async {
                  if (detail.isCompleted) {
                    final success = await _teamService.unmarkCompletionForMember(
                      memberUid: memberUid,
                      scheduleYear: scheduleYear,
                      week: detail.week,
                      day: detail.day,
                    );
                    if (success) {
                      setSheetState(() {
                        final idx = details.indexOf(detail);
                        details[idx] = MemberDayDetail(
                          date: detail.date,
                          week: detail.week,
                          day: detail.day,
                          isCompleted: false,
                          dayLabel: detail.dayLabel,
                        );
                      });
                    }
                  } else {
                    final success = await _teamService.markCompletionForMember(
                      memberUid: memberUid,
                      scheduleYear: scheduleYear,
                      week: detail.week,
                      day: detail.day,
                      date: detail.date,
                    );
                    if (success) {
                      setSheetState(() {
                        final idx = details.indexOf(detail);
                        details[idx] = MemberDayDetail(
                          date: detail.date,
                          week: detail.week,
                          day: detail.day,
                          isCompleted: true,
                          dayLabel: detail.dayLabel,
                        );
                      });
                    }
                  }
                },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color:
                isFuture
                    ? AppColors.background
                    : detail.isCompleted
                    ? AppColors.completedLight
                    : Colors.white,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(
              color:
                  detail.isCompleted
                      ? AppColors.completedBorder
                      : AppColors.border,
            ),
          ),
          child: Row(
            children: [
              // 요일 원형 레이블
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color:
                      isFuture
                          ? AppColors.surfaceGray
                          : detail.isCompleted
                          ? AppColors.completedSubtle
                          : AppColors.primary.withValues(alpha: 0.08),
                ),
                alignment: Alignment.center,
                child: Text(
                  detail.dayLabel,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color:
                        isFuture
                            ? AppColors.textTertiary
                            : detail.isCompleted
                            ? AppColors.completed
                            : AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${detail.date.month}/${detail.date.day}',
                style: TextStyle(
                  fontSize: 14,
                  color:
                      isFuture
                          ? AppColors.textTertiary
                          : AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              if (isFuture)
                const Text(
                  '예정',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textTertiary,
                  ),
                )
              else
                Icon(
                  detail.isCompleted
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked,
                  color:
                      detail.isCompleted
                          ? AppColors.completed
                          : AppColors.disabled,
                  size: 22,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
