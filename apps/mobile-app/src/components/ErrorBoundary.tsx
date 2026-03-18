import React, { Component, ErrorInfo, ReactNode } from 'react';
import { View, Text, StyleSheet, TouchableOpacity } from 'react-native';

interface Props {
  children: ReactNode;
}

interface State {
  hasError: boolean;
  errorMessage: string;
}

/**
 * Top-level error boundary.
 *
 * Catches unhandled render / lifecycle errors anywhere in the tree so the
 * app never shows a blank screen. Displays a recoverable "Something went
 * wrong" UI with a Retry button that resets the boundary.
 *
 * Usage:
 *   <ErrorBoundary>
 *     <AppNavigator />
 *   </ErrorBoundary>
 */
export class ErrorBoundary extends Component<Props, State> {
  state: State = { hasError: false, errorMessage: '' };

  static getDerivedStateFromError(error: Error): State {
    return { hasError: true, errorMessage: error.message };
  }

  componentDidCatch(error: Error, info: ErrorInfo): void {
    // In production, send to crash reporter (Sentry, Firebase Crashlytics, etc.)
    console.error('[ErrorBoundary] Uncaught error:', error, info.componentStack);
  }

  private handleRetry = (): void => {
    this.setState({ hasError: false, errorMessage: '' });
  };

  render(): ReactNode {
    if (this.state.hasError) {
      return (
        <View style={styles.container}>
          <Text style={styles.title}>Something went wrong</Text>
          <Text style={styles.subtitle}>
            The app encountered an unexpected error. Your data is safe.
          </Text>
          {__DEV__ && (
            <Text style={styles.detail}>{this.state.errorMessage}</Text>
          )}
          <TouchableOpacity style={styles.button} onPress={this.handleRetry}>
            <Text style={styles.buttonText}>Retry</Text>
          </TouchableOpacity>
        </View>
      );
    }
    return this.props.children;
  }
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    backgroundColor: '#0F172A',
    padding: 32,
  },
  title: {
    fontSize: 22,
    fontWeight: '700',
    color: '#F8FAFC',
    marginBottom: 12,
    textAlign: 'center',
  },
  subtitle: {
    fontSize: 15,
    color: '#94A3B8',
    textAlign: 'center',
    marginBottom: 12,
  },
  detail: {
    fontSize: 12,
    color: '#EF4444',
    textAlign: 'center',
    marginBottom: 20,
    fontFamily: 'monospace',
  },
  button: {
    marginTop: 8,
    backgroundColor: '#6366F1',
    paddingHorizontal: 32,
    paddingVertical: 14,
    borderRadius: 12,
  },
  buttonText: {
    color: '#FFFFFF',
    fontWeight: '600',
    fontSize: 16,
  },
});
