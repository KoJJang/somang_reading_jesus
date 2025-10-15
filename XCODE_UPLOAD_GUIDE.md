# 📱 Xcode를 이용한 App Store 업로드 가이드

## 🎯 간단 요약 (기존 앱 업데이트)

기존에 배포된 앱이므로 새 빌드만 올리면 됩니다!

---

## 📋 단계별 가이드

### 1️⃣ Xcode 설정 확인 (이미 열림)

현재 `Runner.xcworkspace`가 열렸습니다.

**확인 사항:**
1. **상단 바에서 타겟 디바이스 선택**
   - `Any iOS Device (arm64)` 선택
   - ⚠️ 시뮬레이터가 아닌 실제 디바이스 선택 필수!

2. **Scheme 확인**
   - 상단 바 `Runner` 옆에 현재 scheme 확인
   - Product > Scheme > Edit Scheme (⌘ + <)
   - Run의 Build Configuration이 **"Release"**인지 확인
   - 보통은 Archive 시 자동으로 Release로 설정됨

### 2️⃣ Archive 생성

```
방법 1: 메뉴 사용
Product > Archive (⌘ + Shift + B)

방법 2: 단축키
⌘ (Cmd) + Shift + B
```

**진행 상황:**
- 빌드 시작되면 상단에 진행률 표시
- 약 3-5분 소요 (프로젝트 크기에 따라)
- 완료되면 자동으로 Organizer 창 열림

### 3️⃣ Organizer에서 업로드

**Organizer 창이 열리면:**

1. **왼쪽 Archives 탭 확인**
   - 방금 생성한 Archive가 맨 위에 있음
   - 날짜/시간으로 확인 가능

2. **"Distribute App" 버튼 클릭** (오른쪽 파란 버튼)

3. **배포 방법 선택**
   ```
   ○ App Store Connect (선택!)
   ○ Ad Hoc
   ○ Enterprise
   ○ Development
   ```
   → **"App Store Connect" 선택** → Next

4. **업로드 옵션**
   ```
   ○ Upload (선택!)
   ○ Export
   ```
   → **"Upload" 선택** → Next

5. **서명 옵션**
   ```
   ☑ Automatically manage signing (보통 체크)
   ```
   → Next

6. **검토 및 업로드**
   - 앱 정보 확인
   - Bundle ID: `com.somangchurch.readingjesus`
   - Version: 1.0.1
   - Build: 1
   
   → **"Upload" 버튼 클릭**

### 4️⃣ 업로드 진행

```
업로드 중... (3-10분 소요)
├─ Preparing app for upload...
├─ Performing authentication...
├─ Uploading binary...
└─ Upload successful ✓
```

**완료 메시지:**
```
Upload Successful
Your app has been uploaded to App Store Connect.
```

### 5️⃣ App Store Connect에서 확인

**1. App Store Connect 접속**
- https://appstoreconnect.apple.com
- 로그인

**2. 내 앱 선택**
- "리딩 지저스 소망교회" 클릭

**3. 빌드 확인**
- 왼쪽 메뉴: TestFlight 또는 App Store
- 약 10-30분 후 새 빌드 표시됨
  ```
  Processing... → Ready to Submit
  ```

**4. 새 버전 제출** (필요한 경우)
- "+" 버튼으로 새 버전 추가
- 또는 기존 버전에 새 빌드 선택
- "Submit for Review" 클릭

---

## 🔧 문제 해결

### Archive 버튼이 비활성화된 경우
**원인:** 디바이스가 시뮬레이터로 선택됨
**해결:**
1. 상단 바에서 `Any iOS Device (arm64)` 선택
2. 또는 `Generic iOS Device` 선택

### 서명 오류 발생
**원인:** Apple ID 또는 Provisioning Profile 문제
**해결:**
1. Xcode > Preferences > Accounts
2. Apple ID 확인/추가
3. Download Manual Profiles 클릭
4. Runner 타겟 > Signing & Capabilities
5. Team 선택 확인

### 업로드 실패
**원인:** 네트워크 또는 인증 문제
**해결:**
1. "Validate App" 먼저 실행 (Organizer에서)
2. 문제 확인 및 수정
3. 다시 "Distribute App" 시도

### Archive가 생성 안 됨
**터미널에서 수동 생성:**
```bash
flutter build ios --release

cd ios

xcodebuild -workspace Runner.xcworkspace \
  -scheme Runner \
  -configuration Release \
  -archivePath ../build/Runner.xcarchive \
  archive
```

---

## 📝 현재 버전 정보

```yaml
name: reading_jesus_somang
version: 1.0.1+1
  ├─ Version: 1.0.1
  └─ Build: 1

Bundle ID: com.somangchurch.readingjesus
```

**다음 업데이트 시:**
- 마이너 변경: `1.0.1` → `1.0.2`
- 메이저 변경: `1.0.1` → `1.1.0`
- Build 번호는 항상 증가: `1` → `2` → `3`...

---

## ⚡ 빠른 체크리스트

기존 앱 업데이트 시:

- [x] Xcode 열기 (`Runner.xcworkspace`)
- [ ] 타겟: `Any iOS Device (arm64)` 선택
- [ ] Product > Archive (⌘ + Shift + B)
- [ ] Organizer에서 "Distribute App"
- [ ] "App Store Connect" 선택
- [ ] "Upload" 선택
- [ ] 업로드 완료 대기
- [ ] App Store Connect에서 빌드 확인
- [ ] 새 버전에 빌드 연결
- [ ] Submit for Review

**예상 소요 시간:** 15-30분

---

## 💡 팁

1. **빌드 번호 증가**
   - `pubspec.yaml`에서 `version: 1.0.1+1`의 `+1` 부분을 `+2`로 증가
   - 재빌드 후 Archive 생성

2. **여러 버전 관리**
   - Organizer에서 모든 이전 Archive 확인 가능
   - Window > Organizer (⌘ + Shift + Option + O)

3. **자동 서명 권장**
   - "Automatically manage signing" 체크
   - Xcode가 자동으로 Provisioning Profile 관리

4. **TestFlight 배포**
   - 정식 출시 전 테스트 필요 시
   - App Store Connect > TestFlight
   - 내부/외부 테스터에게 배포 가능

---

**🎉 준비 완료!**

이제 Xcode에서:
1. Any iOS Device 선택
2. Product > Archive (⌘ + Shift + B)
3. Distribute App > App Store Connect > Upload

이렇게만 하면 됩니다! 화이팅! 🚀

