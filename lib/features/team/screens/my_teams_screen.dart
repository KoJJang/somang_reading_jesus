import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/date_helper.dart';
import '../models/team.dart';
import '../services/team_service.dart';
import 'team_leader_screen.dart';

/// 내 팀 현황 화면 (팀원·팀장 통합)
///
/// 현재 사용자가 속한 모든 팀을 연도별로 조회합니다.
/// 팀 카드를 탭하면 대시보드로 이동하며,
/// 해당 팀의 팀장인 경우에만 완료 처리를 할 수 있습니다.
class MyTeamsScreen extends StatefulWidget {
  const MyTeamsScreen({super.key});

  @override
  State<MyTeamsScreen> createState() => _MyTeamsScreenState();
}

class _MyTeamsScreenState extends State<MyTeamsScreen> {
  final TeamService _teamService = TeamService();

  late int _selectedYear;
  List<Team> _teams = [];
  Map<String, List<TeamMemberSummary>> _membersMap = {};
  bool _isLoading = true;

  // 선택 가능한 연도: 현재 연도 기준 최근 3년
  late List<int> _availableYears;
  String? _currentUid;

  @override
  void initState() {
    super.initState();
    final int currentYear = DateHelper.getScheduleYear(DateTime.now());
    _selectedYear = currentYear;
    _availableYears = [currentYear - 2, currentYear - 1, currentYear];
    _currentUid = FirebaseAuth.instance.currentUser?.uid;
    _loadTeams();
  }

  Future<void> _loadTeams() async {
    setState(() => _isLoading = true);
    final teams = await _teamService.getMyTeams(year: _selectedYear);
    if (!mounted) return;

    // 팀이 하나뿐이면 바로 대시보드로 이동
    if (teams.length == 1) {
      final team = teams.first;
      final isReadOnly = team.leaderUid != _currentUid;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) =>
              TeamLeaderScreen(team: team, isReadOnly: isReadOnly),
        ),
      );
      return;
    }

    // 팀원 진행상황 병렬 로드
    final membersResults = await Future.wait(
      teams.map(
        (t) => _teamService.getTeamMembersWithProgress(teamId: t.teamId),
      ),
    );
    final Map<String, List<TeamMemberSummary>> membersMap = {
      for (int i = 0; i < teams.length; i++)
        teams[i].teamId: membersResults[i],
    };

    if (!mounted) return;
    setState(() {
      _teams = teams;
      _membersMap = membersMap;
      _isLoading = false;
    });
  }

  void _onYearChanged(int? year) {
    if (year == null || year == _selectedYear) return;
    setState(() => _selectedYear = year);
    _loadTeams();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('팀 현황'),
        backgroundColor: AppColors.background,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 연도 드롭다운
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                  child: _buildYearDropdown(),
                ),
                Expanded(
                  child: _teams.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                          itemCount: _teams.length,
                          itemBuilder: (context, index) =>
                              _buildTeamCard(_teams[index]),
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildYearDropdown() {
    return Row(
      children: [
        Text(
          '${_teams.length}개 팀',
          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: _selectedYear,
              isDense: true,
              icon: const Icon(
                Icons.keyboard_arrow_down,
                size: 18,
                color: AppColors.textSecondary,
              ),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
              items: _availableYears
                  .map(
                    (y) => DropdownMenuItem(value: y, child: Text('$y년')),
                  )
                  .toList(),
              onChanged: _onYearChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTeamCard(Team team) {
    final bool isLeader = team.leaderUid == _currentUid;
    final List<TeamMemberSummary> members = _membersMap[team.teamId] ?? [];
    final int totalMembers = members.length;
    final int completedCount = members
        .where(
          (m) =>
              !m.isBreakWeek &&
              m.weeklyTotalDays > 0 &&
              m.weeklyCompletedDays >= m.weeklyTotalDays,
        )
        .length;
    final double rate =
        totalMembers > 0 ? completedCount / totalMembers : 0.0;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                TeamLeaderScreen(team: team, isReadOnly: !isLeader),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        team.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      if (isLeader) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            '팀장',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '팀장: ${team.leaderName}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textTertiary,
                    ),
                  ),
                  if (totalMembers > 0) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: rate,
                              minHeight: 5,
                              backgroundColor: const Color(0xFFF3F4F6),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                rate == 1.0
                                    ? const Color(0xFF059669)
                                    : AppColors.primary,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          '$completedCount/$totalMembers명',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.chevron_right,
              color: AppColors.textTertiary,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.group_off, size: 48, color: AppColors.textTertiary),
          const SizedBox(height: 16),
          Text(
            '$_selectedYear년 소속 팀이 없습니다',
            style: const TextStyle(
              fontSize: 17,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            '다른 연도를 선택하거나 관리자에게 문의하세요',
            style: TextStyle(fontSize: 13, color: AppColors.textTertiary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
