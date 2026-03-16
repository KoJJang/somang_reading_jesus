# 배포 가이드

## ⚠️ 배포 전 필수 검증

> **배포 전 아래 항목을 반드시 직접 확인한다. 미확인 시 배포하지 않는다.**

### Android 동작 확인
```bash
flutter build apk --release
adb install build/app/outputs/flutter-apk/app-release.apk
adb shell am start -n com.somangchurch.readingjesus/.MainActivity
adb logcat | grep -E "I/flutter|E/flutter|FATAL"
```
- 앱이 크래시 없이 홈 화면까지 정상 도달하는지 확인

### iOS 동작 확인
```bash
flutter build ios --release --no-codesign
# Xcode 또는 시뮬레이터에서 실행 확인
```
- 앱이 크래시 없이 홈 화면까지 정상 도달하는지 확인

---

## Android 배포 명령어

```bash
# 내부 테스트 업로드 (빌드 + 메타데이터 포함)
BUNDLE_GEMFILE=fastlane/Gemfile bundle exec fastlane android beta

# 프로덕션 승격 (내부 테스트 → 프로덕션)
BUNDLE_GEMFILE=fastlane/Gemfile bundle exec fastlane android prod
```

## 배포 흐름

```
버전 번호 올리기 (pubspec.yaml)
        ↓
fastlane android beta   → 빌드 + 내부 테스트 트랙 업로드
        ↓
fastlane android prod   → 프로덕션 승격 → Google 심사 → 자동 출시
```

## 버전 관리

- `pubspec.yaml`의 `version: x.y.z+N` 에서 매 배포마다 버전 올리기
- 버전 코드(+N)는 항상 이전보다 높아야 함 — 동일 버전 코드 재업로드 불가
- 현재 프로덕션: `1.0.6+20`

## 메타데이터

Play Store 앱 소개 텍스트는 `fastlane/metadata/android/ko-KR/`에서 관리합니다.

| 파일 | 내용 |
|---|---|
| `title.txt` | 앱 이름 |
| `short_description.txt` | 짧은 설명 (80자 이내) |
| `full_description.txt` | 전체 설명 |
| `changelogs/{버전코드}.txt` | 새 버전 업데이트 내용 |

새 버전 출시 시 `changelogs/{버전코드}.txt` 파일을 추가해야 합니다.

### 스크린샷 추가 방법

1. `fastlane/metadata/android/ko-KR/images/phoneScreenshots/`에 이미지 추가
2. `fastlane/Fastfile`에서 `skip_upload_screenshots: false`로 변경
3. `fastlane android beta` 실행

## 사전 설정 (1회성)

### 필요 파일 (gitignore, 로컬에만 존재)

| 파일 | 설명 |
|---|---|
| `android/app/keystore/release-key.jks` | Android 서명 키스토어 |
| `fastlane/google_play_key.json` | Google Play 서비스 계정 키 |
| `fastlane/app_store_connect_api_key.p8` | iOS App Store Connect 키 |

### GitHub Secrets (등록 완료)

`ANDROID_KEYSTORE_BASE64`, `ANDROID_STORE_PASSWORD`, `ANDROID_KEY_PASSWORD`, `ANDROID_KEY_ALIAS`, `GOOGLE_PLAY_KEY_JSON`, `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_PRIVATE_KEY`, `IOS_DISTRIBUTION_CERT_BASE64`, `IOS_DISTRIBUTION_CERT_PASSWORD`

### Play Store 권한 설정

- Google Cloud 프로젝트 `415585262962`에서 Google Play Android Developer API 활성화
- Play Console → 사용자 및 권한에서 서비스 계정 `jonathan-jang@reading-jesus-somang.iam.gserviceaccount.com` 관리자 권한 추가
- Play Console 개인 계정에서는 "API 액세스" 메뉴가 노출되지 않음 → "사용자 및 권한"에서 직접 추가로 대체

## iOS 배포

- Fastfile에 `ios beta` / `ios prod` lane 준비됨
- App Store Connect 이메일: `yuiyui128@naver.com`
- 별도 세션에서 진행 예정
