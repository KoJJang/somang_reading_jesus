import React from 'react';
import { Link } from 'react-router-dom';

export function SchedulePage(): JSX.Element {
  return (
    <div style={{ padding: 24 }}>
      <div style={{ display: 'flex', gap: 12, alignItems: 'center' }}>
        <Link to="/members">← 멤버</Link>
        <h2 style={{ margin: 0 }}>연도별 일정 설정</h2>
      </div>
      <p style={{ color: '#6b7280' }}>
        (MVP) 다음 단계에서 Firestore `schedule_configs/{'{year}'}` 문서에 대해
        startDate(월요일) + breakWeeks(주 시작일) CRUD를 구현합니다.
      </p>
    </div>
  );
}


