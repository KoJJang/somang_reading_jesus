## 목표

관리자용 웹(Admin Console)을 만들어 아래 기능을 제공한다.

- **멤버 확인/검색/상세 보기**
- **멤버 정보 수정**
  - 교회(현재는 소망교회 단일이지만, 장기적으로 멀티 교회)
  - 팀(연도별로 팀이 달라질 수 있음)
  - 팀장 여부(연도별)
  - 이름(오입력 수정)
  - 소속, 권한(역할), 메모
- **멤버별 진도 확인** (주차/일차 기준 완료 현황, 기간/연도 필터)
- **연도별 일정 설정** (시작 주/시작일, 휴식 주 목록 관리)

---

## 핵심 원칙

- **완료 데이터는 “날짜”가 아니라 “(scheduleYear, week, day)” 기준으로 저장/조회**한다.
  - 일정이 이동(휴식 주 추가 등)되어도 진도 데이터의 의미가 유지된다.
- 일정 설정은 **연도별로 독립** 관리한다. (2025, 2026, ...)
- 팀 소속/팀장 여부는 **연도별로 독립** 관리한다.
- 관리 기능은 반드시 **권한(관리자)**이 있어야만 접근 가능하도록 한다.

---

## 사용자(관리자) 플로우

### 1) 로그인/권한 체크
- 관리자 웹 접속 → Firebase Auth 로그인
- 로그인 방식 권장(관리자 웹): **이메일/비밀번호 또는 Google 로그인**
  - 전화번호 로그인도 가능하지만 Web에서 reCAPTCHA 등 설정이 추가로 필요
- 로그인 후 사용자 토큰의 Custom Claims 또는 Firestore `roles` 문서로 `admin=true` 확인
- 권한 없으면 접근 차단

### 2) 멤버 목록
- 리스트(페이지네이션/검색)
- 필터: 교회, 연도, 팀, 팀장 여부, 상태(활성/비활성), 가입일 범위

### 3) 멤버 상세
- 프로필: 기본 정보, 마지막 활동(최근 완료), 가입/업데이트 시간
- 진도:
  - 연도 선택 (2025/2026)
  - 주차/일차 완료 매트릭스
  - 완료율(%) + 누적 완료 수

### 4) 일정 설정(연도별)
- 연도 선택/생성
- 시작일 설정(월요일 기준)
- 휴식 주 추가/삭제 (주 시작일 기준)
- 변경 사항 저장 시 앱에 즉시 반영

---

## 데이터 모델(제안)

### A) Users / Profiles (Firestore)
- `users/{uid}`
  - `displayName: string`
  - `phoneNumber: string`
  - `churchId: string`
  - `affiliation?: string` (소속)
  - `role?: 'member' | 'leader' | 'admin'` (권한)
  - `memo?: string`
  - `isActive: boolean`
  - `createdAt: Timestamp`
  - `updatedAt: Timestamp`

### A-1) Member profile per year (Firestore)  ✅ 연도별 팀/팀장
- `member_year_profiles/{scheduleYear}/users/{uid}`
  - `churchId: string`
  - `teamId?: string`
  - `isTeamLeader: boolean`
  - `updatedAt: Timestamp`
  - `updatedBy: uid`

### A-2) Teams (Firestore)
- `churches/{churchId}`
  - `name: string`
- `churches/{churchId}/teams/{teamId}`
  - `scheduleYear: number`
  - `name: string`
  - `createdAt: Timestamp`
  - `updatedAt: Timestamp`

### B) Reading Completions (Firestore)
- `reading_completions/{uid}/years/{scheduleYear}/weeks/{week}/days/{day}`
  - `completedAt: Timestamp`
  - `deviceTime: Timestamp` (선택)
  - `source: 'app' | 'admin'` (선택)

> 주의: 현재 앱의 저장 구조가 다르면 “관리자 웹”은 **기존 구조를 우선 존중**하고, 이후 마이그레이션 플랜을 세운다.

### C) Schedule Config (Firestore)
- `schedule_configs/{scheduleYear}`
  - `startDate: Timestamp` (해당 연도 시작일)
  - `breakWeeks: array<Timestamp>` (각 항목은 “휴식 주”의 기준일(월요일 권장))
  - `updatedAt: Timestamp`
  - `updatedBy: uid`

---

## 기술 스택 제안 (3안)

### Option 1) Flutter Web (같은 코드베이스)
- 장점: 기존 Flutter 스타일/컴포넌트 재사용, 단일 repo
- 단점: 웹 특화 DX(테이블/필터/대시보드)는 React 대비 불편할 수 있음

### Option 2) Next.js(React) + Firebase
- 장점: 관리 도구에 최적(테이블, 차트, 폼), 개발 속도 빠름
- 단점: 별도 프론트 스택/빌드 파이프라인 추가

### Option 3) Vite(React) + Firebase (정적 배포) ✅ NAS 친화
- 장점: `npm run build` 산출물이 정적 파일이라 **NAS 배포가 가장 간단**
- 단점: 서버 사이드 렌더링/서버 기능은 없음(관리자 콘솔엔 문제 없음)

권장: **Vite(React) + Firebase** (NAS에 올리기 가장 쉬움)

---

## MVP 범위 (1차 릴리즈)

- 관리자 로그인 + 권한 체크
- 멤버 목록(검색: 이름/전화)
- 멤버 상세:
  - 연도 선택
  - 주차/일차 완료 현황(그리드)
  - 완료율/누적 완료
- 일정 설정:
  - 연도 선택
  - 시작일 설정
  - 휴식 주 추가/삭제

---

## 2차 범위 (고도화)

- 그룹(소그룹/교구) 관리 및 그룹별 통계
- 멤버 초대/탈퇴/비활성 처리
- 리포트(주간/월간) 및 CSV Export
- 감사 로그(Audit log)
- 앱 푸시/공지 발송(선택)

---

## 보안/권한

- Firestore Rules에서 `admin`만:
  - `schedule_configs/*` read/write
  - 사용자 프로필 write
  - 전체 completion read
- 일반 유저는 자기 completion만 read/write

---

## 다음 질문(기획 확정용)

확정:
- 멤버 정보: 교회/팀(연도별)/팀장 여부(연도별)/이름/소속/권한/메모 수정
- 로그인: 전화번호 로그인 유지 가능(관리자 웹은 이메일/구글 권장)
- 일정: startDate(월요일) + breakWeeks(주 단위)면 충분
- 호스팅: 장기적으로 NAS, 우선은 정적 배포(Vite)로 시작


