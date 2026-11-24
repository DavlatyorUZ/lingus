"""Validate and atomically publish Lingoy SQLite snapshots. Python standard library."""
from contextlib import closing
from datetime import datetime, timezone
from pathlib import Path
import os
import sqlite3
import sys
import tempfile
import uuid

REQUIRED = {
    "migrations": "version applied",
    "users": "id email name password google_sub picture revision",
    "challenges": "email purpose code name password expires sent attempts locked",
    "sessions": "id user_id family hash expires revoked",
    "oauth": "state binding nonce verifier ticket expires",
    "tickets": "id challenge user_id expires",
    "saved": "user_id word_id deleted revision",
    "mutations": "user_id id created",
    "usage": "user_id day n",
    "cache": "key value expires",
    "supplements": "id normalized lemma translation explanation source updated",
}


def reader(file):
    connection = sqlite3.connect(Path(file).resolve().as_uri() + "?mode=ro", uri=True, timeout=10)
    connection.execute("PRAGMA trusted_schema=OFF")
    connection.execute("PRAGMA query_only=ON")
    return connection


def validate(file):
    with closing(reader(file)) as connection:
        connection.execute("BEGIN")
        if connection.execute("PRAGMA integrity_check").fetchall() != [("ok",)]:
            raise ValueError("Baza yaxlitligi tekshiruvdan o‘tmadi.")
        if connection.execute("PRAGMA foreign_key_check").fetchone() is not None:
            raise ValueError("Bazada jadvallararo bog‘lanish buzilgan.")
        for table, columns in REQUIRED.items():
            # Both identifiers come exclusively from the fixed schema above.
            selected = ",".join('"' + name + '"' for name in columns.split())
            actual = {row[1] for row in connection.execute(f'PRAGMA table_info("{table}")')}
            if not set(columns.split()).issubset(actual):
                raise ValueError("Backup Lingoy bazasining to‘liq tuzilmasiga ega emas.")
            connection.execute(f'SELECT {selected} FROM "{table}" LIMIT 0')
        if connection.execute("SELECT max(version) FROM migrations").fetchone()[0] != 1:
            raise ValueError("Backup migratsiya versiyasi ushbu release bilan mos emas.")


def backup(base):
    base = Path(base).resolve()
    source = base / "shared/data/lingoy.sqlite"
    if not source.exists():
        print("Baza hali yaratilmagan.")
        return None
    destination = base / "shared/backups"
    destination.mkdir(parents=True, exist_ok=True, mode=0o700)
    stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S%fZ")
    output = destination / f"lingoy-{stamp}-{uuid.uuid4().hex[:8]}.sqlite"
    descriptor, filename = tempfile.mkstemp(prefix=".lingoy-", suffix=".part", dir=destination)
    os.close(descriptor)
    temporary = Path(filename)
    try:
        with closing(reader(source)) as src, closing(sqlite3.connect(temporary)) as dst:
            src.backup(dst)
        validate(temporary)
        temporary.chmod(0o600)
        with temporary.open("rb") as saved:
            os.fsync(saved.fileno())
        os.replace(temporary, output)
        directory = os.open(destination, os.O_RDONLY)
        try:
            os.fsync(directory)
        finally:
            os.close(directory)
        print("Backup tayyor:", output.name)
        return output
    finally:
        temporary.unlink(missing_ok=True)


def main():
    try:
        if len(sys.argv) != 3 or sys.argv[1] not in ["backup", "validate"]:
            raise ValueError("database_backup.py backup BASE yoki validate FILE")
        if sys.argv[1] == "backup":
            backup(sys.argv[2])
        else:
            validate(sys.argv[2])
    except (ValueError, OSError, sqlite3.Error):
        print("Baza tekshiruvdan o‘tmadi yoki faylga kirish imkoni yo‘q. Amaldagi bazani almashtirmang.", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
