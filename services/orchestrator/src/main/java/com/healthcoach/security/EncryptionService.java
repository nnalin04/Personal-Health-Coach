package com.healthcoach.security;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import javax.crypto.Cipher;
import javax.crypto.SecretKey;
import javax.crypto.spec.GCMParameterSpec;
import javax.crypto.spec.SecretKeySpec;
import java.security.SecureRandom;
import java.util.Base64;

/**
 * Application-level AES-256-GCM encryption for sensitive health data.
 *
 * Used to encrypt/decrypt medical report fields (raw_text_enc, lab_values_enc)
 * in compliance with DPDP Act 2023 requirements for health PII at rest.
 *
 * Key: {@code app.encryption.key} property — must be a Base64-encoded
 * 256-bit (32-byte) key. Generate with:
 *   openssl rand -base64 32
 *
 * Format on disk:  Base64( IV[12] || ciphertext || GCM-tag[16] )
 */
@Service
public class EncryptionService {

    private static final String ALGORITHM  = "AES/GCM/NoPadding";
    private static final int    IV_LEN     = 12;   // 96-bit IV recommended for GCM
    private static final int    TAG_LEN    = 128;  // 128-bit authentication tag

    private final SecretKey secretKey;
    private final boolean   enabled;

    public EncryptionService(@Value("${app.encryption.key:}") String keyB64) {
        if (keyB64 == null || keyB64.isBlank()) {
            this.secretKey = null;
            this.enabled   = false;
        } else {
            byte[] keyBytes = Base64.getDecoder().decode(keyB64.trim());
            this.secretKey  = new SecretKeySpec(keyBytes, "AES");
            this.enabled    = true;
        }
    }

    /**
     * Encrypt plaintext to a Base64-encoded ciphertext string.
     * Returns plaintext unchanged if encryption is not configured.
     */
    public String encrypt(String plaintext) {
        if (!enabled || plaintext == null) return plaintext;
        try {
            byte[] iv = new byte[IV_LEN];
            new SecureRandom().nextBytes(iv);

            Cipher cipher = Cipher.getInstance(ALGORITHM);
            cipher.init(Cipher.ENCRYPT_MODE, secretKey, new GCMParameterSpec(TAG_LEN, iv));
            byte[] ciphertext = cipher.doFinal(plaintext.getBytes("UTF-8"));

            // Prepend IV to ciphertext
            byte[] combined = new byte[IV_LEN + ciphertext.length];
            System.arraycopy(iv, 0, combined, 0, IV_LEN);
            System.arraycopy(ciphertext, 0, combined, IV_LEN, ciphertext.length);
            return Base64.getEncoder().encodeToString(combined);
        } catch (Exception e) {
            throw new RuntimeException("Encryption failed", e);
        }
    }

    /**
     * Decrypt a Base64-encoded ciphertext string.
     * Returns ciphertext unchanged if encryption is not configured.
     */
    public String decrypt(String ciphertext) {
        if (!enabled || ciphertext == null) return ciphertext;
        try {
            byte[] combined = Base64.getDecoder().decode(ciphertext);
            byte[] iv       = new byte[IV_LEN];
            byte[] data     = new byte[combined.length - IV_LEN];
            System.arraycopy(combined, 0,      iv,   0, IV_LEN);
            System.arraycopy(combined, IV_LEN, data, 0, data.length);

            Cipher cipher = Cipher.getInstance(ALGORITHM);
            cipher.init(Cipher.DECRYPT_MODE, secretKey, new GCMParameterSpec(TAG_LEN, iv));
            return new String(cipher.doFinal(data), "UTF-8");
        } catch (Exception e) {
            throw new RuntimeException("Decryption failed", e);
        }
    }

    /** True if an encryption key is configured. */
    public boolean isEnabled() {
        return enabled;
    }
}
