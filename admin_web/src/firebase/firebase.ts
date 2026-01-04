import { initializeApp } from 'firebase/app';
import { getAuth } from 'firebase/auth';
import { getFirestore } from 'firebase/firestore';

function getEnvString(key: string): string {
  const value = import.meta.env[key] as string | undefined;
  if (!value) {
    throw new Error(`Missing env: ${key}`);
  }
  return value;
}

const firebaseConfig = {
  apiKey: getEnvString('VITE_FIREBASE_API_KEY'),
  authDomain: getEnvString('VITE_FIREBASE_AUTH_DOMAIN'),
  projectId: getEnvString('VITE_FIREBASE_PROJECT_ID'),
  storageBucket: getEnvString('VITE_FIREBASE_STORAGE_BUCKET'),
  messagingSenderId: getEnvString('VITE_FIREBASE_MESSAGING_SENDER_ID'),
  appId: getEnvString('VITE_FIREBASE_APP_ID'),
};

export const firebaseApp = initializeApp(firebaseConfig);
export const firebaseAuth = getAuth(firebaseApp);
export const firestore = getFirestore(firebaseApp);


