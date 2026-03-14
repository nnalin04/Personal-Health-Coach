/**
 * Page 3 — Omni-Chat Interface
 *
 * The primary input engine for the Health OS.
 * Universal '+' button supports:
 *   - Text messages  (natural language food/symptom logging + profile updates)
 *   - Food images    (routed → Gemini Vision pipeline)
 *   - Medical PDFs   (routed → Document AI OCR pipeline)
 *
 * Task result delivery (in priority order):
 *   1. WebSocket (STOMP) — instant notification from AI Engine via Spring Boot
 *   2. Polling fallback  — GET /api/v1/chat/tasks/{taskId} every 3 s (max 60 s)
 *
 * For PROFILE_UPDATE (synchronous) — shows the AI confirmation inline.
 */
import React, { useState, useRef, useCallback } from 'react';
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
  Alert,
  ActionSheetIOS,
} from 'react-native';
import * as ImagePicker    from 'expo-image-picker';
import * as DocumentPicker from 'expo-document-picker';
import { StackNavigationProp } from '@react-navigation/stack';
import { AppStackParamList } from '../navigation/AppNavigator';
import apiClient from '../services/apiClient';
import { useAuthStore } from '../store/authStore';
import { useTaskWebSocket, TaskCompletionMessage } from '../hooks/useTaskWebSocket';

type Props = { navigation: StackNavigationProp<AppStackParamList, 'OmniChat'> };

type MessageType = 'text' | 'food-image' | 'medical-pdf' | 'ai-response' | 'processing';

interface ChatMessage {
  id:      string;
  role:    'user' | 'assistant';
  type:    MessageType;
  text:    string;
  taskId?: string;
}

// ── Helpers ───────────────────────────────────────────────────────────────────

function formatTaskResult(result: TaskCompletionMessage['result']): string {
  if (!result) return '✅ Done! Check your Dashboard for updates.';
  if (result.type === 'FOOD' && result.mealLog) {
    const m = result.mealLog as Record<string, unknown>;
    return `✅ Logged! ${m.dishName} — ${m.calories} kcal, ${m.proteinG}g protein, ${m.carbsG}g carbs, ${m.fatsG}g fat.\n${m.confidence ?? ''}`;
  }
  return String(result.message ?? '✅ Done! Check your Dashboard for updates.');
}

async function uploadToOmniChat(
  payload: { text?: string; file?: { uri: string; name: string; mimeType: string } },
  type: 'FOOD' | 'REPORT' | 'TEXT',
  chatId: string,
) {
  const form = new FormData();
  form.append('type',   type);
  form.append('chatId', chatId);
  if (payload.text) form.append('message', payload.text);
  if (payload.file) {
    form.append('file', {
      uri:  payload.file.uri,
      name: payload.file.name,
      type: payload.file.mimeType,
    } as unknown as Blob);
  }
  const res = await apiClient.post('/v1/chat/upload', form, {
    headers: { 'Content-Type': 'multipart/form-data' },
  });
  return res.data as {
    taskId:         string;
    status:         'PROCESSING' | 'COMPLETED';
    estimatedTime?: string;
    message?:       string;
    type?:          string;
  };
}

/** Polling fallback — used when WebSocket is not connected. */
async function pollTaskResult(taskId: string, onUpdate: (text: string) => void) {
  const MAX_POLLS = 20;
  for (let i = 0; i < MAX_POLLS; i++) {
    await new Promise((r) => setTimeout(r, 3000));
    try {
      const res  = await apiClient.get(`/v1/chat/tasks/${taskId}`);
      const task = res.data;
      if (task.status === 'COMPLETED') {
        onUpdate(formatTaskResult(task.result));
        return;
      }
      if (task.status === 'FAILED')  { onUpdate(`⚠️ Processing failed: ${task.error ?? 'Unknown error'}`); return; }
      if (task.status === 'PARTIAL') { onUpdate(task.result?.message ?? '⚠️ Partial result — some features coming soon.'); return; }
    } catch {
      // network hiccup — keep polling
    }
  }
  onUpdate('⏱ Still processing… check Dashboard in a moment.');
}

// ── Component ─────────────────────────────────────────────────────────────────

export default function OmniChatScreen({ navigation }: Props) {
  const { user } = useAuthStore();
  const chatId   = useRef(`chat-${Date.now()}`).current;
  const listRef  = useRef<FlatList>(null);

  // Track pending taskIds so we can match incoming WS messages
  const pendingTaskIds = useRef<Set<string>>(new Set());

  const [messages, setMessages] = useState<ChatMessage[]>([{
    id: '0', role: 'assistant', type: 'text',
    text: "What did you eat, or how are you feeling? You can share a food photo, upload a medical report, or update your profile — try \"Update my weight to 75 kg\" or \"Change my region to Punjab\".",
  }]);
  const [input, setInput]       = useState('');
  const [wsStatus, setWsStatus] = useState<'connecting' | 'live' | 'polling'>('connecting');

  const addMessage = (msg: Omit<ChatMessage, 'id'>) => {
    const m = { ...msg, id: Date.now().toString() };
    setMessages((prev) => [...prev, m]);
    return m;
  };

  const replaceProcessing = (text: string) =>
    setMessages((prev) =>
      prev.map((m) => m.type === 'processing' ? { ...m, type: 'ai-response' as const, text } : m),
    );

  // ── WebSocket handler ──────────────────────────────────────────────────────

  const handleWsMessage = useCallback((msg: TaskCompletionMessage) => {
    if (!pendingTaskIds.current.has(msg.taskId)) return; // not our task
    pendingTaskIds.current.delete(msg.taskId);

    if (msg.status === 'COMPLETED') {
      replaceProcessing(formatTaskResult(msg.result));
    } else if (msg.status === 'FAILED') {
      replaceProcessing(`⚠️ Processing failed: ${msg.result?.error ?? 'Unknown error'}`);
    } else if (msg.status === 'PARTIAL') {
      replaceProcessing(String(msg.result?.message ?? '⚠️ Partial result — some features coming soon.'));
    }
  }, []);

  const { isConnected: wsConnected } = useTaskWebSocket(
    user?.id ? String(user.id) : null,
    handleWsMessage,
  );

  // Update status indicator
  React.useEffect(() => {
    setWsStatus(wsConnected ? 'live' : 'polling');
  }, [wsConnected]);

  // ── Submit helpers ─────────────────────────────────────────────────────────

  const waitForResult = async (taskId: string) => {
    if (wsConnected) {
      // Register task — WS handler will resolve it
      pendingTaskIds.current.add(taskId);
      // Start polling anyway as a 30s safety net
      setTimeout(async () => {
        if (pendingTaskIds.current.has(taskId)) {
          pendingTaskIds.current.delete(taskId);
          await pollTaskResult(taskId, replaceProcessing);
        }
      }, 30000);
    } else {
      await pollTaskResult(taskId, replaceProcessing);
    }
  };

  // ── Send text ──────────────────────────────────────────────────────────────

  const handleSendText = async () => {
    const trimmed = input.trim();
    if (!trimmed) return;
    setInput('');
    addMessage({ role: 'user',      type: 'text',      text: trimmed });
    addMessage({ role: 'assistant', type: 'processing', text: '⏳ Thinking...' });

    try {
      const result = await uploadToOmniChat({ text: trimmed }, 'TEXT', chatId);
      if (result.status === 'COMPLETED' && result.message) {
        replaceProcessing(result.message);
      } else {
        replaceProcessing('⏳ Working on it...');
        await waitForResult(result.taskId);
      }
    } catch {
      replaceProcessing('⚠️ Could not reach Health OS. Check your connection.');
    }
  };

  // ── Attachment ─────────────────────────────────────────────────────────────

  const handleAttach = () => {
    if (Platform.OS === 'ios') {
      ActionSheetIOS.showActionSheetWithOptions(
        { options: ['Cancel', 'Food Photo', 'Medical Report (PDF)'], cancelButtonIndex: 0 },
        (idx) => { if (idx === 1) pickFoodImage(); if (idx === 2) pickMedicalPdf(); },
      );
    } else {
      Alert.alert('Attach', 'Choose type', [
        { text: 'Food Photo',           onPress: pickFoodImage },
        { text: 'Medical Report (PDF)', onPress: pickMedicalPdf },
        { text: 'Cancel', style: 'cancel' },
      ]);
    }
  };

  const pickFoodImage = async () => {
    const perm = await ImagePicker.requestMediaLibraryPermissionsAsync();
    if (!perm.granted) { Alert.alert('Permission required', 'Allow photo access to log food.'); return; }
    const result = await ImagePicker.launchImageLibraryAsync({ mediaTypes: ['images'], quality: 0.7 });
    if (result.canceled) return;
    const asset = result.assets[0];
    addMessage({ role: 'user',      type: 'food-image', text: '📷 Food photo attached' });
    addMessage({ role: 'assistant', type: 'processing',  text: '🔍 Identifying food and estimating macros...' });
    try {
      const upload = await uploadToOmniChat(
        { file: { uri: asset.uri, name: asset.fileName ?? 'food.jpg', mimeType: 'image/jpeg' } },
        'FOOD', chatId,
      );
      replaceProcessing('⏳ Analysing your photo...');
      await waitForResult(upload.taskId);
    } catch {
      replaceProcessing('⚠️ Upload failed. Try again.');
    }
  };

  const pickMedicalPdf = async () => {
    const result = await DocumentPicker.getDocumentAsync({ type: 'application/pdf' });
    if (result.canceled) return;
    const asset = result.assets[0];
    addMessage({ role: 'user',      type: 'medical-pdf', text: `📄 Medical report: ${asset.name}` });
    addMessage({ role: 'assistant', type: 'processing',   text: '🏥 Extracting lab values from your report...' });
    try {
      const upload = await uploadToOmniChat(
        { file: { uri: asset.uri, name: asset.name, mimeType: 'application/pdf' } },
        'REPORT', chatId,
      );
      replaceProcessing('⏳ Processing your report...');
      await waitForResult(upload.taskId);
    } catch {
      replaceProcessing('⚠️ Upload failed. Try again.');
    }
  };

  // ── Render ─────────────────────────────────────────────────────────────────

  return (
    <SafeAreaView style={styles.safe}>
      <View style={styles.topBar}>
        <TouchableOpacity onPress={() => navigation.goBack()} style={styles.backBtn}>
          <Text style={styles.backText}>← Dashboard</Text>
        </TouchableOpacity>
        <Text style={styles.title}>Health OS</Text>
        <View style={styles.statusPill}>
          <View style={[styles.statusDot, wsConnected ? styles.dotLive : styles.dotPoll]} />
          <Text style={styles.statusText}>{wsConnected ? 'Live' : 'Poll'}</Text>
        </View>
      </View>

      <KeyboardAvoidingView style={styles.flex} behavior={Platform.OS === 'ios' ? 'padding' : undefined}>
        <FlatList
          ref={listRef}
          data={messages}
          keyExtractor={(m) => m.id}
          contentContainerStyle={styles.chatList}
          onContentSizeChange={() => listRef.current?.scrollToEnd({ animated: true })}
          renderItem={({ item }) => (
            <View style={[styles.bubble, item.role === 'user' ? styles.userBubble : styles.aiBubble]}>
              <Text style={[styles.bubbleText, item.role === 'user' ? styles.userText : styles.aiText]}>
                {item.text}
              </Text>
            </View>
          )}
        />

        <View style={styles.inputRow}>
          <TouchableOpacity style={styles.attachBtn} onPress={handleAttach}>
            <Text style={styles.attachText}>+</Text>
          </TouchableOpacity>
          <TextInput
            style={styles.input}
            value={input}
            onChangeText={setInput}
            placeholder="Log food, symptoms, or ask anything..."
            placeholderTextColor="#555"
            onSubmitEditing={handleSendText}
            returnKeyType="send"
            multiline
          />
          <TouchableOpacity style={styles.sendBtn} onPress={handleSendText} disabled={!input.trim()}>
            <Text style={styles.sendText}>→</Text>
          </TouchableOpacity>
        </View>
      </KeyboardAvoidingView>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  safe:       { flex: 1, backgroundColor: '#0A0A0A' },
  flex:       { flex: 1 },
  topBar:     { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', paddingHorizontal: 16, paddingVertical: 12, borderBottomWidth: 1, borderBottomColor: '#1C1C1E' },
  backBtn:    { width: 80 },
  backText:   { color: '#2563EB', fontSize: 15 },
  title:      { color: '#FFFFFF', fontSize: 17, fontWeight: '600' },
  statusPill: { flexDirection: 'row', alignItems: 'center', backgroundColor: '#1C1C1E', borderRadius: 12, paddingHorizontal: 8, paddingVertical: 4 },
  statusDot:  { width: 7, height: 7, borderRadius: 4, marginRight: 5 },
  dotLive:    { backgroundColor: '#22C55E' },
  dotPoll:    { backgroundColor: '#F59E0B' },
  statusText: { color: '#9CA3AF', fontSize: 11 },
  chatList:   { paddingHorizontal: 16, paddingVertical: 12 },
  bubble:     { maxWidth: '82%', borderRadius: 18, padding: 13, marginBottom: 10 },
  aiBubble:   { backgroundColor: '#1C1C1E', alignSelf: 'flex-start' },
  userBubble: { backgroundColor: '#2563EB', alignSelf: 'flex-end' },
  bubbleText: { fontSize: 15, lineHeight: 22 },
  aiText:     { color: '#E5E7EB' },
  userText:   { color: '#FFFFFF' },
  inputRow:   { flexDirection: 'row', alignItems: 'flex-end', padding: 10, borderTopWidth: 1, borderTopColor: '#1C1C1E', backgroundColor: '#0A0A0A' },
  attachBtn:  { width: 44, height: 44, borderRadius: 22, backgroundColor: '#1C1C1E', alignItems: 'center', justifyContent: 'center', marginRight: 8 },
  attachText: { color: '#9CA3AF', fontSize: 24, lineHeight: 28 },
  input:      { flex: 1, backgroundColor: '#1C1C1E', color: '#FFFFFF', borderRadius: 20, paddingHorizontal: 16, paddingVertical: 10, fontSize: 15, maxHeight: 120 },
  sendBtn:    { width: 44, height: 44, borderRadius: 22, backgroundColor: '#2563EB', alignItems: 'center', justifyContent: 'center', marginLeft: 8 },
  sendText:   { color: '#FFFFFF', fontSize: 20, fontWeight: '700' },
});
