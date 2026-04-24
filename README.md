# NADRA Queue Management System - Mobile App 📱🎫

This is the frontend repository for the **NADRA Queue Management System**. Built with Flutter, this cross-platform mobile application allows citizens to bypass physical lines by booking and tracking their NADRA service tokens digitally. 

## 🚀 Tech Stack
* **Framework:** Flutter (Dart)
* **State Management & Storage:** Stateful Widgets, Shared Preferences
* **Network Integration:** HTTP (REST API integration with Django backend)
* **UI/UX:** Custom Material Design with Full Dark/Light Mode Support

## ✨ Core Features
* **Smart Booking Wizard:** A step-by-step intuitive wizard to select City, District, and specific NADRA Offices.
* **Live Token Status:** Real-time visibility of active, completed, or cancelled tokens.
* **Office Locator:** View nearby NADRA branches along with estimated wait times.
* **AI Assistant Chatbot:** An integrated smart assistant to answer common queries regarding NADRA processes in Urdu and English.
* **Bilingual Interface:** Quick action cards and key instructions available in both English and Urdu.

## ⚙️ Installation & Setup

Follow these steps to run the mobile app on your local machine or emulator:

**1. Clone the repository:**
```bash
git clone [https://github.com/yourusername/nadra-queue-frontend.git](https://github.com/yourusername/nadra-queue-frontend.git)
cd nadra-queue-frontend
2. Fetch Flutter packages:
Bash

flutter pub get

3. Configure the Backend API:
Open lib/api_config.dart and ensure the base URL points to your running backend (either localhost or your PythonAnywhere domain):

Dart

static const String baseUrl = '[http://yourusername.pythonanywhere.com/api](http://yourusername.pythonanywhere.com/api)';
4. Run the application:

Bash

flutter run
📂 Key Project Structure
/lib/screens/ - Contains all UI views (HomeScreen, BookingWizard, ChatbotScreen, etc.)

/lib/api_config.dart - Centralized API endpoint management.

👨‍💻 Author
Dilawer Khan - AI & Data Science Engineer (Team Lead)


---

### 3. Frontend ko CMD ke zariye Push Karein

Ab apne Flutter project ke folder (jaise `Desktop\Project AI\nadra_queue_app`) mein CMD open karein aur bari bari yeh commands run karein:

**Step 1: Git Initialize karein**
```cmd
git init
