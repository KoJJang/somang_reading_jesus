import React from 'react';
import { Link } from 'react-router-dom';

export function MembersPage(): JSX.Element {
  return (
    <div style={{ padding: 24 }}>
      <div style={{ display: 'flex', gap: 12, alignItems: 'center' }}>
        <h2 style={{ margin: 0 }}>멤버</h2>
        <Link to="/schedule">일정 설정</Link>
      </div>
      <p style={{ color: '#6b7280' }}>
        (MVP) 다음 단계에서 Firestore `users` 및 `member_year_profiles/{'{year}'}/users`를
        조회해 목록/필터/수정을 구현합니다.
      </p>
    </div>
  );
}


