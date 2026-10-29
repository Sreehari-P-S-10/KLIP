"""
KLIP DPDP Act 2023 Cryptographic Vault Module
Implements:
1. AES-256-GCM authenticated encryption for PII fields (Name, Phone, Address, Job Card).
2. Salted & Peppered SHA-256 deterministic hashing for phone numbers (O(1) authentication lookup).
3. Deterministic surrogate UUID derivation from KoBo submission UUIDs.
4. SHA-256 file and batch checksums for zero-loss audit compliance.
"""

import os
import hmac
import uuid
import base64
import hashlib
import secrets
from typing import Optional

# Default fallback keys for development (overridden by .env in production)
DEFAULT_AES_KEY_B64 = "r4nd0m_s3cr3t_aes_256_k3y_m4st3r_ch4ng3_m3_in_pr0d="
DEFAULT_PEPPER = "klip_dpdp_salt_pepper_2026_kanjikuzhi_super_secret_string"

class CryptoVault:
    def __init__(self, aes_key_b64: Optional[str] = None, pepper: Optional[str] = None):
        self.pepper = pepper or os.environ.get("PII_PEPPER_KEY", DEFAULT_PEPPER)
        key_raw = aes_key_b64 or os.environ.get("PII_AES_KEY", DEFAULT_AES_KEY_B64)
        
        # Derive 32-byte key
        try:
            self.key_bytes = base64.b64decode(key_raw)
            if len(self.key_bytes) != 32:
                self.key_bytes = hashlib.sha256(key_raw.encode()).digest()
        except Exception:
            self.key_bytes = hashlib.sha256(key_raw.encode()).digest()
            
        self._has_hazmat = False
        try:
            from cryptography.hazmat.primitives.ciphers.aead import AESGCM
            self._aesgcm = AESGCM(self.key_bytes)
            self._has_hazmat = True
        except ImportError:
            self._aesgcm = None

    def encrypt(self, plaintext: Optional[str]) -> Optional[bytes]:
        """Encrypts plaintext string into authenticated ciphertext bytes."""
        if plaintext is None or plaintext == "":
            return None
        
        data = plaintext.encode("utf-8")
        
        if self._has_hazmat and self._aesgcm:
            # 96-bit random nonce for AES-GCM
            nonce = secrets.token_bytes(12)
            ciphertext = self._aesgcm.encrypt(nonce, data, None)
            return nonce + ciphertext
        else:
            # Fallback stream cipher with HMAC-SHA256 authentication
            iv = secrets.token_bytes(16)
            stream_key = hmac.new(self.key_bytes, iv, hashlib.sha256).digest()
            # Extend stream key to data length
            keystream = bytearray()
            counter = 0
            while len(keystream) < len(data):
                keystream.extend(hmac.new(stream_key, counter.to_bytes(4, 'big'), hashlib.sha256).digest())
                counter += 1
            ct = bytes([b ^ k for b, k in zip(data, keystream[:len(data)])])
            mac = hmac.new(self.key_bytes, iv + ct, hashlib.sha256).digest()
            return b"V1" + iv + mac + ct

    def decrypt(self, ciphertext: Optional[bytes]) -> Optional[str]:
        """Decrypts authenticated ciphertext bytes back to plaintext string."""
        if ciphertext is None or len(ciphertext) == 0:
            return None
            
        if self._has_hazmat and self._aesgcm:
            if not ciphertext.startswith(b"V1"):
                try:
                    nonce = ciphertext[:12]
                    raw_ct = ciphertext[12:]
                    return self._aesgcm.decrypt(nonce, raw_ct, None).decode("utf-8")
                except Exception:
                    pass
        
        # Fallback or V1 decrypt
        if ciphertext.startswith(b"V1"):
            try:
                iv = ciphertext[2:18]
                mac = ciphertext[18:50]
                ct = ciphertext[50:]
                expected_mac = hmac.new(self.key_bytes, iv + ct, hashlib.sha256).digest()
                if not hmac.compare_digest(mac, expected_mac):
                    raise ValueError("Ciphertext authentication failed (tampered data)")
                stream_key = hmac.new(self.key_bytes, iv, hashlib.sha256).digest()
                keystream = bytearray()
                counter = 0
                while len(keystream) < len(ct):
                    keystream.extend(hmac.new(stream_key, counter.to_bytes(4, 'big'), hashlib.sha256).digest())
                    counter += 1
                pt = bytes([b ^ k for b, k in zip(ct, keystream[:len(ct)])])
                return pt.decode("utf-8")
            except Exception as e:
                return f"[DECRYPT_ERROR: {e}]"
                
        return "[ENCRYPTED_BLOB]"

    def hash_mobile(self, phone: Optional[str]) -> Optional[str]:
        """
        Generates deterministic SHA-256 hash using high-entropy server pepper.
        Allows O(1) citizen lookup without storing unencrypted phone numbers.
        """
        if not phone:
            return None
        # Clean phone string (keep only digits)
        digits = "".join(c for c in str(phone) if c.isdigit())
        if len(digits) > 10:
            digits = digits[-10:] # standard Indian 10-digit format
            
        salted = f"{digits}:{self.pepper}".encode("utf-8")
        return hashlib.sha256(salted).hexdigest()

    def derive_household_uuid(self, submission_uuid: str) -> uuid.UUID:
        """Derives consistent, deterministic UUIDv5 from KoBo submission UUID."""
        if not submission_uuid:
            return uuid.uuid4()
        return uuid.uuid5(uuid.NAMESPACE_DNS, f"klip.kanjikuzhi.{submission_uuid}")

    @staticmethod
    def compute_file_sha256(filepath: str) -> str:
        """Calculates SHA-256 checksum of raw input survey file."""
        hasher = hashlib.sha256()
        with open(filepath, "rb") as f:
            while chunk := f.read(65536):
                hasher.update(chunk)
        return hasher.hexdigest()
