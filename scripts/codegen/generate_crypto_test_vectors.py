#!/usr/bin/env python3
"""Generates known-answer test vectors for Submersion's SBE1 crypto.

Output: test/fixtures/crypto/crypto_vectors.json
All values are base64 unless noted. Deterministic (fixed inputs).
"""
import base64
import gzip
import json
import uuid

from argon2.low_level import Type, hash_secret_raw
from cryptography.hazmat.primitives.ciphers.aead import AESGCM
from cryptography.hazmat.primitives.kdf.hkdf import HKDF
from cryptography.hazmat.primitives import hashes


def b64(b: bytes) -> str:
    return base64.b64encode(b).decode()


KEY = bytes(range(32))                      # 000102...1f
NONCE = bytes(range(12))                    # 000102...0b
KEY_ID = uuid.UUID("8f14e45f-ceea-467f-ab37-a10a8d5f4c11")
FILENAME = "ssv1.devA.cs.00042.json"
PLAINTEXT = b'{"hello":"submersion","n":42}'

# --- raw AES-256-GCM ---
gcm = AESGCM(KEY)
ct = gcm.encrypt(NONCE, PLAINTEXT, FILENAME.encode())  # ct||tag

# --- HKDF-SHA256 (data key derivation) ---
hkdf_out = HKDF(algorithm=hashes.SHA256(), length=32, salt=None,
                info=b"sbe:v1:data").derive(KEY)

# --- Argon2id (KDF for keyslots) --- small params so tests stay fast
ARGON_SALT = bytes(range(16))
argon_out = hash_secret_raw(
    secret=b"correct horse battery staple", salt=ARGON_SALT,
    time_cost=3, memory_cost=1024, parallelism=1, hash_len=32,
    type=Type.ID)

# --- full SBE1 single-shot envelope (gzip off), built byte-for-byte ---
header = b"SBE1" + KEY_ID.bytes + bytes([0]) + NONCE
env_plain = header + ct

# --- full SBE1 single-shot envelope (gzip on) ---
gz = gzip.compress(PLAINTEXT, mtime=0)
ct_gz = AESGCM(KEY).encrypt(NONCE, gz, FILENAME.encode())
env_gzip = b"SBE1" + KEY_ID.bytes + bytes([1]) + NONCE + ct_gz

vectors = {
    "aesGcm": {"key": b64(KEY), "nonce": b64(NONCE),
               "aad": FILENAME, "plaintext": b64(PLAINTEXT),
               "ciphertextWithTag": b64(ct)},
    "hkdfData": {"ikm": b64(KEY), "info": "sbe:v1:data",
                 "output": b64(hkdf_out)},
    "argon2id": {"password": "correct horse battery staple",
                 "salt": b64(ARGON_SALT), "m": 1024, "t": 3, "p": 1,
                 "output": b64(argon_out)},
    "envelopePlain": {"key": b64(KEY), "keyId": str(KEY_ID),
                      "filename": FILENAME, "plaintext": b64(PLAINTEXT),
                      "envelope": b64(env_plain)},
    "envelopeGzip": {"key": b64(KEY), "keyId": str(KEY_ID),
                     "filename": FILENAME, "plaintext": b64(PLAINTEXT),
                     "envelope": b64(env_gzip)},
}
with open("test/fixtures/crypto/crypto_vectors.json", "w") as f:
    json.dump(vectors, f, indent=2)
print("wrote test/fixtures/crypto/crypto_vectors.json")
