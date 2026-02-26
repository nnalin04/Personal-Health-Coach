# 🥗 Personal AI Health Intelligence System

A premium, localized health and performance monitoring ecosystem that transforms your biometric data and medical reports into actionable, AI-driven insights. Powered by **Google Gemini AI** and built with a modern high-performance stack.

---

## 🚀 Overview

The **Personal AI Health Intelligence System** is a private, cross-platform solution designed to help users track their fitness journey with medical-grade precision. By integrating workout logs, nutritional data, and automated medical report parsing, the system provides a holistic view of your health.

### 🎯 Key Objectives

- **Data Centralization**: Store a lifetime of health metrics in a private PostgreSQL database.
- **AI-Powered Insights**: Use Google Gemini to analyze trends and provide personalized diet and training advice.
- **Medical Report Intelligence**: Automatically parse complex blood work and laboratory reports (PDF/Image) into structured data.
- **Privacy First**: Designed for local or private cloud deployment using Docker.

---

## ✨ Features

- **🔐 Secure Authentication**: Multi-factor ready with traditional Email/Password and **Google Sign-In** support.
- **📋 Health Logging**:
  - **Workouts**: Track exercises, sets, reps, and volume.
  - **Nutrition**: Log meals with calorie and macronutrient breakdown.
  - **Metrics**: Monitor weight, BMI, body fat, and muscle mass.
  - **Activity**: Daily step tracking with historical trends.
- **🧪 Medical Lab Analysis**: Upload medical reports to extract laboratory values and compare them against healthy ranges.
- **🧠 AI Health Summary**:
  - Longitudinal analysis over 7, 30, and 90-day windows.
  - Automated risk flag detection (e.g., protein deficit, high caloric intake).
  - Contextual recommendations for diet, training, and medical awareness.
- **📊 Interactive Visualizations**: Beautiful charts depicting weight trends and health metrics in the mobile app.

---

## 🛠 Tech Stack

### Backend

- **Core**: Java 17, Spring Boot 3.x
- **Security**: Spring Security, JWT, Google OAuth 2.0
- **Database**: PostgreSQL 16 (Relational & Scalable)
- **API**: RESTful architecture with Clean Architecture patterns.

### AI Service

- **Core**: Python 3.11, FastAPI
- **AI Model**: **Google Gemini 1.5 Flash** (via Google Generative AI SDK)
- **Document Parsing**: PyPDF for text extraction and Gemini for structured vision-to-text.

### Mobile

- **Framework**: Flutter (Cross-platform iOS & Android)
- **State Management**: Riverpod (Reactive and Scalable)
- **Networking**: Dio with secure token interceptors.
- **Authentication**: `google_sign_in` package.

### Infrastructure

- **Containerization**: Docker & Docker Compose
- **Testing**: JUnit 5, Mockito, pytest, Flutter Test.

---

## 📦 Project Structure

```text
.
├── backend/            # Spring Boot Application
├── ai-service/        # FastAPI & Gemini AI Logic
├── mobile/             # Flutter Mobile Application
├── docker-compose.yml  # System Orchestration
├── .env.example       # Template for environment variables
└── e2e_verify.py      # Automated End-to-End Test Script
```

---

## 🏗 Setup & Installation

### 1. Environment Configuration

Copy `.env.example` to `.env` in the root directory and fill required secrets:

```bash
cp .env.example .env
GEMINI_API_KEY=your_google_ai_key
GOOGLE_CLIENT_ID=your_google_oauth_id
```

### 2. Run with Docker (Recommended)

Launch the entire ecosystem with a single command:

```bash
docker-compose up --build -d
```

Access the backend at `http://localhost:8080/` and the AI service at `http://localhost:8000/`.

### 2.1 GCP Multi-Env Deployment (Dev/UAT/Prod)

1. Create env files from templates:
   ```bash
   cp .env.dev.tmpl .env.dev
   cp .env.uat.tmpl .env.uat
   cp .env.prod.tmpl .env.prod
   ```
2. Fill all secrets in each file (`JWT_SECRET`, `POSTGRES_PASSWORD`, `GEMINI_API_KEY`, `GOOGLE_CLIENT_ID`).
3. Deploy:
   ```bash
   ./deploy_to_gcp_dev.sh
   ./deploy_to_gcp_uat.sh
   ./deploy_to_gcp_prod.sh
   ```
4. Optional: override project/zone/instance/machine type:
   ```bash
   PROJECT_ID=my-gcp-project ZONE=us-central1-a ./deploy_to_gcp_dev.sh
   ```

Notes:
- These scripts deploy to separate Compute Engine VMs (one per environment).
- The scripts package and upload `backend/`, `ai-service/`, compose file, and env file before running `docker compose up -d --build`.
- Backend will be available on port `8080` of each VM public IP.

### 3. Mobile Setup

- Ensure the Flutter SDK is installed.
- If this repository does not yet include platform folders, initialize them first:
  ```bash
  cd mobile
  flutter create .
  ```
- Setup Google Services:
  - Add `google-services.json` to `mobile/android/app/`.
  - Add `GoogleService-Info.plist` to `mobile/ios/Runner/`.
- Run:
  ```bash
  cd mobile
  flutter pub get
  flutter run
  ```

### 4. APK User Connection Setup (Important)

- The app now supports runtime backend URL configuration.
- In the app, go to:
  - `Profile Settings` -> `Connection` -> `API Base URL`
- Set your deployed backend URL, for example:
  - `https://api.yourdomain.com/api`
- Save changes, then use the app normally.
- For emulator-only local usage, default is:
  - `http://10.0.2.2:8080/api`

---

## 🧪 Testing

### Automated E2E Verification

I have included a specialized verification script to test the entire flow:

```bash
python3 e2e_verify.py
```

This script validates:
- backend + AI service health
- auth registration
- workout logging
- `/api/health-summary/me`
- `/api/health-summary/me/ai-insights`

### Manual Testing

- **Backend**: `cd backend && mvn test`
- **AI Service**: `cd ai-service && python3 -m pytest` (requires pytest installed)
- **Mobile**: `cd mobile && flutter test`

---

## 📋 Deployment TODO

- A complete deployment + production checklist is tracked in:
  - `PROJECT_TODO.md`

---

## 🛡 Security & Privacy

- **JWT Tokens**: All API requests are secured via stateless JWT tokens.
- **Local AI**: The Python service acts as a gateway, ensuring your raw health data is only sent to AI models with strictly filtered context.
- **OAuth**: Uses Google's official identity platform for secure social login.

---

_Created with ❤️ for a Healthier Intelligence._
