import { createContext } from 'react';
import type { User } from 'firebase/auth';

export type AuthState =
  | { status: 'loading' }
  | { status: 'signed_out' }
  | { status: 'signed_in'; user: User; isAdmin: boolean };

export const AuthContext = createContext<AuthState>({ status: 'loading' });


