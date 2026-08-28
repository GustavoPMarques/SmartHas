import { Platform } from 'react-native';
import AsyncStorage from '@react-native-async-storage/async-storage';
import { initializeApp, getApps, getApp } from 'firebase/app';
import { initializeAuth, getAuth, getReactNativePersistence } from 'firebase/auth';

const firebaseConfig = {
  apiKey: "AIzaSyAfF3-Xodpmq8SUqfCrcEtiFy2I3EHmZR4",
  authDomain: "backend-smarthas.firebaseapp.com",
  projectId: "backend-smarthas",
  storageBucket: "backend-smarthas.firebasestorage.app",
  messagingSenderId: "652134149411",
  appId: "1:652134149411:web:1aafda6442e0181277b096",
  measurementId: "G-KS9B6VK073"
};

const app = getApps().length ? getApp() : initializeApp(firebaseConfig);

// Na web usamos a persistência padrão do navegador.
// No app nativo, precisamos indicar explicitamente o AsyncStorage,
// senão o login não sobrevive a um fechar/abrir do app.
const auth = Platform.OS === 'web'
  ? getAuth(app)
  : initializeAuth(app, { persistence: getReactNativePersistence(AsyncStorage) });

export { auth };
