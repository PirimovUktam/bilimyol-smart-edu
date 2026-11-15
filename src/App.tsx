import { AuthProvider } from './core/context/AuthContext';
import { AppRouter } from './app/router/AppRouter';
import { PreferencesBar } from './presentation/components/PreferencesBar';

export function App() {
  return (
    <AuthProvider>
      <PreferencesBar />
      <AppRouter />
    </AuthProvider>
  );
}

export default App;
