import React, { useContext } from 'react';
import { Navigate, Route, Routes } from 'react-router-dom';
import { AuthContext } from './auth/AuthContext';
import { LoginPage } from './pages/LoginPage';
import { MembersPage } from './pages/MembersPage';
import { MemberDetailPage } from './pages/MemberDetailPage';
import { SchedulePage } from './pages/SchedulePage';

function Guard(props: { children: React.ReactNode }): JSX.Element {
  const auth = useContext(AuthContext);
  if (auth.status === 'loading') return <div style={{ padding: 24 }}>Loading…</div>;
  if (auth.status === 'signed_out') return <Navigate to="/login" replace />;
  if (!auth.isAdmin) return <div style={{ padding: 24 }}>권한이 없습니다 (admin)</div>;
  return <>{props.children}</>;
}

export function App(): JSX.Element {
  return (
    <Routes>
      <Route path="/login" element={<LoginPage />} />
      <Route
        path="/"
        element={
          <Guard>
            <Navigate to="/members" replace />
          </Guard>
        }
      />
      <Route
        path="/members"
        element={
          <Guard>
            <MembersPage />
          </Guard>
        }
      />
      <Route
        path="/members/:uid"
        element={
          <Guard>
            <MemberDetailPage />
          </Guard>
        }
      />
      <Route
        path="/schedule"
        element={
          <Guard>
            <SchedulePage />
          </Guard>
        }
      />
      <Route path="*" element={<Navigate to="/" replace />} />
    </Routes>
  );
}


