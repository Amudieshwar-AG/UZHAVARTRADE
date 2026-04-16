# UzhavarTrade

A zero-literacy, Tamil voice-powered marketplace built with Flutter, with a Python voice-auth backend for seller login.

## Features
- Voice-based product listing in Tamil
- Voice search for buyers
- Text-to-Speech feedback
- Offline local storage with Hive
- Seller voice registration and authentication backend

## Project Layout
- lib/: Flutter app
- voice_auth/: Flask backend for voice authentication
- requirements.txt: root dependency entry for backend

## Run Flutter App
From project root:

```powershell
flutter pub get
flutter run
```

## Run Voice Auth Backend
From project root:

```powershell
py -3 -m pip install -r requirements.txt
$env:DATABASE_URL = "postgresql://postgres:your_password@localhost:5432/uzhavartrade_voiceauth"
cd voice_auth
py -3 app.py
```

For full backend usage and endpoint examples, see voice_auth/README.md.
