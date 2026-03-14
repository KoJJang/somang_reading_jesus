# 스크립트

## excel_to_teams_json.py

리딩지저스 팀 신청서 Excel을 JSON으로 변환합니다.

### 사용법

```bash
# openpyxl 설치 (최초 1회)
pip install openpyxl

# Excel → JSON 변환 (기본 출력: assets/data/teams_2026.json)
python scripts/excel_to_teams_json.py "~/Downloads/리딩지저스 팀 신청서.xlsx"

# 출력 경로 지정
python scripts/excel_to_teams_json.py ./팀신청서.xlsx assets/data/teams_2026.json
```

### Excel 형식

- 1행: 헤더 (팀장 이름, 팀원1, 팀원2, ... 팀원10)
- 2행~: 팀장 이름, 팀원 이름들

### 앱에서 사용

변환된 JSON은 프로필 화면의 **디버그 빌드**에서 "실제 팀 데이터 임포트 (2026)" 버튼으로 Firestore에 반영됩니다.
