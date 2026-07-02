-- E2E Encrypted Backup: add encrypted_blob and backup_salt columns to user_data
-- The server stores only an opaque AES-256-GCM blob and a non-secret PBKDF2 salt.
-- The key is derived client-side from a 12-word recovery phrase (zero-knowledge).

ALTER TABLE user_data
  ADD COLUMN IF NOT EXISTS encrypted_blob TEXT,
  ADD COLUMN IF NOT EXISTS backup_salt TEXT;

COMMENT ON COLUMN user_data.encrypted_blob IS 'AES-256-GCM encrypted blob (nonce || ciphertext || mac), base64-encoded. Server cannot decrypt.';
COMMENT ON COLUMN user_data.backup_salt IS 'PBKDF2 salt (non-secret), base64-encoded. Used with recovery phrase to derive decryption key.';
