import { AuthProvider } from './core/context/AuthContext';
import { AppRouter } from './app/router/AppRouter';

export function App() {
  return (
    <AuthProvider>
      <AppRouter />
    </AuthProvider>
  );
}

export default App;
