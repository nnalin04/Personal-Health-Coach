/**
 * Page 3 — Omni-Chat Interface
 *
 * The primary input engine for the Health OS.
 * Universal '+' button supports:
 *   - Text messages  (natural language food/symptom logging)
 *   - Food images    (routed → Gemini Vision pipeline)
 *   - Medical PDFs   (routed → Document AI OCR pipeline)
 *
 * Long-running tasks return taskId + "PROCESSING" status.
 * WebSocket subscription updates the chat when AI finishes.
 *
 * Smart Router on backend classifies input as FOOD | REPORT | TEXT.
 */
import React, { useState, useRef } from 'react';
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
import * as ImagePicker from 'expo-image-picker';
import * as DocumentPicker from 'expo-document-picker';
import { StackNavigationProp } from '@react-navigation/stack';
import { RootStackParamList } from '../navigation/AppNavigator';

type Props = { navigation: StackNavigationProp<RootStackParamList, 'OmniChat'> };

type MessageType = 'text' | 'food-image' | 'medical-pdf' | 'ai-response' | 'processing';

interface ChatMessage {
  id: string;
  role: 'user' | 'assistant';
  type: MessageType;
  text: string;
  taskId?: string;
}

const BASE_URL = process.env.EXPO_PUBLIC_API_URL ?? 'https://healthcoach.duckdns.org/api';

interface OmniChatResponse {
  taskId: string;
  status: 'PROCESSING' | 'COMPLETED';
  estimatedTime?: string;
  message?: string;   // set when status === 'COMPLETED' (e.g. profile update confirmation)
  type?: string;      // e.g. 'PROFILE_UPDATE'
}

async function uploadToOmniChat(
  payload: { text?: string; file?: { uri: string; name: string; mimeType: string } },
  type: 'FOOD' | 'REPORT' | 'TEXT',
  chatId: string,
): Promise<OmniChatResponse> {
  const form = new FormData();
  form.append('type', type);
  form.append('chatId', chatId);
  if (payload.text) form.append('message', payload.text);
  if (payload.file) {
    form.append('file', { uri: payload.file.uri, name: payload.file.name, type: payload.file.mimeType } as any);
  }
  const res = await fetch(`${BASE_URL}/v1/chat/upload`, {
    method: 'POST',
    body: form,
    headers: { 'Accept': 'application/json' },
  });
  return res.json();
}

export default function OmniChatScreen({ navigation }: Props) {
  const chatId = useRef(`chat-${Date.now()}`).current;
  const [messages, setMessages] = useState<ChatMessage[]>([
    {
      id: '0',
      role: 'assistant',
      type: 'text',
      text: "What did you eat, or how are you feeling? You can also share a food photo, upload a medical report, or update your profile — just say things like \"Update my weight to 75 kg\" or \"Change my region to Punjab\".",
    },
  ]);
  const [input, setInput] = useState('');
  const listRef = useRef<FlatList>(null);

  const addMessage = (msg: Omit<ChatMessage, 'id'>) => {
    const newMsg = { ...msg, id: Date.now().toString() };
    setMessages((prev) => [...prev, newMsg]);
    return newMsg;
  };

  const handleSendText = async () => {
    const trimmed = input.trim();
    if (!trimmed) return;
    setInput('');
    addMessage({ role: 'user', type: 'text', text: trimmed });
    addMessage({ role: 'assistant', type: 'processing', text: '⏳ Analyzing...' });

    try {
      const result = await uploadToOmniChat({ text: trimmed }, 'TEXT', chatId);
      const responseText = result.status === 'COMPLETED' && result.message
        ? result.message
        : `Got it! Task ${result.taskId} is ${result.status}. Estimated: ${result.estimatedTime}`;
      setMessages((prev) =>
        prev.map((m) =>
          m.type === 'processing' ? { ...m, type: 'ai-response', text: responseText } : m,
        ),
      );
    } catch {
      setMessages((prev) =>
        prev.map((m) => (m.type === 'processing' ? { ...m, type: 'ai-response', text: '⚠️ Could not reach Health OS. Check your connection.' } : m)),
      );
    }
  };

  const handleAttach = () => {
    if (Platform.OS === 'ios') {
      ActionSheetIOS.showActionSheetWithOptions(
        { options: ['Cancel', 'Food Photo', 'Medical Report (PDF)'], cancelButtonIndex: 0 },
        (idx) => {
          if (idx === 1) pickFoodImage();
          if (idx === 2) pickMedicalPdf();
        },
      );
    } else {
      Alert.alert('Attach', 'Choose type', [
        { text: 'Food Photo',         onPress: pickFoodImage },
        { text: 'Medical Report PDF', onPress: pickMedicalPdf },
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
    addMessage({ role: 'user', type: 'food-image', text: `📷 Food photo attached` });
    addMessage({ role: 'assistant', type: 'processing', text: '🔍 Identifying food and estimating macros...' });
    try {
      const upload = await uploadToOmniChat(
        { file: { uri: asset.uri, name: asset.fileName ?? 'food.jpg', mimeType: 'image/jpeg' } },
        'FOOD',
        chatId,
      );
      setMessages((prev) =>
        prev.map((m) =>
          m.type === 'processing'
            ? { ...m, type: 'ai-response', text: `✅ Vision analysis started (${upload.taskId}). Dashboard will update in ~${upload.estimatedTime}.`, taskId: upload.taskId }
            : m,
        ),
      );
    } catch {
      setMessages((prev) =>
        prev.map((m) => (m.type === 'processing' ? { ...m, type: 'ai-response', text: '⚠️ Upload failed. Try again.' } : m)),
      );
    }
  };

  const pickMedicalPdf = async () => {
    const result = await DocumentPicker.getDocumentAsync({ type: 'application/pdf' });
    if (result.canceled) return;
    const asset = result.assets[0];
    addMessage({ role: 'user', type: 'medical-pdf', text: `📄 Medical report: ${asset.name}` });
    addMessage({ role: 'assistant', type: 'processing', text: '🏥 Extracting lab values from your report...' });
    try {
      const upload = await uploadToOmniChat(
        { file: { uri: asset.uri, name: asset.name, mimeType: 'application/pdf' } },
        'REPORT',
        chatId,
      );
      setMessages((prev) =>
        prev.map((m) =>
          m.type === 'processing'
            ? { ...m, type: 'ai-response', text: `✅ OCR started (${upload.taskId}). Blood metrics will appear in your Dashboard in ~${upload.estimatedTime}.`, taskId: upload.taskId }
            : m,
        ),
      );
    } catch {
      setMessages((prev) =>
        prev.map((m) => (m.type === 'processing' ? { ...m, type: 'ai-response', text: '⚠️ Upload failed. Try again.' } : m)),
      );
    }
  };

  return (
    <SafeAreaView style={styles.safe}>
      <View style={styles.topBar}>
        <TouchableOpacity onPress={() => navigation.goBack()} style={styles.backBtn}>
          <Text style={styles.backText}>← Dashboard</Text>
        </TouchableOpacity>
        <Text style={styles.title}>Health OS</Text>
        <View style={{ width: 80 }} />
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
  safe:        { flex: 1, backgroundColor: '#0A0A0A' },
  flex:        { flex: 1 },
  topBar:      { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', paddingHorizontal: 16, paddingVertical: 12, borderBottomWidth: 1, borderBottomColor: '#1C1C1E' },
  backBtn:     { width: 80 },
  backText:    { color: '#2563EB', fontSize: 15 },
  title:       { color: '#FFFFFF', fontSize: 17, fontWeight: '600' },
  chatList:    { paddingHorizontal: 16, paddingVertical: 12 },
  bubble:      { maxWidth: '82%', borderRadius: 18, padding: 13, marginBottom: 10 },
  aiBubble:    { backgroundColor: '#1C1C1E', alignSelf: 'flex-start' },
  userBubble:  { backgroundColor: '#2563EB', alignSelf: 'flex-end' },
  bubbleText:  { fontSize: 15, lineHeight: 22 },
  aiText:      { color: '#E5E7EB' },
  userText:    { color: '#FFFFFF' },
  inputRow:    { flexDirection: 'row', alignItems: 'flex-end', padding: 10, borderTopWidth: 1, borderTopColor: '#1C1C1E', backgroundColor: '#0A0A0A' },
  attachBtn:   { width: 44, height: 44, borderRadius: 22, backgroundColor: '#1C1C1E', alignItems: 'center', justifyContent: 'center', marginRight: 8 },
  attachText:  { color: '#9CA3AF', fontSize: 24, lineHeight: 28 },
  input:       { flex: 1, backgroundColor: '#1C1C1E', color: '#FFFFFF', borderRadius: 20, paddingHorizontal: 16, paddingVertical: 10, fontSize: 15, maxHeight: 120 },
  sendBtn:     { width: 44, height: 44, borderRadius: 22, backgroundColor: '#2563EB', alignItems: 'center', justifyContent: 'center', marginLeft: 8 },
  sendText:    { color: '#FFFFFF', fontSize: 20, fontWeight: '700' },
});
