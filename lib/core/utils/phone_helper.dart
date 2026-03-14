/// 전화번호 표시 포맷 유틸리티
///
/// +821029066258 → 010-2906-6258 형식으로 변환
class PhoneHelper {
  /// 한국 휴대폰 번호를 사용자 친화적인 형식(010-XXXX-XXXX)으로 변환
  ///
  /// 입력 예: +821029066258, 821029066258, 01029066258, 1029066258
  /// 출력 예: 010-2906-6258
  static String formatForDisplay(String? phone) {
    if (phone == null || phone.trim().isEmpty) return '';

    String digits = phone.replaceAll(RegExp(r'[^\d]'), '');

    // +82 또는 82로 시작하면 제거 후 0 추가
    if (digits.startsWith('82') && digits.length >= 10) {
      digits = '0${digits.substring(2)}';
    }
    // 10으로 시작하면 (국가코드 제거된 형태) 0 추가
    else if (digits.startsWith('10') && digits.length == 10) {
      digits = '0$digits';
    }

    // 010-XXXX-XXXX 형식 (11자리)
    if (digits.length == 11 && digits.startsWith('010')) {
      return '${digits.substring(0, 3)}-${digits.substring(3, 7)}-${digits.substring(7)}';
    }
    // 10자리 (010 제외)
    if (digits.length == 10 && digits.startsWith('10')) {
      return '010-${digits.substring(2, 6)}-${digits.substring(6)}';
    }

    // 이미 하이픈이 있거나 다른 형식이면 원본 반환 (최소한 숫자만 추출해서 시도)
    if (digits.length >= 10) {
      final normalized = digits.length == 11 ? digits : '0$digits';
      if (normalized.startsWith('010') && normalized.length == 11) {
        return '${normalized.substring(0, 3)}-${normalized.substring(3, 7)}-${normalized.substring(7)}';
      }
    }

    return phone;
  }
}
