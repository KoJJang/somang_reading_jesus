# App Store 제출 체크리스트

## ⚠️ 필수 수정 사항

### 1. 개인정보 보호 정책 URL (Critical)
**문제**: Info.plist에 개인정보 처리방침 URL이 없습니다.
**해결**: 
- Firebase Auth를 사용하므로 개인정보 처리방침 필수
- Info.plist에 다음 추가 필요:
```xml
<key>NSUserTrackingUsageDescription</key>
<string>사용자 경험 개선을 위해 데이터를 수집합니다.</string>
```

### 2. 앱 아이콘 검증
**확인 필요**: 
- `assets/images/icon.png`가 1024x1024 PNG인지 확인
- 알파 채널 없는지 확인 (iOS 요구사항)

### 3. 버전 정보
**현재 상태**:
- Version: 1.0.1
- Build: 1
- Bundle ID: com.somangchurch.readingjesus

**권장**:
- 첫 출시라면 1.0.0+1로 변경 권장

## 📋 App Store Connect 준비사항

### 1. 필수 정보
- [ ] 앱 이름: "리딩 지저스 소망교회"
- [ ] 부제목 (30자 이하)
- [ ] 카테고리: Books 또는 Education
- [ ] 연령 등급 설정
- [ ] 개인정보 처리방침 URL
- [ ] 지원 URL
- [ ] 마케팅 URL (선택)

### 2. 스크린샷 준비
**필수**:
- iPhone 6.7" (iPhone 15 Pro Max): 1290 x 2796
- iPhone 6.5" (iPhone 11 Pro Max): 1242 x 2688
- 최소 3개, 최대 10개

**권장 화면**:
1. 메인 화면 (오늘의 말씀)
2. 캘린더 화면
3. 주간 진행 현황
4. 통독 완료 화면
5. 일별/주간 해설 화면

### 3. 앱 설명 (4000자 이하)
```
소망교회 성경 통독을 위한 공식 앱입니다.

주요 기능:
• 45주 체계적인 성경 통독 일정
• 매일 읽을 말씀 안내
• 유튜브 강의 연동
• 일별/주간 해설 이미지
• 읽기 완료 체크 및 진행 현황
• 캘린더로 한눈에 보는 통독 현황
• Firebase 동기화로 기기 간 데이터 공유

※ 이 앱은 소망교회 성도들을 위한 통독 보조 도구입니다.
```

### 4. 키워드 (100자 이하, 쉼표로 구분)
```
성경,통독,소망교회,리딩지저스,말씀,성경읽기,Bible,교회,기독교
```

### 5. 앱 미리보기 (선택사항)
- 15-30초 동영상
- 앱 사용 시연

## 🔍 App Store Review 주의사항

### 1. 전화번호 인증 (Firebase Auth)
**현재 상태**: 전화번호 로그인 사용 중
**필요 조치**:
- 테스트 계정 정보 제공 필수
- Info.plist에 권한 설명 추가:
```xml
<key>NSContactsUsageDescription</key>
<string>전화번호 인증을 위해 연락처 권한이 필요합니다.</string>
```

### 2. 외부 링크 (YouTube)
**현재 상태**: YouTube 강의 링크 연결
**가능한 거부 사유**:
- 외부 콘텐츠 의존도가 높음
- 앱 내 충분한 기능이 있는지 검토

**대응 방안**:
- 앱 내 독립적인 가치 강조 (캘린더, 진행 현황, 동기화 등)
- YouTube는 보조 기능임을 명시

### 3. 콘텐츠 권한
**확인 필요**:
- 해설 이미지 저작권 확인
- 성경 구절 저작권 (번역본 확인)

### 4. 타겟 사용자
**문제**: "소망교회 성도용"으로 제한적
**대응**:
- 앱 설명에 "누구나 사용 가능하지만 소망교회 일정에 맞춰져 있음" 명시
- 또는 "조직 내부용 앱"으로 분류 고려

## 🛠️ 빌드 전 필수 작업

### 1. Info.plist 수정 필요
```xml
<!-- 추가 필요 -->
<key>NSUserTrackingUsageDescription</key>
<string>더 나은 서비스 제공을 위해 사용자 데이터를 수집합니다.</string>

<key>NSContactsUsageDescription</key>
<string>전화번호 인증을 위해 필요합니다.</string>
```

### 2. 빌드 명령어
```bash
# 1. 의존성 설치
flutter pub get
cd ios && pod install && cd ..

# 2. 빌드 (Release 모드)
flutter build ios --release

# 3. Archive 생성 (Xcode에서)
# Xcode > Product > Archive
# 또는
xcodebuild -workspace ios/Runner.xcworkspace \
  -scheme Runner \
  -configuration Release \
  -archivePath build/Runner.xcarchive \
  archive
```

### 3. 테스트 필수 항목
- [ ] Release 모드에서 Firebase 연동 정상 작동
- [ ] 전화번호 인증 정상 작동
- [ ] YouTube 링크 열기 정상 작동
- [ ] 이미지 로딩 정상 작동
- [ ] 데이터 동기화 정상 작동
- [ ] 다크모드 대응 확인
- [ ] 다양한 화면 크기 테스트

## 📱 제출 프로세스

1. **App Store Connect에서 앱 생성**
   - Bundle ID: com.somangchurch.readingjesus
   - 앱 이름: 리딩 지저스 소망교회

2. **Xcode에서 Archive 업로드**
   - Window > Organizer
   - Archive 선택 > Distribute App
   - App Store Connect 선택

3. **App Store Connect에서 빌드 선택**
   - 업로드된 빌드 선택
   - 스크린샷 업로드
   - 설명 작성
   - 심사 제출

## ⏱️ 예상 일정

- Archive 생성: 5-10분
- 업로드: 10-30분
- 처리 대기: 1-24시간
- 심사: 1-3일 (평균 24시간)
- 거부 시 수정/재제출: +1-2일

## 🚨 흔한 거부 사유

1. **개인정보 처리방침 누락** → 필수 추가
2. **전화번호 인증 테스트 불가** → 테스트 계정 제공
3. **외부 콘텐츠 의존** → 앱 내 가치 강조
4. **제한적 타겟 사용자** → 설명 수정
5. **앱 충돌** → 철저한 테스트
6. **개인정보 수집 동의 미흡** → 명시적 동의 화면 추가

## 📞 지원

문제 발생 시:
1. App Store Connect > 내 앱 > 앱 정보 > 연락처
2. Apple Developer Forum
3. Apple Developer Support (유료 계정)

