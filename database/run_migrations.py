"""
KLIP Modular Database Migration Runner
Applies SQL migrations in order and tracks applied files in public.schema_migrations.
Supports direct execution via psql CLI or Python PostgreSQL drivers.
"""

import os
import sys
import glob
import subprocess
from pathlib import Path

sys.stdout.reconfigure(encoding='utf-8')

BASE_DIR = Path(__file__).resolve().parent
MIGRATIONS_DIR = BASE_DIR / "migrations"
SEEDS_DIR = BASE_DIR / "seeds"

def load_env(env_path):
    env_vars = {}
    if os.path.exists(env_path):
        with open(env_path, "r", encoding="utf-8") as f:
            for line in f:
                line = line.strip()
                if line and not line.startswith("#") and "=" in line:
                    k, v = line.split("=", 1)
                    env_vars[k.strip()] = v.strip().strip('"').strip("'")
    return env_vars

def get_db_config():
    root_env = BASE_DIR.parent / ".env"
    example_env = BASE_DIR.parent / ".env.example"
    
    cfg = load_env(root_env) if root_env.exists() else load_env(example_env)
    
    host = os.environ.get("POSTGRES_HOST", cfg.get("POSTGRES_HOST", "localhost"))
    port = os.environ.get("POSTGRES_PORT", cfg.get("POSTGRES_PORT", "5432"))
    user = os.environ.get("POSTGRES_USER", cfg.get("POSTGRES_USER", "postgres"))
    password = os.environ.get("POSTGRES_PASSWORD", cfg.get("POSTGRES_PASSWORD", "postgres"))
    dbname = os.environ.get("POSTGRES_DB", cfg.get("POSTGRES_DB", "klip_db"))
    
    return {
        "host": host,
        "port": port,
        "user": user,
        "password": password,
        "dbname": dbname
    }

def run_psql_file(filepath, config):
    env = os.environ.copy()
    if config.get("password"):
        env["PGPASSWORD"] = config["password"]
    
    cmd = [
        "psql",
        "-h", config["host"],
        "-p", str(config["port"]),
        "-U", config["user"],
        "-d", config["dbname"],
        "-v", "ON_ERROR_STOP=1",
        "-f", str(filepath)
    ]
    
    result = subprocess.run(cmd, env=env, capture_output=True, text=True, encoding="utf-8")
    return result.returncode == 0, result.stdout, result.stderr

def run_psql_command(sql_command, config):
    env = os.environ.copy()
    if config.get("password"):
        env["PGPASSWORD"] = config["password"]
        
    cmd = [
        "psql",
        "-h", config["host"],
        "-p", str(config["port"]),
        "-U", config["user"],
        "-d", config["dbname"],
        "-t", "-A",
        "-c", sql_command
    ]
    
    result = subprocess.run(cmd, env=env, capture_output=True, text=True, encoding="utf-8")
    return result.returncode == 0, result.stdout.strip(), result.stderr

def ensure_database_exists(config):
    # Connect to default 'postgres' database to check/create target db
    temp_cfg = config.copy()
    temp_cfg["dbname"] = "postgres"
    
    check_sql = f"SELECT 1 FROM pg_database WHERE datname = '{config['dbname']}';"
    ok, stdout, stderr = run_psql_command(check_sql, temp_cfg)
    
    if ok and stdout == "1":
        print(f"[OK] Database '{config['dbname']}' already exists.")
        return True
    elif ok:
        print(f"[INFO] Creating database '{config['dbname']}'...")
        create_sql = f"CREATE DATABASE \"{config['dbname']}\";"
        cok, cstdout, cstderr = run_psql_command(create_sql, temp_cfg)
        if cok:
            print(f"[SUCCESS] Database '{config['dbname']}' created successfully.")
            return True
        else:
            print(f"[ERROR] Failed to create database: {cstderr}")
            return False
    else:
        print(f"[WARNING] Could not verify database existence: {stderr}")
        return False

def ensure_migration_table(config):
    sql = """
    CREATE TABLE IF NOT EXISTS public.schema_migrations (
        migration_file VARCHAR(255) PRIMARY KEY,
        applied_at TIMESTAMPTZ DEFAULT NOW()
    );
    """
    ok, out, err = run_psql_command(sql, config)
    return ok

def get_applied_migrations(config):
    sql = "SELECT migration_file FROM public.schema_migrations ORDER BY migration_file;"
    ok, out, err = run_psql_command(sql, config)
    if ok and out:
        return set(out.splitlines())
    return set()

def record_migration(filename, config):
    sql = f"INSERT INTO public.schema_migrations (migration_file) VALUES ('{filename}') ON CONFLICT DO NOTHING;"
    run_psql_command(sql, config)

def execute_migrations(apply_seeds=True):
    config = get_db_config()
    print("=" * 65)
    print("KLIP DATABASE MIGRATION SYSTEM")
    print(f"Target Host: {config['host']}:{config['port']} | DB: {config['dbname']} | User: {config['user']}")
    print("=" * 65)
    
    # 1. Check / Create Database
    if not ensure_database_exists(config):
        print("[NOTICE] Proceeding with migration against target database...")
    
    # 2. Check / Create Tracking Table
    if not ensure_migration_table(config):
        print(f"[ERROR] Unable to connect to database '{config['dbname']}'. Check credentials.")
        return False
        
    applied = get_applied_migrations(config)
    print(f"[INFO] Found {len(applied)} previously applied migrations.")
    
    # 3. Discover and Sort Migration Files
    migration_files = sorted(MIGRATIONS_DIR.glob("*.sql"))
    if not migration_files:
        print("[WARN] No SQL migration files found in database/migrations/")
        return True
        
    for mpath in migration_files:
        fname = mpath.name
        if fname in applied:
            print(f"  [SKIPPED] {fname} (already applied)")
            continue
            
        print(f"\n  [APPLYING] {fname}...")
        ok, stdout, stderr = run_psql_file(mpath, config)
        if not ok:
            print(f"\n[ERROR] Migration '{fname}' failed:")
            print(stderr)
            return False
        
        record_migration(fname, config)
        print(f"  [SUCCESS] {fname} applied successfully.")
        
    # 4. Apply Seeds if requested
    if apply_seeds and SEEDS_DIR.exists():
        seed_files = sorted(SEEDS_DIR.glob("*.sql"))
        print("\n" + "-" * 65)
        print("APPLYING REFERENCE SEEDS (Panchayat, Wards, Codelists)")
        print("-" * 65)
        for spath in seed_files:
            sname = spath.name
            print(f"  [SEEDING] {sname}...")
            ok, stdout, stderr = run_psql_file(spath, config)
            if not ok:
                print(f"  [ERROR] Seed '{sname}' failed: {stderr}")
            else:
                print(f"  [SUCCESS] Seed '{sname}' completed.")
                
    print("\n" + "=" * 65)
    print("[COMPLETED] All database migrations and seed scripts finished.")
    print("=" * 65)
    return True

if __name__ == "__main__":
    import argparse
    parser = argparse.ArgumentParser(description="Run KLIP PostgreSQL Migrations")
    parser.add_argument("--no-seeds", action="store_true", help="Skip running seed SQL files")
    args = parser.parse_args()
    
    execute_migrations(apply_seeds=not args.no_seeds)
