import React from 'react';
import { Link, useParams } from 'react-router-dom';

export function MemberDetailPage(): JSX.Element {
  const params = useParams();
  return (
    <div style={{ padding: 24 }}>
      <div style={{ display: 'flex', gap: 12, alignItems: 'center' }}>
        <Link to="/members">← 멤버</Link>
        <h2 style={{ margin: 0 }}>멤버 상세</h2>
      </div>
      <p style={{ color: '#6b7280' }}>uid: {params.uid}</p>
      <p style={{ color: '#6b7280' }}>
        (MVP) 다음 단계에서 연도 선택 + 주차/일차 완료 매트릭스 + 팀/팀장/권한/메모 수정 UI를 추가합니다.
      </p>
    </div>
  );
}


