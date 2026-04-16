from __future__ import annotations

import os
import tempfile
from pathlib import Path
from typing import Tuple

import librosa
import numpy as np
from werkzeug.datastructures import FileStorage

TARGET_SR = 16000
MIN_DURATION_SECONDS = 1.5
MAX_DURATION_SECONDS = 5.0
TRIM_TOP_DB = 30
MAX_UPLOAD_SIZE_MB = 15
SUPPORTED_AUDIO_SUFFIXES = {
    ".wav",
    ".mp3",
    ".m4a",
    ".flac",
    ".ogg",
    ".aac",
    ".webm",
}


def _normalize_audio(audio: np.ndarray) -> np.ndarray:
    if audio.size == 0:
        return audio
    peak = float(np.max(np.abs(audio)))
    if peak <= 1e-8:
        return audio
    return audio / peak


def _trim_silence(audio: np.ndarray) -> np.ndarray:
    if audio.size == 0:
        return audio
    trimmed, _ = librosa.effects.trim(audio, top_db=TRIM_TOP_DB)
    return trimmed


def _simple_noise_gate(audio: np.ndarray) -> np.ndarray:
    if audio.size == 0:
        return audio
    threshold = max(0.02 * float(np.max(np.abs(audio))), 1e-4)
    gated = np.copy(audio)
    gated[np.abs(gated) < threshold] = 0.0
    return gated


def _is_valid_audio_signal(audio: np.ndarray) -> bool:
    if audio.size == 0:
        return False
    if not np.all(np.isfinite(audio)):
        return False
    # Reject near-silent recordings where model embeddings become unstable.
    rms = float(np.sqrt(np.mean(np.square(audio), dtype=np.float64)))
    return rms >= 0.002


def preprocess_audio_file(file_path: str) -> Tuple[np.ndarray, int]:
    audio, sr = librosa.load(file_path, sr=TARGET_SR, mono=True)
    if audio.size == 0:
        raise ValueError("Audio file is empty.")

    audio = np.asarray(audio, dtype=np.float32)
    audio = audio - float(np.mean(audio, dtype=np.float64))

    audio = _trim_silence(audio)
    audio = _normalize_audio(audio)
    audio = _simple_noise_gate(audio)

    if not _is_valid_audio_signal(audio):
        raise ValueError(
            "Audio quality is too low or mostly silent. Please re-record in a quieter place."
        )

    duration = float(len(audio)) / float(sr)
    if duration < MIN_DURATION_SECONDS:
        raise ValueError(
            f"Audio is too short ({duration:.2f}s). Please record at least {MIN_DURATION_SECONDS:.1f}s."
        )

    max_samples = int(MAX_DURATION_SECONDS * sr)
    if len(audio) > max_samples:
        audio = audio[:max_samples]

    return np.ascontiguousarray(audio.astype(np.float32)), sr


def _validate_upload(file_storage: FileStorage) -> None:
    if file_storage is None:
        raise ValueError("Audio file is missing.")

    filename = file_storage.filename or ""
    suffix = Path(filename).suffix.lower() if filename else ""
    if suffix and suffix not in SUPPORTED_AUDIO_SUFFIXES:
        raise ValueError(
            f"Unsupported audio format '{suffix}'. Use one of: {', '.join(sorted(SUPPORTED_AUDIO_SUFFIXES))}."
        )

    stream = file_storage.stream
    current_pos = stream.tell()
    stream.seek(0, os.SEEK_END)
    size_bytes = stream.tell()
    stream.seek(current_pos)

    max_size = MAX_UPLOAD_SIZE_MB * 1024 * 1024
    if size_bytes > max_size:
        raise ValueError(
            f"Audio file is too large ({size_bytes / (1024 * 1024):.2f} MB). Max allowed is {MAX_UPLOAD_SIZE_MB} MB."
        )


def save_upload_to_temp(file_storage: FileStorage) -> str:
    _validate_upload(file_storage)

    file_storage.stream.seek(0)
    suffix = Path(file_storage.filename or "audio.wav").suffix.lower() or ".wav"
    temp_file = tempfile.NamedTemporaryFile(delete=False, suffix=suffix)
    temp_file.close()
    file_storage.save(temp_file.name)
    return temp_file.name


def cleanup_temp_file(file_path: str) -> None:
    try:
        if os.path.exists(file_path):
            os.remove(file_path)
    except OSError:
        pass
