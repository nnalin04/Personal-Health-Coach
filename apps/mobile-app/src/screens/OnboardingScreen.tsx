/**
 * Page 1 — Onboarding / Auth
 *
 * Conversational onboarding that captures Taste_Profile and Health_Baseline
 * through an empathetic chat-based dialogue.
 *
 * Flow:
 *   → Google Sign-In
 *   → Chat collects: name, region, cuisine style, dietary restrictions, health goals
 *   → Saves Taste_Profile to WatermelonDB + syncs to orchestrator
 *   → Navigates to Dashboard
 */
import React, { useState } from 'react';
import {
  View,
  Text,
  TextInput,
  TouchableOpacity,
  FlatList,
  StyleSheet,
  SafeAreaView,
  KeyboardAvoidingView,
  Platform,
} from 'react-native';
import { StackNavigationProp } from '@react-navigation/stack';
import { RootStackParamList } from '../navigation/AppNavigator';

type Props = { navigation: StackNavigationProp<RootStackParamList, 'Onboarding'> };

interface ChatMessage {
  id: string;
  role: 'assistant' | 'user';
  text: string;
}

const ONBOARDING_STEPS = [
  { key: 'name',          prompt: "Hello! I'm your personal Health OS. What should I call you?" },
  { key: 'region',        prompt: "Great, {name}! Which region of India are you from? (e.g. Maharashtra, Punjab, South India)" },
  { key: 'cuisine',       prompt: "What's your primary cuisine style? (e.g. vegetarian, non-veg, vegan, jain)" },
  { key: 'restrictions',  prompt: "Any dietary restrictions I should know about? (e.g. no onion-garlic, gluten-free, or just say 'none')" },
  { key: 'goal',          prompt: "Last one — what's your main health goal right now? (e.g. lose weight, build muscle, manage diabetes, stay fit)" },
];

export default function OnboardingScreen({ navigation }: Props) {
  const [messages, setMessages] = useState<ChatMessage[]>([
    { id: '0', role: 'assistant', text: ONBOARDING_STEPS[0].prompt },
  ]);
  const [input, setInput] = useState('');
  const [stepIndex, setStepIndex] = useState(0);
  const [profile, setProfile] = useState<Record<string, string>>({});

  const sendMessage = () => {
    const trimmed = input.trim();
    if (!trimmed) return;

    const currentStep = ONBOARDING_STEPS[stepIndex];
    const updatedProfile = { ...profile, [currentStep.key]: trimmed };
    setProfile(updatedProfile);

    const userMsg: ChatMessage = { id: Date.now().toString(), role: 'user', text: trimmed };
    const nextStep = stepIndex + 1;
    const nextMessages: ChatMessage[] = [...messages, userMsg];

    if (nextStep < ONBOARDING_STEPS.length) {
      const nextPrompt = ONBOARDING_STEPS[nextStep].prompt.replace('{name}', updatedProfile.name || trimmed);
      nextMessages.push({ id: (Date.now() + 1).toString(), role: 'assistant', text: nextPrompt });
      setStepIndex(nextStep);
    } else {
      nextMessages.push({
        id: (Date.now() + 1).toString(),
        role: 'assistant',
        text: `Perfect, ${updatedProfile.name || trimmed}! Your Health OS is ready. Let me take you to your dashboard.`,
      });
      // TODO: save Taste_Profile to WatermelonDB and sync to orchestrator
      setTimeout(() => navigation.replace('Dashboard'), 1800);
    }

    setMessages(nextMessages);
    setInput('');
  };

  return (
    <SafeAreaView style={styles.safe}>
      <KeyboardAvoidingView style={styles.flex} behavior={Platform.OS === 'ios' ? 'padding' : undefined}>
        <View style={styles.header}>
          <Text style={styles.logo}>Health OS</Text>
          <Text style={styles.tagline}>Invisible tracking. Intelligent insights.</Text>
        </View>

        <FlatList
          data={messages}
          keyExtractor={(m) => m.id}
          contentContainerStyle={styles.chatList}
          renderItem={({ item }) => (
            <View style={[styles.bubble, item.role === 'user' ? styles.userBubble : styles.aiBubble]}>
              <Text style={[styles.bubbleText, item.role === 'user' ? styles.userText : styles.aiText]}>
                {item.text}
              </Text>
            </View>
          )}
        />

        <View style={styles.inputRow}>
          <TextInput
            style={styles.input}
            value={input}
            onChangeText={setInput}
            placeholder="Type your answer..."
            placeholderTextColor="#888"
            onSubmitEditing={sendMessage}
            returnKeyType="send"
          />
          <TouchableOpacity style={styles.sendBtn} onPress={sendMessage}>
            <Text style={styles.sendText}>→</Text>
          </TouchableOpacity>
        </View>
      </KeyboardAvoidingView>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  safe:        { flex: 1, backgroundColor: '#0A0A0A' },
  flex:        { flex: 1 },
  header:      { paddingTop: 32, paddingHorizontal: 24, paddingBottom: 16 },
  logo:        { fontSize: 28, fontWeight: '700', color: '#FFFFFF', letterSpacing: 1 },
  tagline:     { fontSize: 13, color: '#666', marginTop: 4 },
  chatList:    { paddingHorizontal: 16, paddingBottom: 16 },
  bubble:      { maxWidth: '80%', borderRadius: 16, padding: 12, marginBottom: 10 },
  aiBubble:    { backgroundColor: '#1C1C1E', alignSelf: 'flex-start' },
  userBubble:  { backgroundColor: '#2563EB', alignSelf: 'flex-end' },
  bubbleText:  { fontSize: 15, lineHeight: 22 },
  aiText:      { color: '#E5E7EB' },
  userText:    { color: '#FFFFFF' },
  inputRow:    { flexDirection: 'row', padding: 12, borderTopWidth: 1, borderTopColor: '#1C1C1E', backgroundColor: '#0A0A0A' },
  input:       { flex: 1, backgroundColor: '#1C1C1E', color: '#FFFFFF', borderRadius: 24, paddingHorizontal: 18, paddingVertical: 12, fontSize: 15 },
  sendBtn:     { width: 48, height: 48, borderRadius: 24, backgroundColor: '#2563EB', alignItems: 'center', justifyContent: 'center', marginLeft: 8 },
  sendText:    { color: '#FFFFFF', fontSize: 20, fontWeight: '700' },
});
