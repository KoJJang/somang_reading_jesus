# 디자인 시스템

> 코드에서 실제 사용되는 패턴을 기준으로 작성한 문서입니다.  
> 새 화면을 만들 때 이 문서를 먼저 참고하고, 여기 없는 패턴을 추가할 때는 문서를 업데이트하세요.

---

## 1. 색상 (AppColors)

```dart
import 'package:reading_jesus_somang/core/constants/app_colors.dart';
```

### Primary
| 상수 | 색상 | 용도 |
|---|---|---|
| `primary` | `#4F46E5` | 버튼, 강조 요소, 인터랙티브 아이콘 |
| `primaryLight` | `#EEF2FF` | 팀 태그 배경, 연한 강조 배경 |
| `primaryLighter` | `#E0E7FF` | 완료 도트 배경 (미전체완료) |
| `primaryMuted` | `#6366F1` | 태그 텍스트, 덜 강한 primary |

### Text
| 상수 | 색상 | 용도 |
|---|---|---|
| `textPrimary` | `#111827` | 제목, 주요 본문 |
| `textSecondary` | `#6B7280` | 부제목, 레이블, 설명 |
| `textTertiary` | `#9CA3AF` | 힌트, 캡션, 비활성 텍스트, 아이콘 |

### Surface / Border
| 상수 | 색상 | 용도 |
|---|---|---|
| `background` | `#F9FAFB` | 화면 배경 (Scaffold) |
| `cardBackground` | `#FFFFFF` | 카드, 모달 표면 |
| `border` | `#E5E7EB` | 카드 테두리, 구분선 |
| `surfaceGray` | `#F3F4F6` | 미래 일정, progress bar 배경, 비활성 영역 |
| `disabled` | `#D1D5DB` | 비활성 컨트롤, 미완료 도트 테두리 |

### Status — Completed (초록)
| 상수 | 색상 | 용도 |
|---|---|---|
| `completed` | `#059669` | 완료 아이콘, 텍스트, 강조 |
| `completedLight` | `#F0FDF4` | 완료 카드 배경 |
| `completedBorder` | `#BBF7D0` | 완료 카드 테두리 |
| `completedSubtle` | `#D1FAE5` | 완료 아바타 배경 |

### 규칙
- 하드코딩 색상(`Color(0x...)`) 사용 금지 — 항상 `AppColors.*` 사용
- 새 색상이 필요하면 `app_colors.dart`에 의미 있는 이름으로 추가

---

## 2. 타이포그래피

별도 `TextStyle` 상수는 없으므로 아래 조합을 그대로 사용합니다.

| 용도 | fontSize | fontWeight | color |
|---|---|---|---|
| 히어로 숫자 | `44` | `w800` | 상황에 따라 |
| 화면 제목 (AppBar) | Material 기본 | — | — |
| 카드 제목 | `16–17` | `w700` | `textPrimary` |
| 섹션 레이블 | `13` | `w600` | `textSecondary` |
| 본문 | `14` | `w400–w500` | `textPrimary` |
| 서브텍스트 | `13` | `w400` | `textSecondary` |
| 캡션 / 힌트 | `12` | `w500` | `textTertiary` |
| 배지 / 태그 | `10–11` | `w600` | 상황에 따라 |

---

## 3. 간격 (Spacing)

`AppSizes` 상수를 우선 사용하고, 없는 값은 직접 지정합니다.

```dart
AppSizes.paddingXS = 4
AppSizes.paddingS  = 8
AppSizes.paddingM  = 16
AppSizes.paddingL  = 24
AppSizes.paddingXL = 32
```

### 실사용 패턴

| 상황 | 값 |
|---|---|
| 화면 좌우 패딩 | `20` |
| 화면 하단 패딩 | `40` (리스트) |
| 카드 내부 패딩 | `horizontal: 14–18, vertical: 12–16` |
| 히어로 카드 패딩 | `all: 20` |
| 카드 간격 | `bottom: 8–12` |
| 제목 ↔ 서브텍스트 | `6` |
| 아이콘 ↔ 텍스트 | `8–12` |
| 배지와 이름 사이 | `6` |
| 바텀시트 패딩 | `fromLTRB(20, 12, 20, 20)` |
| 빈 상태 아이콘 ↔ 텍스트 | `12–16` |

---

## 4. 모서리 반지름 (Border Radius)

| 값 | 적용 대상 |
|---|---|
| `3–4` | Progress bar, 배지/칩 |
| `8` | 드롭다운, 소형 버튼 |
| `10–12` | 버튼, 멤버 카드, 소형 카드 |
| `14` | 팀 목록 카드 |
| `18` | 히어로 카드 |
| `20` | 바텀시트, 원형 칩 태그 |

---

## 5. 컴포넌트 패턴

### 5-1. 카드 (기본)

```dart
Container(
  margin: const EdgeInsets.only(bottom: 12),
  decoration: BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(14),
    border: Border.all(color: AppColors.border),
  ),
  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
  child: ...,
)
```

**상태별 변형:**

| 상태 | color | border color |
|---|---|---|
| 기본 | `Colors.white` | `AppColors.border` |
| 완료 | `AppColors.completedLight` | `AppColors.completedBorder` |
| 비활성/미래 | `AppColors.background` | `AppColors.border` |

### 5-2. 목록 항목 (탭 가능한 카드)

```dart
Container(
  margin: const EdgeInsets.only(bottom: 8),
  decoration: BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(12),
    border: Border.all(color: AppColors.border),
  ),
  child: InkWell(
    borderRadius: BorderRadius.circular(12), // 카드와 동일해야 ripple이 자연스러움
    onTap: () => ...,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          // 아바타 (선택)
          CircleAvatar(radius: 18, ...),
          const SizedBox(width: 12),
          // 콘텐츠
          Expanded(child: Column(...)),
          // 우측 메타 + 화살표
          Text(...),
          const Icon(Icons.chevron_right, size: 18, color: AppColors.textTertiary),
        ],
      ),
    ),
  ),
)
```

### 5-3. AppBar

```dart
AppBar(
  title: Text(title),
  backgroundColor: AppColors.background,
  elevation: 0,
  surfaceTintColor: Colors.transparent,
  actions: [...], // 선택
)
```

- 배경은 항상 `AppColors.background` (흰색 아님)
- elevation, surfaceTintColor 항상 0 / transparent

### 5-4. 버튼

**주요 액션 (다이얼로그 확인 등):**
```dart
FilledButton(
  onPressed: ...,
  child: const Text('확인'),
)
```

**보조 액션 (화면 내 버튼):**
```dart
SizedBox(
  width: double.infinity,
  child: OutlinedButton.icon(
    icon: const Icon(Icons.group, size: 18),
    label: const Text('팀 현황 보기'),
    style: OutlinedButton.styleFrom(
      foregroundColor: AppColors.textSecondary,
      side: const BorderSide(color: AppColors.border),
      padding: const EdgeInsets.symmetric(vertical: 13),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
    ),
  ),
)
```

- 화면 내 단독 버튼은 항상 `width: double.infinity`
- 아이콘 크기 `17–18`

### 5-5. 배지 / 태그

**인라인 배지 (팀장, 역할 등):**
```dart
Container(
  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
  decoration: BoxDecoration(
    color: AppColors.primary.withValues(alpha: 0.1),
    borderRadius: BorderRadius.circular(4),
  ),
  child: Text(
    '팀장',
    style: const TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w600,
      color: AppColors.primary,
    ),
  ),
)
```

**팀 이름 태그 (칩):**
```dart
Container(
  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
  decoration: BoxDecoration(
    color: AppColors.primaryLight,
    borderRadius: BorderRadius.circular(20),
  ),
  child: Text(
    team.name,
    style: const TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w500,
      color: AppColors.primaryMuted,
    ),
  ),
)
```

### 5-6. 빈 상태 (Empty State)

```dart
Center(
  child: Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Icon(Icons.group_off, size: 48, color: AppColors.textTertiary),
      const SizedBox(height: 16),
      Text(
        '소속 팀이 없습니다',
        style: const TextStyle(fontSize: 17, color: AppColors.textSecondary),
      ),
      const SizedBox(height: 6),
      Text(
        '보조 설명 문구',
        style: const TextStyle(fontSize: 13, color: AppColors.textTertiary),
        textAlign: TextAlign.center,
      ),
    ],
  ),
)
```

- 아이콘 크기 `48`, 색상 `textTertiary`
- 주 메시지 `fontSize: 17`, `textSecondary`
- 보조 메시지 `fontSize: 13`, `textTertiary`

### 5-7. 로딩 / 새로고침

```dart
// 초기 로딩
body: _isLoading
    ? const Center(child: CircularProgressIndicator())
    : RefreshIndicator(
        onRefresh: _loadData,
        child: ListView(...),
      )
```

- 항상 `RefreshIndicator`로 리스트 감싸기 (풀투리프레시 지원)

---

## 6. 섹션 레이블 패턴

화면 내 섹션 구분에 사용:

```dart
Text(
  'TEAM',  // 또는 '팀원 진행상황'
  style: const TextStyle(
    fontSize: 11,       // 영문 대문자 섹션: 11px
    fontWeight: FontWeight.w600,
    letterSpacing: 1.0, // 영문 대문자만 letterSpacing 적용
    color: AppColors.textTertiary,
  ),
)
```

---

## 7. 새 화면 체크리스트

새 화면을 만들 때 확인:

- [ ] `Scaffold.backgroundColor: AppColors.background`
- [ ] AppBar에 `elevation: 0`, `surfaceTintColor: Colors.transparent`
- [ ] 리스트는 `ListView` + `RefreshIndicator` + `fromLTRB(20, 8, 20, 40)` padding
- [ ] 카드는 `Border.all(color: AppColors.border)` 항상 포함
- [ ] 탭 가능한 카드는 `InkWell(borderRadius: ...)` — `GestureDetector` 사용 지양
- [ ] 하드코딩 색상 없이 `AppColors.*` 사용
- [ ] 로딩 / 빈 상태 / 에러 상태 UI 모두 구현
- [ ] 텍스트에 `overflow: TextOverflow.ellipsis` 또는 `Expanded` 처리
