# 📦 앱 크기 최적화 가이드

## 현재 상태 (105.9MB)

### 크기 구성
```
성경 DB:        11MB  (10%)
폰트:           14MB  (13%)
이미지:         79MB  (75%)
Flutter 엔진:    2MB   (2%)
```

---

## 🎯 추가 최적화 방안

### 1. 폰트 최적화 (14MB → 3MB) ⭐ 추천

#### 현재
- Pretendard 9개 weight 모두 포함
- Thin(100), ExtraLight(200), Light(300), Regular(400), Medium(500), SemiBold(600), Bold(700), ExtraBold(800), Black(900)

#### 최적화
**필요한 weight만 선택** (약 11MB 절감)
```yaml
fonts:
  - family: Pretendard
    fonts:
      - asset: assets/fonts/Pretendard-Regular.otf
        weight: 400
      - asset: assets/fonts/Pretendard-Medium.otf
        weight: 500
      - asset: assets/fonts/Pretendard-SemiBold.otf
        weight: 600
      - asset: assets/fonts/Pretendard-Bold.otf
        weight: 700
```
절감: **~11MB (80% 감소)**

---

### 2. 성경 DB 최적화 (11MB → 6MB)

#### 방법 A: 하나의 DB만 사용
현재 2개 DB 사용 중:
- `bible2.db` (5.9MB)
- `bible_korHRV.db` (5.5MB)

→ 실제로 둘 다 필요한지 확인 후 하나만 사용

#### 방법 B: On-Demand 다운로드
- 앱 설치 시 기본 DB만 포함
- 필요시 추가 번역본 다운로드

절감: **~5MB (50% 감소)**

---

### 3. 이미지 On-Demand 다운로드 ⭐⭐ 강력 추천

#### 현재 문제
- 270개 이미지 모두 APK에 포함
- 사용자가 모든 이미지를 바로 필요로 하지 않음

#### 해결 방안
**Firebase Storage 또는 GitHub에서 동적 로딩**

```dart
// 예시 구조
class DynamicImageLoader {
  Future<String> getImageUrl(String imagePath) async {
    // 1. 로컬 캐시 확인
    if (await isImageCached(imagePath)) {
      return getLocalPath(imagePath);
    }
    
    // 2. 다운로드 & 캐시
    final url = 'https://your-cdn.com/images/$imagePath';
    await downloadAndCache(url, imagePath);
    return getLocalPath(imagePath);
  }
}
```

**장점:**
- 초기 설치 크기: **26MB** (79MB 감소!)
- 네트워크 있을 때 자동 다운로드
- 한번 다운로드 후 캐시에 저장

**단점:**
- 첫 사용 시 다운로드 필요
- 오프라인에서 일부 이미지 안 보임

절감: **~79MB (100% 감소, 대신 온디맨드)**

---

### 4. 즉시 적용 가능한 최적화

#### A. 불필요한 폰트 제거
```bash
# pubspec.yaml에서 사용하지 않는 weight 제거
# 현재: 9개 → 추천: 4개 (Regular, Medium, SemiBold, Bold)
```

#### B. 이미지 추가 압축
```bash
# 품질 70% → 60%로 낮추기
find assets/images/summary -name "*.jpg" -exec mogrify -quality 60 {} \;

# 예상 절감: 약 15-20MB
```

#### C. WebP 포맷 사용
```bash
# JPEG → WebP 변환 (25-35% 추가 압축)
find assets/images/summary -name "*.jpg" -exec sh -c '
  cwebp -q 70 "$1" -o "${1%.jpg}.webp"
' _ {} \;

# 예상 절감: 약 20-25MB
```

---

## 🚀 권장 최적화 조합

### Option 1: 빠른 최적화 (즉시 적용)
```
1. 폰트 4개만 사용:        -11MB
2. 이미지 품질 60%:        -15MB
-----------------------------------
최종 크기:                 ~80MB (25% 감소)
```

### Option 2: 중간 최적화
```
1. 폰트 4개만 사용:        -11MB
2. WebP 변환:             -20MB
3. DB 하나만 사용:         -5MB
-----------------------------------
최종 크기:                 ~70MB (34% 감소)
```

### Option 3: 최대 최적화 (개발 필요)
```
1. 폰트 4개만 사용:        -11MB
2. 이미지 On-Demand:      -79MB (초기)
3. DB 하나만 사용:         -5MB
-----------------------------------
최종 크기:                 ~11MB (90% 감소!)
초기 다운로드:             ~26MB (75% 감소)
```

---

## 📝 즉시 적용: 폰트 최적화

가장 쉽고 효과적인 방법입니다.

### 1. pubspec.yaml 수정
```yaml
fonts:
  - family: Pretendard
    fonts:
      - asset: assets/fonts/Pretendard-Regular.otf
        weight: 400
      - asset: assets/fonts/Pretendard-Medium.otf
        weight: 500
      - asset: assets/fonts/Pretendard-SemiBold.otf
        weight: 600
      - asset: assets/fonts/Pretendard-Bold.otf
        weight: 700
```

### 2. 사용하지 않는 폰트 파일 삭제
```bash
rm assets/fonts/Pretendard-Thin.otf
rm assets/fonts/Pretendard-ExtraLight.otf
rm assets/fonts/Pretendard-Light.otf
rm assets/fonts/Pretendard-ExtraBold.otf
rm assets/fonts/Pretendard-Black.otf
```

### 3. 재빌드
```bash
flutter build appbundle --release
```

**예상 결과: 105.9MB → 94.9MB**

---

## 🎨 WebP 변환 가이드

### 설치 (Mac)
```bash
brew install webp
```

### 변환
```bash
cd assets/images/summary

# 모든 JPEG를 WebP로 변환
find . -name "*.jpg" -exec sh -c '
  cwebp -q 70 "$1" -o "${1%.jpg}.webp" && rm "$1"
' _ {} \;
```

### pubspec.yaml 수정
```yaml
# 자동으로 .webp 파일도 인식됨
assets:
  - assets/images/summary/
```

### 코드 수정 (필요시)
```dart
// .jpg → .webp 확장자만 변경
Image.asset('assets/images/summary/1권1강/1권1강_성경읽기_1.webp')
```

---

## 📊 최종 추천

### 지금 당장 적용 (10분)
1. **폰트 4개만 사용** → 11MB 절감

### 시간 있으면 추가 (30분)
2. **WebP 변환** → 추가 20MB 절감
3. **총 절감: 31MB → 최종 약 75MB**

### 장기적으로 고려
- 이미지 On-Demand 로딩 구현
- 최종 초기 크기: 26MB

---

## ⚡ 빠른 실행

폰트만 최적화하려면:

```bash
# 1. 불필요한 폰트 삭제
rm assets/fonts/Pretendard-{Thin,ExtraLight,Light,ExtraBold,Black}.otf

# 2. pubspec.yaml 수정 (weight 4개만)
# 3. 재빌드
flutter build appbundle --release
```

예상 시간: **5분**
예상 절감: **11MB**

---

**현재 105.9MB는 이미 상당히 최적화된 상태입니다!**
(이미지 압축으로 267MB → 105.9MB 달성)

추가 최적화는 선택사항이며, 
Play Store 200MB 제한은 통과했으므로
**현재 상태로도 문제없습니다!** ✅


