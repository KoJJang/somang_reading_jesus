#!/usr/bin/env bash
# deploy.sh — 소망교회 리딩지저스 앱 배포 스크립트
# 사용법: bash scripts/deploy.sh

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_ROOT"

# ─── 색상 출력 ────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

info()    { echo -e "${CYAN}[INFO]${NC} $*"; }
success() { echo -e "${GREEN}[OK]${NC}   $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $*"; }
error()   { echo -e "${RED}[ERR]${NC}  $*"; exit 1; }

# ─── 현재 버전 읽기 ───────────────────────────────────────────────────────────
read_version() {
  grep '^version:' pubspec.yaml | sed 's/version: //'
}

# ─── 버전 증가 ────────────────────────────────────────────────────────────────
bump_version() {
  local current
  current=$(read_version)
  local name code
  name=$(echo "$current" | cut -d'+' -f1)
  code=$(echo "$current" | cut -d'+' -f2)

  # patch 버전 +1, build number +1
  local major minor patch
  IFS='.' read -r major minor patch <<< "$name"
  patch=$((patch + 1))
  code=$((code + 1))

  local new_version="${major}.${minor}.${patch}+${code}"
  sed -i '' "s/^version: .*/version: ${new_version}/" pubspec.yaml
  echo "$new_version"
}

# ─── 사전 검사 ────────────────────────────────────────────────────────────────
preflight_checks() {
  info "사전 검사 중..."

  command -v flutter >/dev/null 2>&1 || error "Flutter가 설치되지 않았습니다"
  command -v fastlane >/dev/null 2>&1 || error "Fastlane이 설치되지 않았습니다 (gem install fastlane)"

  info "flutter analyze 실행 중..."
  if ! flutter analyze --no-pub 2>&1; then
    error "flutter analyze 실패. 에러를 수정 후 다시 실행하세요."
  fi
  success "analyze 통과"

  info "flutter test 실행 중..."
  if ! flutter test 2>&1; then
    error "테스트 실패. 테스트를 수정 후 다시 실행하세요."
  fi
  success "테스트 통과"
}

# ─── 메인 ─────────────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}══════════════════════════════════════════${NC}"
echo -e "${BOLD}  소망교회 리딩지저스 — 배포 스크립트     ${NC}"
echo -e "${BOLD}══════════════════════════════════════════${NC}"
echo ""

# 현재 버전 표시
CURRENT_VERSION=$(read_version)
info "현재 버전: ${BOLD}${CURRENT_VERSION}${NC}"
echo ""

# 버전 증가 여부 선택
echo -e "${BOLD}버전을 자동으로 올릴까요?${NC}"
echo "  1) 예 — patch + build number 자동 증가"
echo "  2) 아니오 — 현재 버전 유지"
read -rp "선택 (1/2): " BUMP_CHOICE
echo ""

if [[ "$BUMP_CHOICE" == "1" ]]; then
  NEW_VERSION=$(bump_version)
  success "버전 업데이트: ${CURRENT_VERSION} → ${NEW_VERSION}"
  echo ""
fi

# 사전 검사
preflight_checks
echo ""

# 플랫폼 선택
echo -e "${BOLD}배포할 플랫폼을 선택하세요:${NC}"
echo "  1) Android만"
echo "  2) iOS만"
echo "  3) Android + iOS 모두"
read -rp "선택 (1/2/3): " PLATFORM_CHOICE
echo ""

# 트랙/환경 선택
echo -e "${BOLD}배포 트랙을 선택하세요:${NC}"
echo "  1) Beta (Android: 내부테스트 / iOS: TestFlight)"
echo "  2) Production (스토어 출시)"
read -rp "선택 (1/2): " TRACK_CHOICE
echo ""

case "$TRACK_CHOICE" in
  1) TRACK="beta" ;;
  2) TRACK="prod" ;;
  *) error "잘못된 선택입니다" ;;
esac

# 최종 확인
CURRENT_VERSION=$(read_version)
echo -e "${BOLD}── 배포 요약 ──────────────────────────────${NC}"
info "버전  : ${CURRENT_VERSION}"
case "$PLATFORM_CHOICE" in
  1) info "플랫폼: Android" ;;
  2) info "플랫폼: iOS" ;;
  3) info "플랫폼: Android + iOS" ;;
  *) error "잘못된 선택입니다" ;;
esac
info "트랙  : ${TRACK}"
echo ""
read -rp "계속 진행할까요? (y/N): " CONFIRM
[[ "$CONFIRM" =~ ^[Yy]$ ]] || { warn "배포 취소됨"; exit 0; }
echo ""

# Fastlane 실행
run_fastlane() {
  local platform="$1"
  local lane="$2"
  info "fastlane ${platform} ${lane} 실행 중..."
  cd fastlane
  bundle exec fastlane "${platform}" "${lane}" 2>&1 || fastlane "${platform}" "${lane}" 2>&1
  cd ..
}

case "$PLATFORM_CHOICE" in
  1)
    run_fastlane android "$TRACK"
    ;;
  2)
    run_fastlane ios "$TRACK"
    ;;
  3)
    run_fastlane android "$TRACK"
    run_fastlane ios "$TRACK"
    ;;
esac

echo ""
success "배포 완료!"
