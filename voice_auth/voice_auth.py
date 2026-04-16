from __future__ import annotations

import os
from threading import Lock
from typing import Iterable

import numpy as np
import whisper
from resemblyzer import VoiceEncoder, preprocess_wav

from audio_processing import preprocess_audio_file

_WHISPER_MODEL_NAME = os.getenv("WHISPER_MODEL", "base")
_encoder: VoiceEncoder | None = None
_whisper_model = None
_encoder_lock = Lock()
_whisper_lock = Lock()
EMBEDDING_DTYPE = np.float32


def get_voice_encoder() -> VoiceEncoder:
    global _encoder
    if _encoder is None:
        with _encoder_lock:
            if _encoder is None:
                _encoder = VoiceEncoder()
    return _encoder


def get_whisper_model():
    global _whisper_model
    if _whisper_model is None:
        with _whisper_lock:
            if _whisper_model is None:
                _whisper_model = whisper.load_model(_WHISPER_MODEL_NAME)
    return _whisper_model


def transcribe_audio(file_path: str, language: str = "ta") -> str:
    # Whisper is optional validation; errors should not block voice registration/login.
    try:
        model = get_whisper_model()
        result = model.transcribe(file_path, language=language, fp16=False)
        return str(result.get("text", "")).strip()
    except Exception:
        return ""


def extract_voice_embedding(file_path: str) -> np.ndarray:
    audio, sr = preprocess_audio_file(file_path)
    wav = preprocess_wav(audio, source_sr=sr)
    if wav.size == 0:
        raise ValueError("Could not extract usable speech from audio.")

    encoder = get_voice_encoder()
    embedding = encoder.embed_utterance(wav)
    vector = np.asarray(embedding, dtype=EMBEDDING_DTYPE)
    if vector.ndim != 1 or vector.size == 0:
        raise ValueError("Generated embedding is invalid.")
    if not np.all(np.isfinite(vector)):
        raise ValueError("Generated embedding contains invalid values.")
    return vector


def average_embeddings(embeddings: Iterable[np.ndarray]) -> np.ndarray:
    vectors = [np.asarray(v, dtype=EMBEDDING_DTYPE) for v in embeddings]
    if not vectors:
        raise ValueError("No embeddings available to average.")

    expected_size = int(vectors[0].size)
    if expected_size == 0:
        raise ValueError("Embedding vectors are empty.")

    for vec in vectors:
        if vec.ndim != 1 or vec.size != expected_size:
            raise ValueError("Embedding vectors must have the same shape.")
        if not np.all(np.isfinite(vec)):
            raise ValueError("Embedding vectors contain invalid values.")

    stacked = np.vstack(vectors)
    return np.mean(stacked, axis=0).astype(EMBEDDING_DTYPE)


def cosine_similarity(vec_a: np.ndarray, vec_b: np.ndarray) -> float:
    a = np.asarray(vec_a, dtype=EMBEDDING_DTYPE)
    b = np.asarray(vec_b, dtype=EMBEDDING_DTYPE)

    if a.ndim != 1 or b.ndim != 1:
        raise ValueError("Cosine similarity expects 1D vectors.")
    if a.size != b.size:
        raise ValueError("Vectors must have the same length.")
    if not np.all(np.isfinite(a)) or not np.all(np.isfinite(b)):
        raise ValueError("Vectors contain invalid values.")

    denominator = float(np.linalg.norm(a) * np.linalg.norm(b))
    if denominator == 0.0:
        return 0.0
    score = float(np.dot(a, b) / denominator)
    return max(min(score, 1.0), -1.0)


def find_best_voice_match(
    probe_embedding: np.ndarray,
    candidates: Iterable[dict[str, object]],
) -> tuple[dict[str, object] | None, float]:
    best_match: dict[str, object] | None = None
    best_score = -1.0

    for candidate in candidates:
        embedding = candidate.get("embedding")
        if embedding is None:
            continue

        score = cosine_similarity(probe_embedding, np.asarray(embedding, dtype=EMBEDDING_DTYPE))
        if score > best_score:
            best_score = score
            best_match = candidate

    return best_match, best_score
