## 변경 요약
<!-- 무엇을, 왜 변경했는지 간략히 -->

## 테스트 계획
- [ ] 로컬 디버그 빌드에서 동작 확인
- [ ] 영향 받는 기존 화면 회귀 테스트

---

## PR 머지 전 체크리스트

### 코드 안전성
- [ ] Null safety — 강제 언래핑(`!`) 없이 방어적 처리
- [ ] 모든 async 함수에 try/catch, `mounted` 체크 적용
- [ ] Firestore 쓰기 경로에 인증 검증 있음 (서버측 rules + 클라이언트 guard)
- [ ] 하드코딩된 시크릿·개인정보(전화번호, 이메일 등) 없음
- [ ] `kDebugMode` 가드: 디버그 전용 UI·기능 릴리즈 빌드에서 제외

### 컴파일 & 의존성
- [ ] 새 파일의 import 경로 정확
- [ ] 새 패키지는 `pubspec.yaml`에 추가, `pubspec.lock` 커밋됨
- [ ] 새 에셋은 `pubspec.yaml` assets 섹션에 선언

### Firestore
- [ ] 새 컬렉션/쓰기 경로가 `firestore.rules`에 반영됨
- [ ] `firebase deploy --only firestore:rules` 배포 예정 (또는 완료)
- [ ] 읽기 쿼리에 필요한 복합 인덱스 확인 (orderBy + where 조합)

### 배포 준비
- [ ] 기존 라우트 깨지지 않음
- [ ] Breaking change 있으면 마이그레이션 계획 포함
- [ ] TODO/FIXME 중 이번 PR에서 반드시 해결해야 할 항목 없음

### 머지 판정
- [ ] 위 항목 모두 PASS → **MERGE SAFE**
- WARN 항목 있으면 후속 이슈 등록 후 머지
- FAIL 항목 있으면 해결 후 재검토
