import React, { useEffect, useState } from 'react';
import { View, Text, StyleSheet, Animated } from 'react-native';
import NetInfo from '@react-native-community/netinfo';
import MaterialIcons from 'react-native-vector-icons/MaterialIcons';

export function OfflineBanner() {
  const [isConnected, setIsConnected] = useState<boolean>(true);
  const slideAnim = useState(new Animated.Value(-100))[0];

  useEffect(() => {
    const unsubscribe = NetInfo.addEventListener((state) => {
      const connected = state.isConnected ?? true;
      setIsConnected(connected);

      Animated.timing(slideAnim, {
        toValue: connected ? -100 : 0,
        duration: 300,
        useNativeDriver: true,
      }).start();
    });

    return () => unsubscribe();
  }, [slideAnim]);

  return (
    <Animated.View style={[styles.container, { transform: [{ translateY: slideAnim }] }]}>
      <MaterialIcons name="wifi-off" size={20} color="#FFFFFF" style={styles.icon} />
      <Text style={styles.text}>No internet connection</Text>
    </Animated.View>
  );
}

const styles = StyleSheet.create({
  container: {
    position: 'absolute',
    top: 0,
    left: 0,
    right: 0,
    backgroundColor: '#EF4444', 
    paddingTop: 50, // safe area padding for standard notches
    paddingBottom: 10,
    paddingHorizontal: 20,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    zIndex: 9999,
    elevation: 9999,
  },
  icon: {
    marginRight: 8,
  },
  text: {
    color: '#FFFFFF',
    fontWeight: '600',
    fontSize: 14,
  },
});
