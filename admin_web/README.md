## Admin Web (Vite + React + Firebase)

NAS에 올리기 쉬운 **정적 배포**를 목표로 `Vite(React)`로 시작합니다.

### 로컬 실행

```bash
cd admin_web
npm install
npm run dev
```

### 빌드 (정적 파일 생성)

```bash
cd admin_web
npm run build
```

빌드 산출물은 `admin_web/dist/`에 생성됩니다. 이 디렉터리를 NAS의 웹서버에 그대로 배포하면 됩니다.

### Firebase 설정

Firebase 콘솔에서 **Web App**을 추가한 뒤, 아래 환경변수를 세팅하세요.

- `VITE_FIREBASE_API_KEY`
- `VITE_FIREBASE_AUTH_DOMAIN`
- `VITE_FIREBASE_PROJECT_ID`
- `VITE_FIREBASE_STORAGE_BUCKET`
- `VITE_FIREBASE_MESSAGING_SENDER_ID`
- `VITE_FIREBASE_APP_ID`

예시:

```bash
export VITE_FIREBASE_API_KEY="..."
export VITE_FIREBASE_AUTH_DOMAIN="..."
export VITE_FIREBASE_PROJECT_ID="reading-jesus-somang"
export VITE_FIREBASE_STORAGE_BUCKET="..."
export VITE_FIREBASE_MESSAGING_SENDER_ID="..."
export VITE_FIREBASE_APP_ID="..."
```

### 권한(관리자) 방식 (초기)

초기 버전은 Firestore의 `roles/{uid}` 문서에 다음 필드가 있으면 관리자로 인정합니다.

- `admin: true`

> 추후 Custom Claims로 강화 가능


