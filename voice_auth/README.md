# Voice-Based Login Authentication Backend

Flask backend for seller voice registration and voice login authentication.

## Tech Stack
- Python 3.10+
- Flask (REST API)
- OpenAI Whisper (speech-to-text preview)
- Resemblyzer (voice embeddings)
- Librosa + NumPy + SciPy (audio preprocessing)
- PostgreSQL (persistent database)

## Folder Structure
- app.py: Flask routes and response handling
- models.py: PostgreSQL schema and data access helpers
- audio_processing.py: upload validation and audio preprocessing
- voice_auth.py: embedding extraction and voice matching helpers
- requirements.txt: backend Python dependencies


## Install (Windows)
Run these commands from project root:

```powershell
py -3 -m venv .venv
.\.venv\Scripts\Activate.ps1
py -3 -m pip install --upgrade pip
py -3 -m pip install -r requirements.txt
```

If you only want backend dependencies:

```powershell
py -3 -m pip install -r voice_auth\requirements.txt
```

## Run Backend
From the backend folder:

```powershell
cd voice_auth
py -3 app.py
```

Server URLs:
- http://127.0.0.1:5000
- http://0.0.0.0:5000

## Environment Variables
- VOICE_MATCH_THRESHOLD (default: 0.75)
- WHISPER_MODEL (default: base)
- DATABASE_URL (optional, preferred)
- PGHOST (default: localhost)
- PGPORT (default: 5432)
- PGDATABASE (default: uzhavartrade_voiceauth)
- PGUSER (default: postgres)
- PGPASSWORD (default: postgres)

Example:

```powershell
$env:VOICE_MATCH_THRESHOLD = "0.78"
$env:WHISPER_MODEL = "small"
$env:DATABASE_URL = "postgresql://postgres:your_password@localhost:5432/uzhavartrade_voiceauth"
py -3 app.py
```

If you prefer PG* variables instead of DATABASE_URL:

```powershell
$env:PGHOST = "localhost"
$env:PGPORT = "5432"
$env:PGDATABASE = "uzhavartrade_voiceauth"
$env:PGUSER = "postgres"
$env:PGPASSWORD = "your_password"
py -3 app.py
```

## API Usage

### 1) Health
GET /health

Response:

```json
{
  "success": true,
  "message": "Voice auth service is running"
}
```

### 2) Register Seller
POST /register

Required form-data:
- name
- phone
- audio_files (2 or 3 files)

PowerShell example:

```powershell
curl.exe -X POST "http://127.0.0.1:5000/register" `
  -F "name=Kumar" `
  -F "phone=9876543210" `
  -F "audio_files=@sample1.wav" `
  -F "audio_files=@sample2.wav"
```

### 3) Login Seller
POST /login

Required form-data:
- audio

Optional form-data:
- phone

PowerShell example:

```powershell
curl.exe -X POST "http://127.0.0.1:5000/login" `
  -F "audio=@login.wav" `
  -F "phone=9876543210"
```

Success response includes:
- authenticated
- confidence_score
- threshold
- seller

Failure response includes:
- otp_required
- otp_code (mock fallback)

### 4) List Sellers
GET /sellers

Returns seller metadata only (no embedding vectors).

### 5) Login Audit
GET /login-attempts?limit=20

Returns recent login attempt logs.

## Audio Requirements
- Supported extensions: .wav, .mp3, .m4a, .flac, .ogg, .aac, .webm
- Suggested clip length: 2 to 5 seconds
- Max upload size: 15 MB per file
- Best results: clear speech in low-noise environment

## Troubleshooting
- If `python` command is unavailable on Windows, use `py -3`.
- If port 5000 is busy, stop the running process or start on a different port.
- If voice matching is too strict, lower VOICE_MATCH_THRESHOLD slightly (for example, 0.75 to 0.72).
- If database connection fails, verify your PostgreSQL service is running and your `DATABASE_URL` or `PG*` credentials are correct.
