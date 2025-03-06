import 'package:flutter/material.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('개인정보 처리방침')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '리딩 지저스 소망교회 개인정보 처리방침',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text(
              '소망교회(이하 "교회")는 이용자의 개인정보를 중요시하며, 「개인정보 보호법」을 준수하기 위하여 노력하고 있습니다. 교회는 개인정보 처리방침을 통하여 수집하는 개인정보가 어떠한 용도와 방식으로 이용되고 있으며, 개인정보보호를 위해 어떠한 조치가 취해지고 있는지 알려드립니다.',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 24),
            _buildSectionTitle('1. 수집하는 개인정보 항목'),
            _buildText('교회는 앱 서비스 제공을 위해 다음의 개인정보를 수집합니다:'),
            _buildBulletPoint('필수항목: 휴대폰 번호, 이름, 생년월일'),
            _buildBulletPoint('선택항목: 없음'),
            _buildBulletPoint('자동 수집 항목: 기기 정보, 로그 데이터, 사용 기록'),

            const SizedBox(height: 16),
            _buildSectionTitle('2. 개인정보의 수집 및 이용목적'),
            _buildText('수집한 개인정보는 다음의 목적을 위해 활용됩니다:'),
            _buildBulletPoint('사용자 식별 및 앱 서비스 제공'),
            _buildBulletPoint('성경 통독 기록 관리 및 진도 확인'),
            _buildBulletPoint('앱 기능 개선 및 사용성 향상'),
            _buildBulletPoint('공지사항 및 중요 안내 전달'),

            const SizedBox(height: 16),
            _buildSectionTitle('3. 개인정보의 보유 및 이용기간'),
            _buildText(
              '원칙적으로 개인정보는 회원 탈퇴 시까지 보관됩니다. 다만, 다음의 경우에는 관련 법령에 따라 일정 기간 보관됩니다:',
            ),
            _buildBulletPoint('서비스 이용 기록: 3개월 (통신비밀보호법)'),
            _buildBulletPoint('접속 로그: 3개월 (통신비밀보호법)'),

            const SizedBox(height: 16),
            _buildSectionTitle('4. 개인정보의 파기절차 및 방법'),
            _buildText('회원 탈퇴 시 또는 보유기간이 종료된 개인정보는 지체 없이 파기됩니다.'),
            _buildText('전자적 파일 형태로 저장된 개인정보는 복구 및 재생이 불가능한 방법으로 영구삭제 됩니다.'),

            const SizedBox(height: 16),
            _buildSectionTitle('5. 개인정보의 제3자 제공'),
            _buildText(
              '교회는 원칙적으로 이용자의 개인정보를 외부에 제공하지 않습니다. 다만, 다음의 경우에는 예외로 합니다:',
            ),
            _buildBulletPoint('이용자가 사전에 동의한 경우'),
            _buildBulletPoint('법령의 규정에 의거하거나, 수사 목적으로 법령에 정해진 절차에 따라 요청받은 경우'),

            const SizedBox(height: 16),
            _buildSectionTitle('6. 이용자의 권리와 행사방법'),
            _buildText(
              '이용자는 언제든지 등록된 자신의 개인정보를 조회하거나 수정할 수 있으며, 앱 탈퇴를 통해 개인정보 삭제를 요청할 수 있습니다.',
            ),
            _buildText(
              '개인정보 관련 문의는 앱 내 문의하기 기능 또는 아래의 연락처로 요청하시면 지체 없이 조치하겠습니다.',
            ),

            const SizedBox(height: 16),
            _buildSectionTitle('7. 개인정보 자동 수집 장치의 설치/운영 및 거부에 관한 사항'),
            _buildText(
              '교회는 이용자에게 개별적인 맞춤서비스를 제공하기 위해 이용정보를 저장하고 수시로 불러오는 기술을 사용할 수 있습니다.',
            ),

            const SizedBox(height: 16),
            _buildSectionTitle('8. 개인정보의 안전성 확보조치'),
            _buildText('교회는 개인정보의 안전성 확보를 위해 다음과 같은 조치를 취하고 있습니다:'),
            _buildBulletPoint('개인정보 암호화 전송 및 저장'),
            _buildBulletPoint('접근 권한 관리'),
            _buildBulletPoint('방화벽 및 보안 시스템 운영'),

            const SizedBox(height: 16),
            _buildSectionTitle('9. 개인정보 보호책임자'),
            _buildText(
              '교회는 개인정보 처리에 관한 업무를 총괄해서 책임지고, 개인정보와 관련된 불만처리 및 피해구제 등을 위하여 아래와 같이 개인정보 보호책임자를 지정하고 있습니다.',
            ),
            const SizedBox(height: 8),
            const Text(
              '▶ 개인정보 보호책임자\n'
              '성명: 김정민\n'
              '연락처: 031-238-7545\n'
              '이메일: somang@somang.com',
              style: TextStyle(fontSize: 14),
            ),

            const SizedBox(height: 16),
            _buildSectionTitle('10. 개인정보 처리방침 변경'),
            _buildText('이 개인정보 처리방침은 2025년 3월 1일부터 적용됩니다.'),
            _buildText('본 개인정보 처리방침이 변경될 경우에는 변경 내용을 앱 내 공지사항을 통해 공지할 것입니다.'),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        title,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildText(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(text, style: const TextStyle(fontSize: 14)),
    );
  }

  Widget _buildBulletPoint(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 16.0, bottom: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(fontSize: 14)),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 14))),
        ],
      ),
    );
  }
}
