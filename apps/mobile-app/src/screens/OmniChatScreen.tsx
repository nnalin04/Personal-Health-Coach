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
import MaterialIcons from 'react-native-vector-icons/MaterialIcons';

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
    text: "Hi! What did you eat today? You can share a food photo, upload a medical report, or just talk.",
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

  const handleSendText = async (textOverride?: string) => {
    const textToSend = textOverride || input;
    const trimmed = textToSend.trim();
    if (!trimmed) return;
    setInput('');
    addMessage({ role: 'user',      type: 'text',      text: trimmed });
    addMessage({ role: 'assistant', type: 'processing', text: 'Analysing...' });

    try {
      const result = await uploadToOmniChat({ text: trimmed }, 'TEXT', chatId);
      if (result.status === 'COMPLETED' && result.message) {
        replaceProcessing(result.message);
      } else {
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
    addMessage({ role: 'user',      type: 'food-image', text: '📷 Food photo' });
    addMessage({ role: 'assistant', type: 'processing',  text: 'Analysing photo...' });
    try {
      const upload = await uploadToOmniChat(
        { file: { uri: asset.uri, name: asset.fileName ?? 'food.jpg', mimeType: 'image/jpeg' } },
        'FOOD', chatId,
      );
      await waitForResult(upload.taskId);
    } catch {
      replaceProcessing('⚠️ Upload failed. Try again.');
    }
  };

  const pickMedicalPdf = async () => {
    const result = await DocumentPicker.getDocumentAsync({ type: 'application/pdf' });
    if (result.canceled) return;
    const asset = result.assets[0];
    addMessage({ role: 'user',      type: 'medical-pdf', text: `📄 ${asset.name}` });
    addMessage({ role: 'assistant', type: 'processing',   text: 'Processing report...' });
    try {
      const upload = await uploadToOmniChat(
        { file: { uri: asset.uri, name: asset.name, mimeType: 'application/pdf' } },
        'REPORT', chatId,
      );
      await waitForResult(upload.taskId);
    } catch {
      replaceProcessing('⚠️ Upload failed. Try again.');
    }
  };

  // ── Render ─────────────────────────────────────────────────────────────────
  
  const displayName = user?.email ? user.email.split('@')[0] : 'User';

  return (
    <SafeAreaView style={styles.safe}>
      {/* TopAppBar */}
      <View style={styles.header}>
        <View style={styles.headerLeft}>
          <TouchableOpacity onPress={() => navigation.goBack()} style={styles.backBtn}>
            <MaterialIcons name="arrow-back" size={24} color="#9CA3AF" />
          </TouchableOpacity>
          <Text style={styles.headerSubtitle}>Dashboard</Text>
        </View>
        <Text style={styles.headerTitle}>Health OS</Text>
        <View style={styles.headerRight}>
          <View style={[styles.statusDot, wsConnected ? styles.dotLive : styles.dotPoll]} />
        </View>
      </View>

      <KeyboardAvoidingView style={styles.flex} behavior={Platform.OS === 'ios' ? 'padding' : undefined}>
        <FlatList
          ref={listRef}
          data={messages}
          keyExtractor={(m) => m.id}
          contentContainerStyle={styles.chatList}
          onContentSizeChange={() => listRef.current?.scrollToEnd({ animated: true })}
          renderItem={({ item, index }) => (
            <View>
              {item.role === 'assistant' ? (
                <View style={[styles.messageRow, { justifyContent: 'flex-start' }]}>
                  <View style={styles.aiAvatar}>
                    <MaterialIcons name="smart-toy" size={20} color="#2463eb" />
                  </View>
                  <View style={styles.aiMessageContainer}>
                    <Text style={styles.aiMessageSenderText}>HEALTH AI</Text>
                    <View style={styles.aiBubble}>
                      <Text style={[styles.bubbleText, item.type === 'processing' && styles.processingText]}>
                        {item.text}
                      </Text>
                    </View>
                  </View>
                </View>
              ) : (
                <View style={[styles.messageRow, { justifyContent: 'flex-end' }]}>
                  <View style={styles.userMessageContainer}>
                    <Text style={styles.userMessageSenderText}>{displayName.toUpperCase()}</Text>
                    <View style={styles.userBubble}>
                      <Text style={[styles.bubbleText, { color: '#FFFFFF' }]}>
                        {item.text}
                      </Text>
                    </View>
                  </View>
                  <View style={styles.userAvatar}>
                    <Text style={styles.userAvatarText}>{displayName.substring(0, 1).toUpperCase()}</Text>
                  </View>
                </View>
              )}
              
              {/* Show suggestions after the first AI message */}
              {index === 0 && (
                <View style={styles.suggestionsContainer}>
                  <TouchableOpacity style={styles.suggestionBtn} onPress={() => handleSendText('Log breakfast')}>
                    <MaterialIcons name="restaurant" size={14} color="#2463eb" />
                    <Text style={styles.suggestionText}>Log breakfast</Text>
                  </TouchableOpacity>
                  <TouchableOpacity style={styles.suggestionBtn} onPress={() => handleSendText('Log lunch')}>
                    <MaterialIcons name="lunch-dining" size={14} color="#2463eb" />
                    <Text style={styles.suggestionText}>Log lunch</Text>
                  </TouchableOpacity>
                  <TouchableOpacity style={styles.suggestionBtn} onPress={pickMedicalPdf}>
                    <MaterialIcons name="upload-file" size={14} color="#2463eb" />
                    <Text style={styles.suggestionText}>Upload report</Text>
                  </TouchableOpacity>
                </View>
              )}
            </View>
          )}
        />

        {/* Input Bar */}
        <View style={styles.inputContainer}>
          <View style={styles.inputRow}>
            <TouchableOpacity style={styles.attachBtn} onPress={handleAttach}>
              <MaterialIcons name="attach-file" size={24} color="#9CA3AF" />
            </TouchableOpacity>
            <View style={styles.textInputWrapper}>
              <TextInput
                style={styles.input}
                value={input}
                onChangeText={setInput}
                placeholder="Message..."
                placeholderTextColor="#6B7280"
                onSubmitEditing={() => handleSendText()}
                returnKeyType="send"
              />
            </View>
            <TouchableOpacity style={styles.sendBtn} onPress={() => handleSendText()} disabled={!input.trim()}>
              <MaterialIcons name="send" size={20} color="#FFFFFF" />
            </TouchableOpacity>
          </View>
        </View>
      </KeyboardAvoidingView>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  safe: { flex: 1, backgroundColor: '#0A0A0A' },
  flex: { flex: 1 },
  header: { flexDirection: 'row', alignItems: 'center', backgroundColor: '#0A0A0A', borderBottomWidth: 1, borderBottomColor: '#1F2937', padding: 16 },
  headerLeft: { flex: 1, flexDirection: 'row', alignItems: 'center', gap: 8 },
  backBtn: { padding: 4 },
  headerSubtitle: { color: '#9CA3AF', fontSize: 14, fontWeight: '500' },
  headerTitle: { color: '#FFFFFF', fontSize: 18, fontWeight: '700', textAlign: 'center' },
  headerRight: { flex: 1, alignItems: 'flex-end', justifyContent: 'center' },
  statusDot: { width: 10, height: 10, borderRadius: 5, shadowOffset: { width: 0, height: 0 }, shadowRadius: 8, elevation: 4 },
  dotLive: { backgroundColor: '#22C55E', shadowColor: '#22C55E', shadowOpacity: 0.6 },
  dotPoll: { backgroundColor: '#F59E0B', shadowColor: '#F59E0B', shadowOpacity: 0.6 },
  chatList: { padding: 16, paddingBottom: 24, gap: 24 },
  messageRow: { flexDirection: 'row', alignItems: 'flex-start', gap: 12, marginBottom: 24 },
  aiAvatar: { backgroundColor: 'rgba(36, 99, 235, 0.1)', borderRadius: 20, padding: 8 },
  aiMessageContainer: { flex: 1, alignItems: 'flex-start', gap: 4, maxWidth: '80%' },
  aiMessageSenderText: { color: '#9CA3AF', fontSize: 12, fontWeight: '500', marginLeft: 4, textTransform: 'uppercase', letterSpacing: 1 },
  aiBubble: { backgroundColor: '#1C1C1E', borderRadius: 16, borderTopLeftRadius: 4, paddingHorizontal: 16, paddingVertical: 12, shadowColor: '#000', shadowOffset: { width: 0, height: 1 }, shadowOpacity: 0.1, shadowRadius: 2, elevation: 1 },
  userAvatar: { width: 40, height: 40, borderRadius: 20, backgroundColor: 'rgba(36, 99, 235, 0.2)', borderWidth: 2, borderColor: 'rgba(36, 99, 235, 0.2)', alignItems: 'center', justifyContent: 'center' },
  userAvatarText: { color: '#2463eb', fontSize: 16, fontWeight: '700' },
  userMessageContainer: { flex: 1, alignItems: 'flex-end', gap: 4, maxWidth: '80%' },
  userMessageSenderText: { color: '#9CA3AF', fontSize: 12, fontWeight: '500', marginRight: 4, textTransform: 'uppercase', letterSpacing: 1 },
  userBubble: { backgroundColor: '#2463eb', borderRadius: 16, borderTopRightRadius: 4, paddingHorizontal: 16, paddingVertical: 12, shadowColor: '#2463eb', shadowOffset: { width: 0, height: 4 }, shadowOpacity: 0.1, shadowRadius: 8, elevation: 4 },
  bubbleText: { color: '#F1F5F9', fontSize: 15, lineHeight: 22 },
  processingText: { fontStyle: 'italic', color: '#9CA3AF' },
  suggestionsContainer: { flexDirection: 'row', flexWrap: 'wrap', gap: 8, paddingLeft: 48, marginTop: -12, marginBottom: 16 },
  suggestionBtn: { flexDirection: 'row', alignItems: 'center', gap: 8, height: 36, paddingHorizontal: 16, borderRadius: 18, borderWidth: 1, borderColor: '#1F2937', backgroundColor: '#1C1C1E' },
  suggestionText: { color: '#CBD5E1', fontSize: 14, fontWeight: '500' },
  inputContainer: { backgroundColor: '#0A0A0A', borderTopWidth: 1, borderTopColor: '#1F2937', padding: 16 },
  inputRow: { flexDirection: 'row', alignItems: 'center', gap: 12, maxWidth: 896, alignSelf: 'center', width: '100%' },
  attachBtn: { width: 48, height: 48, borderRadius: 12, backgroundColor: '#1C1C1E', alignItems: 'center', justifyContent: 'center' },
  textInputWrapper: { flex: 1 },
  input: { height: 48, backgroundColor: '#1C1C1E', borderRadius: 12, paddingHorizontal: 16, color: '#F1F5F9', fontSize: 15 },
  sendBtn: { width: 48, height: 48, borderRadius: 12, backgroundColor: '#2463eb', alignItems: 'center', justifyContent: 'center', shadowColor: '#2463eb', shadowOffset: { width: 0, height: 4 }, shadowOpacity: 0.2, shadowRadius: 8, elevation: 4 },
});
