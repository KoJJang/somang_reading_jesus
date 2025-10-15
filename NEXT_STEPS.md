# 🚀 App Store 등록 다음 단계

## ✅ 완료된 작업

1. **iOS 빌드 성공**
   - Release 모드 빌드 완료 (421.0MB)
   - 모든 의존성 정상 설치
   - CocoaPods 연동 완료

2. **Info.plist 권한 설정 추가**
   - 사용자 추적 설명
   - 사진 라이브러리 접근 설명

3. **체크리스트 문서 작성**
   - `APP_STORE_CHECKLIST.md` 참고

## 🎯 즉시 수행할 작업

### 1. Archive 생성 (Xcode에서)

```bash
# 방법 1: Xcode GUI 사용 (권장)
1. Xcode에서 Runner.xcworkspace 열기:
   open ios/Runner.xcworkspace

2. 상단 메뉴에서:
   Product > Scheme > Edit Scheme
   - Run Configuration을 "Release"로 변경

3. 타겟 디바이스 선택:
   상단 바에서 "Any iOS Device (arm64)" 선택

4. Archive 생성:
   Product > Archive
   (단축키: Cmd + Shift + B)

5. Organizer 창에서:
   - 생성된 Archive 확인
   - "Distribute App" 클릭
   - "App Store Connect" 선택
   - "Upload" 클릭
```

### 2. App Store Connect 설정

1. **앱 생성** (https://appstoreconnect.apple.com)
   - Bundle ID: `com.somangchurch.readingjesus`
   - 앱 이름: "리딩 지저스 소망교회"
   - 기본 언어: 한국어

2. **필수 정보 입력**
   - [ ] 부제목 (30자): "소망교회 성경 통독 가이드"
   - [ ] 카테고리: Books 또는 Education
   - [ ] 가격: 무료
   - [ ] 개인정보 처리방침 URL (필수!)
   - [ ] 지원 URL (필수!)

3. **스크린샷 준비** (최소 3개)
   - iPhone 6.7" (1290 x 2796)
   - 또는 iPhone 6.5" (1242 x 2688)
   
   권장 화면:
   1. 메인 화면 (오늘의 말씀)
   2. 캘린더 화면
   3. 주간 진행 현황
   4. 완료 체크 화면

4. **앱 설명 작성**
```
소망교회 성경 통독을 위한 공식 앱입니다.

📖 주요 기능
• 45주 체계적인 성경 통독 일정
• 매일 읽을 말씀 안내
• 유튜브 강의 영상 연동
• 일별/주간 해설 이미지 제공
• 읽기 완료 체크 및 진행 현황
• 캘린더로 한눈에 보는 통독 현황
• Firebase 동기화로 기기 간 데이터 공유

✨ 특징
• 깔끔하고 직관적인 디자인
• 오프라인에서도 사용 가능
• 자동 동기화로 데이터 안전 보관
• 휴식 주간 자동 반영

※ 이 앱은 소망교회 성도들을 위한 통독 보조 도구입니다.
```

5. **키워드** (100자)
```
성경,통독,소망교회,리딩지저스,말씀,성경읽기,Bible,교회,기독교,성경공부
```

### 3. 심사 제출 전 체크

#### 필수 확인 사항
- [ ] 개인정보 처리방침 URL 준비 (웹사이트/문서)
- [ ] 지원 URL 준비 (문의 페이지)
- [ ] 테스트 계정 준비 (전화번호 인증용)
- [ ] 스크린샷 5-10개 준비
- [ ] 앱 아이콘 확인 (1024x1024, 알파 채널 없음)

#### 테스트 계정 정보 (심사자용)
```
전화번호: +82-10-XXXX-XXXX
인증번호: 테스트용 전화번호 제공 필요
```

### 4. 심사 시 예상 이슈 및 대응

#### 🚨 높은 확률로 문제될 수 있는 부분:

1. **전화번호 인증**
   - 문제: 테스트 계정 없이 진행 불가
   - 대응: App Review Information에 테스트 전화번호 제공

2. **외부 콘텐츠 (YouTube)**
   - 문제: 앱이 YouTube에 의존적
   - 대응: "YouTube는 보조 기능이며, 캘린더/진행률/동기화 등 독립적인 가치 제공" 명시

3. **개인정보 처리방침**
   - 문제: URL 누락 시 즉시 거부
   - 대응: 반드시 웹사이트에 게시 후 URL 제공

4. **제한적 사용자층**
   - 문제: "소망교회 전용"이 너무 제한적
   - 대응: "누구나 사용 가능하지만 소망교회 일정 기반" 명시

## 📊 예상 일정

| 단계 | 소요 시간 | 누적 시간 |
|------|----------|----------|
| Archive 생성 및 업로드 | 30분-1시간 | 1시간 |
| App Store Connect 설정 | 1-2시간 | 3시간 |
| 스크린샷 준비 | 1-2시간 | 5시간 |
| 심사 대기 | 1-3일 | 3일 |
| **총 예상 시간** | **3-5일** | - |

## 🔧 추가 명령어

### Archive 생성 (터미널)
```bash
# 1. Xcode에서 열기
open ios/Runner.xcworkspace

# 2. 또는 터미널에서 직접 Archive (고급)
xcodebuild -workspace ios/Runner.xcworkspace \
  -scheme Runner \
  -configuration Release \
  -archivePath build/Runner.xcarchive \
  archive

# 3. Export (Xcode Organizer 사용 권장)
xcodebuild -exportArchive \
  -archivePath build/Runner.xcarchive \
  -exportPath build/Runner.ipa \
  -exportOptionsPlist ios/ExportOptions.plist
```

### 빌드 확인
```bash
# 빌드 크기 확인
ls -lh build/ios/iphoneos/Runner.app

# 빌드 로그 확인
tail -100 build_log.txt
```

## 📞 문제 해결

### 빌드 실패 시
1. `flutter clean && flutter pub get`
2. `cd ios && pod deintegrate && pod install && cd ..`
3. Xcode에서 Derived Data 삭제

### Archive 실패 시
1. Xcode > Preferences > Accounts에서 Apple ID 확인
2. Signing & Capabilities 탭에서 팀 선택
3. Provisioning Profile 자동 생성 확인

### 업로드 실패 시
1. Xcode > Organizer > Archives 확인
2. "Validate App" 먼저 실행
3. 문제 해결 후 "Distribute App"

## 📱 연락처

- App Store Connect: https://appstoreconnect.apple.com
- Apple Developer: https://developer.apple.com
- Firebase Console: https://console.firebase.google.com

## ✨ 최종 체크리스트

출시 전 마지막 확인:
- [ ] Archive 생성 완료
- [ ] App Store Connect 업로드 완료
- [ ] 스크린샷 업로드 완료
- [ ] 앱 설명/키워드 입력 완료
- [ ] 개인정보 처리방침 URL 입력
- [ ] 지원 URL 입력
- [ ] 테스트 계정 정보 제공
- [ ] 가격/카테고리 설정
- [ ] "Submit for Review" 클릭

---

**🎉 모든 준비가 완료되었습니다!**

이제 Xcode에서 Archive를 생성하고 App Store Connect에 업로드하면 됩니다.
심사 승인까지 평균 1-3일 소요됩니다. 화이팅! 🚀

