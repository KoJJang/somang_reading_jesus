# 리딩 지저스 소망 교회 (Reading Jesus Somang Church)

## 프로젝트 개요

리딩 지저스는 소망 교회의 성경 통독을 위한 모바일 앱입니다. 이 앱은 사용자들이 매일 정해진 성경 구절을 읽고 기록할 수 있도록 도와주며, 통독 진행 상황을 추적하고 시각화하여 지속적인 성경 읽기를 장려합니다.

## 주요 기능

- **일일 통독 계획**: 매일 읽어야 할 성경 구절 안내
- **통독 진행 상황 시각화**: 주간 및 연간 통독 진행 상황 확인
- **성경 읽기**: 앱 내에서 직접 성경 구절 읽기
- **완료 표시**: 일일 통독 완료 표시 및 기록
- **달력 보기**: 월별 통독 현황 확인
- **휴대폰 인증**: 사용자 계정 관리 및 데이터 동기화
- **클라우드 동기화**: Firebase를 통한 여러 기기 간 데이터 동기화

## 앱 구조

```
lib/
├── core/                 # 핵심 유틸리티 및 상수
│   ├── constants/        # 앱 테마, 색상 등 상수
│   └── utils/            # 유틸리티 함수
│
├── data/                 # 데이터 계층
│   ├── models/           # 데이터 모델
│   ├── repositories/     # 데이터 저장소
│   └── services/         # 데이터 서비스
│
├── features/             # 앱 기능별 모듈
│   ├── auth/             # 인증 관련 기능
│   │   ├── controllers/  # 인증 컨트롤러
│   │   ├── models/       # 인증 모델
│   │   └── screens/      # 인증 화면
│   │
│   ├── bible/            # 성경 읽기 기능
│   │   └── screens/      # 성경 화면
│   │
│   ├── calendar/         # 달력 기능
│   │   └── screens/      # 달력 화면
│   │
│   ├── home/             # 홈 화면 기능
│   │   ├── screens/      # 홈 화면
│   │   └── widgets/      # 홈 화면 위젯
│   │
│   ├── layout/           # 레이아웃 관련 컴포넌트
│   │   └── app_layout.dart  # 앱 기본 레이아웃
│   │
│   └── services/         # 비즈니스 로직 서비스
│
└── main.dart             # 앱 진입점
```

## 기술 스택

- **프레임워크**: Flutter
- **데이터베이스**: 
  - SQLite (로컬 데이터 저장)
  - Firebase Firestore (클라우드 동기화)
- **인증**: Firebase Authentication (휴대폰 인증)
- **상태 관리**: StatefulWidget (향후 Riverpod으로 마이그레이션 예정)

## 주요 컴포넌트 설명

### 1. 홈 화면 (HomeScreen)

홈 화면은 사용자의 통독 진행 상황과 오늘의 읽기 계획을 보여줍니다. 주요 컴포넌트:

- **ReadingCard**: 오늘의 성경 구절 정보
- **WeeklyProgressCard**: 이번 주 통독 진행 상황
- **DailyPlan**: 오늘의 통독 계획 상세 정보
- **완료 버튼**: 오늘의 통독 완료 표시

### 2. 데이터 관리 (ReadingService)

`ReadingService`는 통독 데이터를 관리하는 중심 서비스입니다:

- 로컬 저장소와 Firebase 동기화
- 통독 완료 표시 및 기록
- 사용자 통계 데이터 관리

### 3. 인증 시스템 (AuthService)

`AuthService`는 Firebase를 사용한 휴대폰 인증을 처리합니다:

- SMS 인증 코드 전송 및 확인
- 사용자 로그인/로그아웃 관리
- 인증 상태 모니터링

### 4. 오프라인 우선 접근 방식

앱은 오프라인 우선 접근 방식으로 설계되었습니다:

- 로컬 SQLite DB에 먼저 데이터 저장
- 인터넷 연결 시 Firebase와 데이터 동기화
- 오프라인 상태에서도 완전한 기능 사용 가능

## 설치 및 실행 방법

### 요구 사항

- Flutter SDK (3.7.0 이상)
- Dart SDK (3.0.0 이상)
- Android Studio 또는 VS Code
- Firebase 프로젝트 (인증 및 Firestore 활성화)

### 설치 단계

1. 저장소 클론:
   ```bash
   git clone https://github.com/your-username/somang_reading_jesus.git
   cd somang_reading_jesus
   ```

2. 의존성 설치:
   ```bash
   flutter pub get
   ```

3. Firebase 설정:
   - Firebase 콘솔에서 새 프로젝트 생성
   - FlutterFire CLI를 통해 앱 연결:
     ```bash
     dart pub global activate flutterfire_cli
     flutterfire configure
     ```

4. 앱 실행:
   ```bash
   flutter run
   ```

## 배포 정보

- **Android 패키지명**: com.somangchurch.readingjesus
- **iOS Bundle ID**: com.somangchurch.readingjesus
- **최소 Android SDK**: 23 (Android 6.0)
- **최소 iOS 버전**: 14.0

## 향후 개선 계획

- **상태 관리 개선**: Riverpod 및 freezed를 사용한 상태 관리 도입
- **UI 개선**: 더 나은 사용자 경험을 위한 UI/UX 개선
- **기능 확장**: 성경 구절 공유, 메모 기능 등 추가
- **다국어 지원**: 다양한 언어 지원 추가

## 라이선스

이 프로젝트는 소망 교회의 통독 앱으로, 모든 권리는 소망 교회에 있습니다.

## 스크린샷

(앱 스크린샷은 여기에 추가될 예정입니다)
