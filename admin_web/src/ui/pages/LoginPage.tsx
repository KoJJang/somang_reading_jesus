import React, { useState } from 'react';
import { signInWithEmailAndPassword } from 'firebase/auth';
import { firebaseAuth } from '../../firebase/firebase';
import { useNavigate } from 'react-router-dom';

export function LoginPage(): JSX.Element {
  const navigate = useNavigate();
  const [email, setEmail] = useState<string>('');
  const [password, setPassword] = useState<string>('');
  const [error, setError] = useState<string>('');

  async function signIn(): Promise<void> {
    setError('');
    try {
      await signInWithEmailAndPassword(firebaseAuth, email, password);
      navigate('/members');
    } catch (e) {
      setError(e instanceof Error ? e.message : '로그인 실패');
    }
  }

  return (
    <div style={{ padding: 24, maxWidth: 420 }}>
      <h2>리딩지저스 관리자 로그인</h2>
      <div style={{ display: 'grid', gap: 12 }}>
        <label>
          Email
          <input
            value={email}
            onChange={(event) => setEmail(event.target.value)}
            style={{ width: '100%', padding: 8 }}
          />
        </label>
        <label>
          Password
          <input
            type="password"
            value={password}
            onChange={(event) => setPassword(event.target.value)}
            style={{ width: '100%', padding: 8 }}
          />
        </label>
        <button onClick={() => void signIn()} style={{ padding: 10 }}>
          로그인
        </button>
        {error ? <div style={{ color: 'crimson' }}>{error}</div> : null}
        <div style={{ color: '#6b7280', fontSize: 12 }}>
          관리자 권한은 Firestore `roles/{'{uid}'}` 문서의 `admin: true`로 판단합니다.
        </div>
      </div>
    </div>
  );
}


