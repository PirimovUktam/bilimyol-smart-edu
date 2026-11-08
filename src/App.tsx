import { MotionConfig } from 'framer-motion';
import { AuthProvider } from './core/context/AuthContext';
import { AppRouter } from './app/router/AppRouter';

export function App() {
  return (
    <MotionConfig reducedMotion="user">
    <AuthProvider>
      <AppRouter />
    </AuthProvider>
    </MotionConfig>
  );
}

export default App;
