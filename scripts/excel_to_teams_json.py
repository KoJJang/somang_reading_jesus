#!/usr/bin/env python3
"""
리딩지저스 팀 신청서 Excel → JSON 변환 스크립트

사용법:
  python scripts/excel_to_teams_json.py <엑셀파일경로> [출력경로]

예시:
  python scripts/excel_to_teams_json.py ~/Downloads/리딩지저스\ 팀\ 신청서.xlsx
  python scripts/excel_to_teams_json.py ./팀신청서.xlsx assets/data/teams_2026.json

출력 형식:
  [{"leaderName": "강정순", "memberNames": ["고영남", "김경은", ...]}, ...]
"""

import json
import sys
from pathlib import Path

try:
    import openpyxl
except ImportError:
    print("openpyxl이 필요합니다: pip install openpyxl")
    sys.exit(1)


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)

    excel_path = Path(sys.argv[1]).expanduser()
    if not excel_path.exists():
        print(f"파일을 찾을 수 없습니다: {excel_path}")
        sys.exit(1)

    output_path = (
        Path(sys.argv[2]).expanduser()
        if len(sys.argv) > 2
        else Path(__file__).parent.parent / "assets" / "data" / "teams_2026.json"
    )

    wb = openpyxl.load_workbook(excel_path, read_only=True, data_only=True)
    ws = wb.active
    teams = []

    for row in ws.iter_rows(min_row=2, max_col=11, values_only=True):
        leader = row[0]
        if not leader or not str(leader).strip():
            continue
        members = [
            str(m).strip()
            for m in row[1:11]
            if m and str(m).strip()
        ]
        teams.append({
            "leaderName": str(leader).strip(),
            "memberNames": members,
        })

    wb.close()

    output_path.parent.mkdir(parents=True, exist_ok=True)
    with open(output_path, "w", encoding="utf-8") as f:
        json.dump(teams, f, ensure_ascii=False, indent=2)

    print(f"✅ {len(teams)}개 팀을 {output_path}에 저장했습니다.")
    if teams:
        print(f"   샘플: {teams[0]}")


if __name__ == "__main__":
    main()
