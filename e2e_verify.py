import requests
import time

BASE_URL = "http://localhost:8080/api"
AI_HEALTH_URL = "http://localhost:8000/health"

def verify_system():
    print("🚀 Starting End-to-End Verification...")

    # 1. Check AI Service Health
    try:
        response = requests.get(AI_HEALTH_URL)
        if response.status_code == 200:
            print("✅ AI Service is UP")
        else:
            print(f"❌ AI Service Health Check failed: {response.status_code}")
    except Exception as e:
        print(f"❌ Could not connect to AI Service: {e}")

    # 2. Check Backend Health
    # Note: Adjust endpoint if actuator is not enabled or path is different
    try:
        response = requests.get("http://localhost:8080/actuator/health")
        if response.status_code == 200:
            print("✅ Backend is UP")
    except:
        print("ℹ️ Backend health check skipped (Actuator might be disabled or different port)")

    # 3. Register a Test User
    user_data = {
        "email": f"test_e2e_{int(time.time())}@example.com",
        "password": "password123",
        "age": 30,
        "gender": "Male",
        "height": 175.5,
        "goal": "Build Muscle",
        "dietType": "Omnivore",
        "medicalFlags": "None"
    }
    
    try:
        register_res = requests.post(f"{BASE_URL}/auth/register", json=user_data)
        if register_res.status_code in [200, 201]:
            print("✅ User Registration Successful")
            token = register_res.json()["accessToken"]
        else:
            print(f"❌ Registration failed: {register_res.text}")
            return
    except Exception as e:
        print(f"❌ Error during registration: {e}")
        return

    headers = {"Authorization": f"Bearer {token}"}

    # 4. Log Workout
    workout_data = {
        "exerciseName": "Bench Press",
        "sets": 3,
        "reps": 10,
        "weight": 80.0,
        "date": time.strftime("%Y-%m-%d")
    }
    try:
        workout_res = requests.post(f"{BASE_URL}/workouts", json=workout_data, headers=headers)
        if workout_res.status_code in [200, 201]:
            print("✅ Workout Logged Successfully")
        else:
            print(f"❌ Failed to log workout: {workout_res.text}")
    except Exception as e:
        print(f"❌ Error logging workout: {e}")

    # 5. Get structured health summary
    try:
        print("⏳ Fetching Health Summary...")
        summary_res = requests.get(f"{BASE_URL}/health-summary/me", headers=headers)
        if summary_res.status_code == 200:
            print("✅ Health Summary Retrieved")
        else:
            print(f"❌ Failed to get summary: {summary_res.text}")
            return
    except Exception as e:
        print(f"❌ Error getting summary: {e}")
        return

    # 6. Trigger AI insights
    try:
        print("⏳ Generating AI Insights...")
        ai_res = requests.post(f"{BASE_URL}/health-summary/me/ai-insights", headers=headers)
        if ai_res.status_code == 200:
            print("✅ AI Insights Retrieved")
            print("--- AI Recommended Diet ---")
            ai_insights = ai_res.json().get("ai_insights", {})
            print(ai_insights.get("dietSuggestions", "No data"))
        else:
            print(f"❌ Failed to get AI insights: {ai_res.text}")
    except Exception as e:
        print(f"❌ Error getting AI insights: {e}")

    print("\n🏁 E2E Verification Finished!")

if __name__ == "__main__":
    verify_system()
