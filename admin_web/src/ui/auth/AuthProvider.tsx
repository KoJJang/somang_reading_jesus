import { onAuthStateChanged } from 'firebase/auth';
import { doc, getDoc } from 'firebase/firestore';
import React, { useEffect, useMemo, useState } from 'react';
import { firebaseAuth, firestore } from '../../firebase/firebase';
import { AuthContext, type AuthState } from './AuthContext';

async function checkAdmin(uid: string): Promise<boolean> {
  const ref = doc(firestore, 'roles', uid);
  const snapshot = await getDoc(ref);
  return snapshot.exists() && snapshot.data().admin === true;
}

export function AuthProvider(props: { children: React.ReactNode }): JSX.Element {
  const [state, setState] = useState<AuthState>({ status: 'loading' });

  useEffect(() => {
    const unsubscribe = onAuthStateChanged(firebaseAuth, async (user) => {
      if (!user) {
        setState({ status: 'signed_out' });
        return;
      }
      try {
        const isAdmin = await checkAdmin(user.uid);
        setState({ status: 'signed_in', user, isAdmin });
      } catch {
        setState({ status: 'signed_in', user, isAdmin: false });
      }
    });
    return () => unsubscribe();
  }, []);

  const value = useMemo(() => state, [state]);

  return <AuthContext.Provider value={value}>{props.children}</AuthContext.Provider>;
}


