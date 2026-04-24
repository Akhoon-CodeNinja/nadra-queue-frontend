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
git clone [https://github.com/Akhoon-CodeNinja/nadra-queue-frontend.git](https://github.com/Akhoon-CodeNinja/nadra-queue-frontend.git)
cd nadra-queue-frontend
```

**2. Fetch Flutter packages:**
```bash
flutter pub get
```

**3. Configure the Backend API:**
Open `lib/api_config.dart` and ensure the base URL points to your running backend (either localhost or your PythonAnywhere domain):
```dart
static const String baseUrl = '[http://yourusername.pythonanywhere.com/api](http://yourusername.pythonanywhere.com/api)';
```

**4. Run the application:**
```bash
flutter run
```

## 📂 Key Project Structure
* `/lib/screens/` - Contains all UI views (HomeScreen, BookingWizard, ChatbotScreen, etc.)
* `/lib/api_config.dart` - Centralized API endpoint management.

## 👨‍💻 Author
**Dilawer Khan** - *AI & Data Science Engineer (Team Lead)*
```

---

### 2. CMD Commands (Push Karne Ke Liye)
Apne Flutter folder (`nadra_queue_app`) mein CMD open karein aur in commands ko ek ek karke run karein:

```cmd
git init
git add .
git commit -m "Initial commit with complete Flutter frontend and README"
git branch -M main
git remote add origin https://github.com/Akhoon-CodeNinja/nadra-queue-frontend.git
git push -u origin main
```
