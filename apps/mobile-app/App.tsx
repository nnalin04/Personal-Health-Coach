import 'react-native-gesture-handler';
import { StatusBar } from 'expo-status-bar';
import { GestureHandlerRootView } from 'react-native-gesture-handler';
import { enableScreens } from 'react-native-screens';
import * as Sentry from '@sentry/react-native';

import AppNavigator from './src/navigation/AppNavigator';
import { ErrorBoundary } from './src/components/ErrorBoundary';
import { OfflineBanner } from './src/components/OfflineBanner';

enableScreens();

// Initialize Sentry for Crash Reporting
Sentry.init({
  // Typically an environment variable in production (e.g., process.env.EXPO_PUBLIC_SENTRY_DSN)
  dsn: process.env.EXPO_PUBLIC_SENTRY_DSN || "https://examplePublicKey@o0.ingest.sentry.io/0", 
  tracesSampleRate: 1.0, // Adjust for production
  _experiments: {
    profilesSampleRate: 1.0, 
  },
});

function App() {
  return (
    <ErrorBoundary>
      <GestureHandlerRootView style={{ flex: 1 }}>
        <StatusBar style="light" />
        <OfflineBanner />
        <AppNavigator />
      </GestureHandlerRootView>
    </ErrorBoundary>
  );
}

export default Sentry.wrap(App);
