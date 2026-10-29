import sqlite3
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch
from backend.app import initialize, auth_allowed
from backend.backup import backup


class OperationsTest(unittest.TestCase):
    def test_migration_is_repeatable_and_backup_restores_data(self):
        with tempfile.TemporaryDirectory() as root:
            path = Path(root) / 'source.sqlite3'
            initialize(path)
            with sqlite3.connect(path) as db:
                db.execute("INSERT INTO users VALUES(1,'user@example.com',X'00',X'00',0)")
                db.execute('PRAGMA user_version=0')
            initialize(path)
            initialize(path)
            target = Path(root) / 'backup.sqlite3'
            backup(path, target)
            with sqlite3.connect(target) as db:
                self.assertEqual(db.execute('PRAGMA integrity_check').fetchone()[0], 'ok')
                self.assertEqual(db.execute('PRAGMA user_version').fetchone()[0], 1)
                self.assertEqual(db.execute('SELECT email FROM users').fetchone()[0], 'user@example.com')
            with self.assertRaises(ValueError):
                backup(path, path)

    def test_rate_limit_persists_and_expires(self):
        with tempfile.TemporaryDirectory() as root:
            path = Path(root) / 'db.sqlite3'
            initialize(path)
            with patch('backend.app.time.time', return_value=1000):
                for _ in range(20):
                    self.assertTrue(auth_allowed(path, 'client'))
                initialize(path)
                self.assertFalse(auth_allowed(path, 'client'))
                self.assertTrue(auth_allowed(path, 'other'))
            with patch('backend.app.time.time', return_value=1900):
                self.assertTrue(auth_allowed(path, 'client'))

    def test_future_schema_is_rejected(self):
        with tempfile.TemporaryDirectory() as root:
            path = Path(root) / 'db.sqlite3'
            with sqlite3.connect(path) as db:
                db.execute('PRAGMA user_version=2')
            with self.assertRaises(RuntimeError):
                initialize(path)
