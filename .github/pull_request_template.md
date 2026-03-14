## 변경 요약
<!-- 무엇을, 왜 변경했는지 간략히 -->

## 변경 유형
- [ ] 새 기능 (feat)
- [ ] 버그 수정 (fix)
- [ ] 리팩토링 (refactor)
- [ ] UI/디자인 (style)
- [ ] 배포/인프라 (chore)

---

## PR 머지 전 체크리스트

> 🔴 **REQUIRED** — 미통과 시 머지 불가  
> 🟡 **WARN** — 후속 이슈 등록 후 머지 가능  
> 🔵 **COND** — 해당되는 경우에만 확인

---

### 1. 코드 안전성 🔴

- [ ] Null safety — 강제 언래핑(`!`) 없음, 방어적 null 처리
- [ ] 모든 `async` 함수에 `try/catch` 적용, `mounted` 체크 후 `setState`
- [ ] 사용자 입력값 검증 (빈 문자열, 길이 초과, 타입 불일치)
- [ ] 하드코딩된 시크릿·개인정보(전화번호, 이메일, API 키) 없음
- [ ] `kDebugMode` 가드 — 디버그 전용 UI/기능 릴리즈 빌드에서 제외됨

### 2. 컴파일 & 의존성 🔴

- [ ] 새 파일 import 경로 정확, 순환 참조 없음
- [ ] 새 패키지 `pubspec.yaml` + `pubspec.lock` 커밋됨
- [ ] 새 에셋 `pubspec.yaml` assets 섹션에 선언됨
- [ ] 새 패키지에 알려진 보안 취약점 없음 (`flutter pub audit`)

### 3. Firestore & 보안 🔴

- [ ] 새 컬렉션/쓰기 경로가 `firestore.rules`에 반영됨
- [ ] 서버측 rules와 클라이언트 guard가 이중으로 인증 검증
- [ ] 쿼리에 `.limit()` 적용 — 무제한 컬렉션 스캔 없음
- [ ] `orderBy + where` 조합 시 복합 인덱스 확인 (`firestore.indexes.json`)
- [ ] 배치 쓰기 500건 제한 초과 없음 (초과 시 청크 처리)

### 4. 배포 준비 🔴

- [ ] 기존 라우트 및 화면 회귀 없음
- [ ] Breaking change 없음 (있으면 마이그레이션 계획 포함)
- [ ] `firestore.rules` 변경 시 → `firebase deploy --only firestore:rules` 배포 계획 수립
- [ ] Firestore 인덱스 변경 시 → `firebase deploy --only firestore:indexes` 배포 계획 수립

---

### 5. 성능 & 안정성 🟡

- [ ] N+1 쿼리 패턴 없음 (루프 안 Firestore 호출 → `Future.wait` 병렬 처리)
- [ ] 대용량 리스트에 페이지네이션 또는 쿼리 제한 적용
- [ ] 무거운 작업(이미지 처리, 대용량 JSON) UI 스레드 블로킹 없음
- [ ] `dispose()` 에서 stream subscription, timer, controller 해제

### 6. 운영 & 모니터링 🟡

- [ ] 주요 에러 경로에 `LoggerUtil.error()` 로깅 적용
- [ ] 사용자에게 에러 노출 시 `SnackBar` 또는 빈 상태 UI 처리
- [ ] 새 기능에 대한 로딩/빈 상태/에러 상태 UI 모두 구현
- [ ] 운영 중 롤백이 필요할 경우 방법 확인 (Firestore 데이터 비파괴 여부)

### 7. 테스트 🟡

- [ ] 비즈니스 로직 변경 시 단위 테스트 추가 또는 업데이트
- [ ] 신규 화면/위젯에 기본 위젯 테스트 존재
- [ ] 주요 유저 플로우 수동 확인 완료 (디버그 빌드)

---

### 8. UI 변경 시 🔵 COND

- [ ] 다크모드 대응 (있을 경우)
- [ ] 텍스트 오버플로우 처리 (`overflow: TextOverflow.ellipsis`)
- [ ] 긴 이름/긴 문자열 엣지케이스 확인
- [ ] 앱 색상 체계(`AppColors`) 준수 — 하드코딩 색상 최소화

### 9. Firestore 스키마 변경 시 🔵 COND

- [ ] 기존 문서와 하위 호환 (새 필드는 optional, 기존 필드 삭제 금지)
- [ ] `fromMap` 파싱에 기존 문서의 누락 필드 방어 처리
- [ ] 필요 시 마이그레이션 스크립트 준비 및 테스트 완료

### 10. 앱 릴리즈 시 🔵 COND

- [ ] `pubspec.yaml` 버전 번호 (`version: x.y.z+build`) 업데이트
- [ ] iOS/Android 스토어 심사 정책 위반 요소 없음
- [ ] 권한 변경(카메라, 알림 등) 시 `Info.plist` / `AndroidManifest.xml` 업데이트

---

## 배포 후 모니터링 체크

> 머지 및 배포 직후 확인

- [ ] Firestore 콘솔 — 새 컬렉션/문서 정상 생성 확인
- [ ] 앱 크래시 없음 (Firebase Crashlytics 또는 로그 확인)
- [ ] 주요 유저 플로우 프로덕션에서 1회 직접 확인
- [ ] `firestore.rules` 배포됐다면 Firebase 콘솔 Rules Playground로 권한 검증

---

## 머지 판정

| 결과 | 기준 | 조치 |
|---|---|---|
| ✅ MERGE SAFE | 🔴 전체 PASS | 머지 진행 |
| ⚠️ MERGE WITH CAUTION | 🔴 PASS + 🟡 일부 WARN | 후속 이슈 등록 후 머지 |
| 🚫 DO NOT MERGE | 🔴 FAIL 항목 존재 | 해결 후 재검토 |
