"""Periodic backup worker. Mount /backups on durable, separately replicated storage."""
import logging
import os
import time
from datetime import datetime, timezone
from pathlib import Path
from backend.backup import backup


def run():
    logging.basicConfig(level=logging.INFO)
    source = Path(os.environ.get('TASKHUB_DB', '/data/taskhub.sqlite3'))
    destination = Path(os.environ.get('TASKHUB_BACKUPS', '/backups'))
    while True:
        try:
            filename = datetime.now(timezone.utc).strftime('taskhub-%Y%m%dT%H%M%SZ.sqlite3')
            backup(source, destination / filename)
            (destination / 'last-success').write_text(str(int(time.time())))
            # Retention runs only after a verified new snapshot exists.
            for old in sorted(destination.glob('taskhub-*.sqlite3'))[:-30]:
                old.unlink()
            logging.info('Backup completed: %s', filename)
            delay = 86400
        except Exception:
            logging.exception('Backup failed; retrying in five minutes')
            delay = 300
        time.sleep(delay)


if __name__ == '__main__':
    run()
