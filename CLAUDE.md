# CLAUDE.md – 리딩지저스 소망교회 앱

## 프로젝트 개요

소망교회 성경 통독 앱 (Flutter). 45주 통독 일정 관리, 팀 진행 현황, 해설 이미지/영상 제공.

- **플랫폼**: iOS, Android (Web/Desktop은 보조)
- **Backend**: Firebase (Firestore, Auth, AppCheck)
- **로컬 DB**: SQLite (sqflite) — 오프라인 우선
- **패키지 관리**: `flutter pub` (pubspec.yaml)

---

## 코딩 원칙 (Karpathy Guidelines)

> `/karpathy-guidelines` 스킬을 항상 적용한다. 아래는 핵심 요약.

### 1. 코딩 전에 생각하기
- 가정을 명시적으로 밝힌다. 불확실하면 먼저 묻는다.
- 여러 해석이 가능하면 침묵으로 선택하지 말고, 옵션을 제시한다.
- 더 단순한 방법이 있으면 말한다.

### 2. 단순함 우선
- 요청된 것만 구현한다. 추가 기능, 추가 유연성, 추가 설정 옵션 금지.
- 한 번만 쓰이는 코드에 추상화 레이어 만들지 않는다.
- 200줄짜리가 50줄로 가능하면 다시 쓴다.

### 3. 외과적 변경
- 요청과 직접 연관된 코드만 수정한다. 인접 코드 "개선" 금지.
- 기존 스타일(들여쓰기, 명명 규칙)을 그대로 따른다.
- 내 변경이 만든 미사용 import/변수는 즉시 제거한다.
- 기존 dead code는 발견해도 언급만 하고, 요청 없으면 삭제하지 않는다.

### 4. 목표 기반 실행
- 작업을 검증 가능한 목표로 변환한다.
  - "버그 수정" → "버그를 재현하는 테스트 작성 → 통과시키기"
- 복수 단계 작업은 계획을 먼저 제시한다.

---

## 아키텍처

```
lib/
├── features/          # 기능별 모듈 (auth, calendar, team, home, …)
│   └── <feature>/
│       ├── models/
│       ├── services/  # Firestore/로컬 DB 접근
│       ├── screens/
│       └── widgets/
├── core/
│   ├── constants/
│   ├── utils/         # DateHelper, LoggerUtil 등
│   └── widgets/       # 공용 위젯
├── data/              # 로컬 DB, 자산 파싱
├── routes/
└── main.dart
test/                  # 유닛 테스트 (fake_cloud_firestore 사용)
```

**원칙:**
- 기능은 `features/<name>/` 아래에 캡슐화한다.
- Firestore 직접 접근은 `services/` 레이어에만 허용한다. Screen/Widget에서 직접 접근 금지.
- 공용 유틸은 `core/`에, 특정 기능 전용이면 해당 feature 안에 둔다.

---

## Firestore 규칙

### 컬렉션 구조
```
teams/{teamId}
member_year_profiles/{year}/users/{uid}   # teamIds: List<String>
users/{uid}/completions/{docId}
users/{uid}/stats/{year}
```

### 다중 팀 소속 (teamIds)
- `member_year_profiles`의 팀 필드는 **`teamIds: List<String>`** (복수).
- 추가: `FieldValue.arrayUnion([teamId])`
- 제거: `FieldValue.arrayRemove([teamId])`
- 조회: `where('teamIds', arrayContains: teamId)`
- 구버전 `teamId: String` 필드에 대한 하위 호환 읽기는 `TeamService.getMyTeams()` 안에만 유지.

### N+1 쿼리 금지
- 루프 안에서 개별 Firestore 읽기 금지.
- 병렬 읽기: `Future.wait([...])`
- 예외: 로컬 연산(날짜 계산 등)은 순차도 무방.

### isTeamLeader 판별
- Firestore 필드 `isTeamLeader` 값을 그대로 신뢰하지 않는다.
- 팀별 리더 여부: `uid == team.leaderUid` 비교로 판별.

---

## 플랫폼 안전

### Web 안전
- `dart:io`(`File`, `Directory`, `getTemporaryDirectory()`)는 웹에서 크래시.
- `dart:io` 사용 전 반드시 `kIsWeb` 가드:
  ```dart
  if (!kIsWeb) { /* dart:io 코드 */ }
  ```
- `import 'package:flutter/foundation.dart'` 필요.

### 오프라인 우선
- 사용자 데이터는 SQLite에 먼저 쓴다. Firestore는 동기화 대상.
- 네트워크 없는 상태에서도 핵심 기능(오늘의 말씀, 완료 체크)이 동작해야 한다.

---

## 디버그 전용 코드

- 디버그 전용 코드는 반드시 `kDebugMode` 가드 안에 둔다:
  ```dart
  if (kDebugMode) { /* debug only */ }
  ```
- Firestore에 테스트 데이터를 쓸 때는 `_isTestData: true` 필드를 반드시 포함한다 (삭제 쿼리에 사용).
- 디버그용 클래스/파일 상단에 `// ⚠️ DEBUG ONLY` 주석과 삭제 시점을 명시한다.
- 릴리즈 빌드에 디버그 시드 함수가 노출되지 않도록 한다.

---

## 테스트

- 복잡한 비즈니스 로직(팀 멤버십, 날짜 계산)은 유닛 테스트로 커버한다.
- Firestore 의존 서비스는 생성자 DI(`FirebaseFirestore? firestore`, `String? testCurrentUid`)로 테스트 가능하게 만든다.
- 테스트에서 Firebase 초기화 불필요: `fake_cloud_firestore` + `testCurrentUid` 주입.
- 테스트 실행: `flutter test`

---

## 빌드 & 배포

```bash
# 의존성 설치
flutter pub get

# 분석
flutter analyze

# 테스트
flutter test

# iOS 릴리즈 빌드
flutter build ios --release

# Android 릴리즈 빌드
flutter build appbundle --release
```

---

## ⚠️ PR 머지 전 필수 검증 체크리스트

> PR 등록 또는 main 머지 전에 아래 항목을 **반드시** 직접 확인한다.
> 확인 없이 머지하거나 배포하지 않는다.

### 1. 정적 분석
- [ ] `flutter analyze` — 에러 0개
- [ ] `flutter test` — 전체 통과

### 2. Android 릴리즈 빌드 & 실기기 동작 확인
```bash
flutter build apk --release
adb install build/app/outputs/flutter-apk/app-release.apk
```
- [ ] 앱이 크래시 없이 정상 실행되는지 확인
- [ ] 홈 화면이 정상 렌더링되는지 확인
- [ ] 주요 변경 화면을 직접 탭해서 동작 확인

### 3. iOS 릴리즈 빌드 & 실기기/시뮬레이터 동작 확인
```bash
flutter build ios --release --no-codesign
```
- [ ] 빌드 에러 없음
- [ ] 시뮬레이터 또는 TestFlight에서 앱 정상 실행 확인
- [ ] 홈 화면이 정상 렌더링되는지 확인

### 4. 배포 전 추가 확인
- [ ] `kDebugMode` 블록 밖에 디버그 코드가 없는지 확인
- [ ] `_isTestData: true` 데이터가 프로덕션 Firestore에 남아있지 않은지 확인
- [ ] Firestore rules/indexes 변경 시 `firebase deploy --only firestore:rules,firestore:indexes` 실행
- [ ] `pubspec.yaml` 버전 번호 올렸는지 확인
- [ ] `fastlane/metadata/android/ko-KR/changelogs/{버전코드}.txt` 파일 추가했는지 확인

---

## 주요 유틸리티

| 유틸 | 위치 | 용도 |
|------|------|------|
| `DateHelper` | `core/utils/date_helper.dart` | 통독 주차/날짜 계산, 휴식주 판별 |
| `LoggerUtil` | `core/utils/logger_util.dart` | 로그 (릴리즈에서 자동 비활성화) |
| `ReadingPlanService` | `features/services/` | 날짜별 통독 계획 조회 |
| `TeamService` | `features/team/services/` | 팀 조회/팀원 관리 |

---

## 디자인 시스템

> **새 UI 작업 전 반드시 확인.** 상세 규칙은 memory/design.md 참고.

### 핵심 원칙
- **Card elevation 없음** — `BoxDecoration`으로 `border: Border.all(color: Color(0xFFE5E7EB))` 사용
- **인디고(#4F46E5)** = primary action. **그린(#059669)** = 완료 상태에만 사용
- **AppBar**: `elevation: 0, surfaceTintColor: Colors.transparent, backgroundColor: AppColors.background`
- **섹션 레이블**: `11px, FontWeight.w600, letterSpacing: 1.0, color: textTertiary`
- **Primary 버튼**: `FilledButton`, padding `vertical: 13`, radius `12`

### 팀 UI 규칙
- 팀명 표시: indigo pill 칩 (`#EEF2FF` 배경, `#4F46E5` 텍스트, radius 20)
- 팀원 주간 진행: 6개 dot row (월~토) — 완료=채움, 미완료=빈 원, 미래=회색 점
- 완료 판별: `weeklyCompletedDays >= weeklyTotalDays && weeklyTotalDays > 0` (future days 자동 제외)
- 히어로 카드: 인디고 배경, 44px bold 숫자, 6px progress bar
- **역할 통합 UX**: 팀원/팀장 동일 화면 → `isReadOnly = team.leaderUid != currentUid`
- 연도 선택: 드롭다운 (`getMyTeams(year: selectedYear)`)

### Playground 활용 규칙
- 디자인 변경 전 `team_ui_playground.html`로 먼저 시각화하고 피드백 받은 뒤 구현

---

## 알려진 구조적 결정

- **팀장+팀원 겸직**: 한 사람이 팀장이면서 다른 팀의 팀원일 수 있다. `teamIds` 배열로 처리.
- **다중 팀 팀장**: 한 팀장이 여러 팀을 관리할 수 있다. `getMyLeadingTeams()` 사용.
- **팀원 중복 소속**: 한 팀원이 여러 팀에 동시 소속 가능.
- **Excel → JSON → Firestore**: 팀 데이터는 `assets/data/teams_2026.json` → `RealTeamDataImporter`로 임포트.
