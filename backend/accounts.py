"""Account lifecycle endpoints; callers provide an authenticated transaction."""
import hashlib
import hmac
import secrets


def password_hash(password, salt):
    return hashlib.scrypt(password.encode(), salt=salt, n=2**14, r=8, p=1, dklen=32)


def valid_password(password):
    return isinstance(password, str) and 12 <= len(password) <= 1024


def manage(db, user_id, action, data):
    password = data.get('password')
    if not valid_password(password):
        return 400, {'error': 'invalid_password'}
    db.execute('BEGIN IMMEDIATE')
    row = db.execute('SELECT * FROM users WHERE id=?', (user_id,)).fetchone()
    if not hmac.compare_digest(password_hash(password, row['salt']), row['password_hash']):
        return 401, {'error': 'invalid_credentials'}
    if action == 'recovery-code':
        code = secrets.token_hex(24)
        db.execute('INSERT INTO recovery_codes(user_id,code_hash) VALUES(?,?) ON CONFLICT(user_id) DO UPDATE SET code_hash=excluded.code_hash',
                   (user_id, hashlib.sha256(code.encode()).digest()))
        return 200, {'recoveryCode': code}
    if action == 'password':
        new = data.get('newPassword')
        if not valid_password(new):
            return 400, {'error': 'password_length_must_be_12_to_1024'}
        salt = secrets.token_bytes(16)
        db.execute('UPDATE users SET salt=?,password_hash=? WHERE id=?', (salt, password_hash(new, salt), user_id))
        db.execute('DELETE FROM sessions WHERE user_id=?', (user_id,))
        db.execute('DELETE FROM recovery_codes WHERE user_id=?', (user_id,))
        return 200, {'ok': True}
    if action == 'delete':
        db.execute('DELETE FROM groups WHERE owner_id=?', (user_id,))
        db.execute('DELETE FROM users WHERE id=?', (user_id,))
        return 200, {'ok': True}
    return 404, {'error': 'not_found'}


def recover(db, data):
    email, code, password = data.get('email'), data.get('recoveryCode'), data.get('newPassword')
    if not isinstance(email, str) or not isinstance(code, str) or len(code) != 48 or not valid_password(password):
        return 400, {'error': 'invalid_recovery_request'}
    db.execute('BEGIN IMMEDIATE')
    row = db.execute('SELECT u.id,r.code_hash FROM users u JOIN recovery_codes r ON r.user_id=u.id WHERE u.email=?', (email.casefold(),)).fetchone()
    if row is None or not hmac.compare_digest(hashlib.sha256(code.encode()).digest(), row['code_hash']):
        return 400, {'error': 'invalid_recovery_code'}
    salt = secrets.token_bytes(16)
    db.execute('UPDATE users SET salt=?,password_hash=? WHERE id=?', (salt, password_hash(password, salt), row['id']))
    db.execute('DELETE FROM sessions WHERE user_id=?', (row['id'],))
    db.execute('DELETE FROM recovery_codes WHERE user_id=?', (row['id'],))
    return 200, {'ok': True}
