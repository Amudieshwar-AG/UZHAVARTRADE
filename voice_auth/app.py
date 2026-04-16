from __future__ import annotations

import os
import random
from typing import Any

from flask import Flask, request
from flask_cors import CORS
from psycopg2 import IntegrityError

import models
from audio_processing import cleanup_temp_file, save_upload_to_temp
from voice_auth import (
    average_embeddings,
    extract_voice_embedding,
    find_best_voice_match,
    transcribe_audio,
)

VOICE_MATCH_THRESHOLD = float(os.getenv("VOICE_MATCH_THRESHOLD", "0.75"))
MIN_REGISTER_SAMPLES = 2
MAX_REGISTER_SAMPLES = 3

app = Flask(__name__)
CORS(app)
models.init_db()


def _error_response(message: str, status_code: int = 400) -> tuple[dict[str, Any], int]:
    return {"success": False, "message": message}, status_code


def _normalize_phone(phone: str) -> str:
    return "".join(ch for ch in phone if ch.isdigit())


def _collect_registration_audio_files() -> list[Any]:
    files = request.files.getlist("audio_files")
    if not files:
        single_audio = request.files.get("audio")
        if single_audio:
            files = [single_audio]
    return files


@app.get("/health")
def health() -> tuple[dict[str, Any], int]:
    return {"success": True, "message": "Voice auth service is running"}, 200


@app.post("/register")
def register() -> tuple[dict[str, Any], int]:
    name = (request.form.get("name") or "").strip()
    phone = _normalize_phone((request.form.get("phone") or "").strip())

    if not name or not phone:
        return _error_response("Both name and phone are required.", 400)
    if len(phone) < 8:
        return _error_response("Phone number looks invalid. Please provide at least 8 digits.", 400)

    files = _collect_registration_audio_files()

    if len(files) < MIN_REGISTER_SAMPLES or len(files) > MAX_REGISTER_SAMPLES:
        return _error_response(
            f"Please upload {MIN_REGISTER_SAMPLES} or {MAX_REGISTER_SAMPLES} audio samples for registration.",
            400,
        )

    embeddings = []
    transcriptions = []

    try:
        for uploaded_file in files:
            temp_path = save_upload_to_temp(uploaded_file)
            try:
                transcribed = transcribe_audio(temp_path, language="ta")
                if transcribed:
                    transcriptions.append(transcribed)

                embedding = extract_voice_embedding(temp_path)
                embeddings.append(embedding)
            finally:
                cleanup_temp_file(temp_path)

        avg_embedding = average_embeddings(embeddings)
        seller_id = models.add_seller(name=name, phone=phone, embedding=avg_embedding)

        return (
            {
                "success": True,
                "message": "Registration successful. Voice profile saved.",
                "seller": {
                    "id": seller_id,
                    "name": name,
                    "phone": phone,
                },
                "sample_count": len(embeddings),
                "transcription_preview": transcriptions,
            },
            201,
        )

    except ValueError as exc:
        return _error_response(str(exc), 400)
    except IntegrityError:
        return _error_response("A seller with this phone already exists.", 409)
    except Exception as exc:
        return _error_response(f"Registration failed: {exc}", 500)


@app.post("/login")
def login() -> tuple[dict[str, Any], int]:
    uploaded_audio = request.files.get("audio")
    phone_hint = _normalize_phone((request.form.get("phone") or "").strip()) or None

    if uploaded_audio is None:
        return _error_response("Audio file is required for login.", 400)

    sellers = models.get_sellers_for_matching()
    if not sellers:
        return _error_response("No sellers registered yet.", 404)

    candidate_sellers = sellers
    if phone_hint:
        filtered = [seller for seller in sellers if seller["phone"] == phone_hint]
        if not filtered:
            return _error_response("No registered seller found for the provided phone.", 404)
        candidate_sellers = filtered

    temp_path = save_upload_to_temp(uploaded_audio)
    try:
        login_embedding = extract_voice_embedding(temp_path)
        transcription = transcribe_audio(temp_path, language="ta")
    except ValueError as exc:
        return _error_response(str(exc), 400)
    except Exception as exc:
        return _error_response(f"Could not process login audio: {exc}", 500)
    finally:
        cleanup_temp_file(temp_path)

    best_match, best_similarity = find_best_voice_match(login_embedding, candidate_sellers)

    if best_match is None:
        return _error_response("No voice profiles available for matching.", 404)

    confidence_score = round(best_similarity, 4)

    if best_similarity >= VOICE_MATCH_THRESHOLD:
        login_timestamp = models.mark_successful_login(best_match["id"])
        models.log_login_attempt(
            seller_id=best_match["id"],
            phone_input=phone_hint,
            similarity=best_similarity,
            success=True,
            used_otp=False,
        )

        return (
            {
                "success": True,
                "authenticated": True,
                "message": f"Welcome back, {best_match['name']}",
                "confidence_score": confidence_score,
                "threshold": VOICE_MATCH_THRESHOLD,
                "login_timestamp": login_timestamp,
                "transcription_preview": transcription,
                "seller": {
                    "id": best_match["id"],
                    "name": best_match["name"],
                    "phone": best_match["phone"],
                },
            },
            200,
        )

    otp_code = f"{random.randint(100000, 999999)}"
    models.log_login_attempt(
        seller_id=int(best_match["id"]),
        phone_input=phone_hint,
        similarity=best_similarity,
        success=False,
        used_otp=True,
    )

    return (
        {
            "success": False,
            "authenticated": False,
            "message": "Voice authentication failed. Use OTP fallback.",
            "confidence_score": confidence_score,
            "threshold": VOICE_MATCH_THRESHOLD,
            "otp_required": True,
            "otp_code": otp_code,
        },
        401,
    )


@app.get("/sellers")
def get_sellers() -> tuple[dict[str, Any], int]:
    sellers = models.list_sellers()
    return {"success": True, "count": len(sellers), "sellers": sellers}, 200


@app.get("/login-attempts")
def get_login_attempts() -> tuple[dict[str, Any], int]:
    raw_limit = (request.args.get("limit") or "20").strip()
    try:
        limit = int(raw_limit)
    except ValueError:
        return _error_response("Query parameter 'limit' must be an integer.", 400)

    if limit < 1 or limit > 200:
        return _error_response("Query parameter 'limit' must be between 1 and 200.", 400)

    attempts = models.list_login_attempts(limit=limit)
    return {"success": True, "count": len(attempts), "attempts": attempts}, 200


@app.route("/orders", methods=["POST"])
def create_order() -> tuple[dict[str, Any], int]:
    data = request.get_json() or {}
    product_name = data.get("product_name")
    quantity = data.get("quantity")
    total_price = data.get("total_price")
    seller_name = data.get("seller_name")
    seller_upi_id = data.get("seller_upi_id")

    if not product_name or not quantity or not total_price:
        return _error_response("Missing required order fields.", 400)

    conn = models.get_connection()
    try:
        with conn.cursor() as cursor:
            cursor.execute(
                """
                INSERT INTO orders (product_name, quantity, total_price, seller_name, seller_upi_id, status)
                VALUES (%s, %s, %s, %s, %s, 'முடிந்தது')
                RETURNING id
                """,
                (product_name, quantity, total_price, seller_name, seller_upi_id)
            )
            order_id = cursor.fetchone()["id"]
        conn.commit()
    finally:
        conn.close()

    return {"success": True, "order_id": order_id}, 201


@app.route("/orders", methods=["GET"])
def get_orders() -> tuple[dict[str, Any], int]:
    conn = models.get_connection()
    try:
        with conn.cursor() as cursor:
            cursor.execute("SELECT * FROM orders ORDER BY created_at DESC")
            records = cursor.fetchall()
            
            # format dates before returning
            for r in records:
                r["created_at"] = r["created_at"].isoformat()
            
            return {"success": True, "orders": records}, 200
    except Exception as e:
        return _error_response(str(e), 500)
    finally:
        conn.close()


@app.route("/orders/<int:order_id>/complete", methods=["PUT"])
def complete_order(order_id: int) -> tuple[dict[str, Any], int]:
    conn = models.get_connection()
    try:
        with conn.cursor() as cursor:
            cursor.execute(
                "UPDATE orders SET status = 'முடிந்தது' WHERE id = %s RETURNING id",
                (order_id,)
            )
            if cursor.fetchone() is None:
                return _error_response("Order not found.", 404)
        conn.commit()
        return {"success": True, "message": "Order completed"}, 200
    finally:
        conn.close()


if __name__ == "__main__":
    app.run(debug=True, host="0.0.0.0", port=5000)
