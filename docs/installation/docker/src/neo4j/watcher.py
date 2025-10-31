#!/usr/bin/env python3
"""
Auto-executes .cypher files dropped into /updates folder
Moves processed files to /processed folder
"""
import os
import sys
import time
import subprocess
from pathlib import Path
from datetime import datetime

WATCH_DIR = Path("/updates")
PROCESSED_DIR = Path("/updates/processed")
NEO4J_URI = os.getenv("NEO4J_URI", "bolt://neo4j:7687")
NEO4J_USER = os.getenv("NEO4J_USER", "neo4j")
NEO4J_PASSWORD = os.getenv("NEO4J_PASSWORD")
CHECK_INTERVAL = 5  # seconds

# Ensure processed directory exists
PROCESSED_DIR.mkdir(exist_ok=True)

print("=" * 60)
print("Neo4j Update Watcher Started")
print("=" * 60)
print(f"Watching: {WATCH_DIR}")
print(f"Processed files moved to: {PROCESSED_DIR}")
print(f"Check interval: {CHECK_INTERVAL} seconds")
print("Drop .cypher files to auto-execute them!")
print("=" * 60)
print()

# Install neo4j driver
print("Installing neo4j driver...")
subprocess.run(["pip", "install", "-q", "neo4j"], check=True)
print()

from neo4j import GraphDatabase

def check_neo4j_connection():
    """Check if Neo4j is reachable"""
    try:
        # Handle SSL connections with self-signed certificates
        if NEO4J_URI.startswith("bolt+s://"):
            # For self-signed certificates, use +ssc scheme or configure trust
            ssl_uri = NEO4J_URI.replace("bolt+s://", "bolt+ssc://")
            driver = GraphDatabase.driver(ssl_uri, auth=(NEO4J_USER, NEO4J_PASSWORD))
        else:
            driver = GraphDatabase.driver(NEO4J_URI, auth=(NEO4J_USER, NEO4J_PASSWORD))
        
        with driver.session() as session:
            session.run("RETURN 1")
        driver.close()
        return True
    except Exception as e:
        print(f"[{datetime.now()}] Neo4j connection check failed: {e}")
        return False

def run_cypher_file(file_path):
    """Execute a cypher file against Neo4j"""
    print(f"[{datetime.now()}] Processing: {file_path.name}")
    
    try:
        # Check connection first
        if not check_neo4j_connection():
            print(f"  ✗ Cannot connect to Neo4j. Will retry later.")
            return False
        
        with open(file_path, 'r', encoding='utf-8') as f:
            cypher_script = f.read()
        
        # Connect and run with SSL handling
        if NEO4J_URI.startswith("bolt+s://"):
            # For self-signed certificates, use +ssc scheme
            ssl_uri = NEO4J_URI.replace("bolt+s://", "bolt+ssc://")
            driver = GraphDatabase.driver(ssl_uri, auth=(NEO4J_USER, NEO4J_PASSWORD))
        else:
            driver = GraphDatabase.driver(NEO4J_URI, auth=(NEO4J_USER, NEO4J_PASSWORD))
        
        with driver.session() as session:
            # Split by semicolon and run each statement
            statements = [s.strip() for s in cypher_script.split(';') if s.strip()]
            
            for i, statement in enumerate(statements, 1):
                if statement:
                    print(f"  Executing statement {i}/{len(statements)}...")
                    session.run(statement)
        
        driver.close()
        
        print(f"  ✓ Success!")
        
        # Move to processed folder with timestamp
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        new_name = f"{timestamp}_{file_path.name}"
        new_path = PROCESSED_DIR / new_name
        file_path.rename(new_path)
        print(f"  → Moved to: processed/{new_name}")
        print()
        
        return True
        
    except Exception as e:
        print(f"  ✗ Error: {e}")
        # Move to processed with ERROR prefix
        error_name = f"ERROR_{datetime.now().strftime('%Y%m%d_%H%M%S')}_{file_path.name}"
        try:
            file_path.rename(PROCESSED_DIR / error_name)
            print(f"  → Moved to: processed/{error_name}")
        except Exception as move_error:
            print(f"  ✗ Could not move file: {move_error}")
        print()
        return False

def watch_folder():
    """Watch folder for new .cypher files"""
    processed_files = set()
    heartbeat_counter = 0
    
    print(f"[{datetime.now()}] Watcher loop started. Watching for .cypher files...")
    print()
    
    while True:
        try:
            # Heartbeat every 60 iterations (5 minutes at 5 second intervals)
            heartbeat_counter += 1
            if heartbeat_counter >= 60:
                print(f"[{datetime.now()}] Watcher alive - heartbeat")
                sys.stdout.flush()
                heartbeat_counter = 0
            
            # Find all .cypher files
            cypher_files = sorted(WATCH_DIR.glob("*.cypher"))
            
            for file_path in cypher_files:
                if file_path.name not in processed_files:
                    run_cypher_file(file_path)
                    processed_files.add(file_path.name)
            
            time.sleep(CHECK_INTERVAL)
            
        except KeyboardInterrupt:
            print("\nWatcher stopped by user.")
            break
        except Exception as e:
            print(f"[{datetime.now()}] Watcher error: {e}")
            print("Continuing to watch...")
            sys.stdout.flush()
            time.sleep(10)

if __name__ == "__main__":
    # Wait for Neo4j to be ready
    print("Waiting for Neo4j to be ready...")
    print(f"Using connection URI: {NEO4J_URI}")
    max_retries = 30
    for i in range(max_retries):
        try:
            # Handle SSL connections with self-signed certificates
            if NEO4J_URI.startswith("bolt+s://"):
                # For self-signed certificates, use +ssc scheme
                ssl_uri = NEO4J_URI.replace("bolt+s://", "bolt+ssc://")
                driver = GraphDatabase.driver(ssl_uri, auth=(NEO4J_USER, NEO4J_PASSWORD))
                print(f"Using SSL connection with self-signed certificate support: {ssl_uri}")
            else:
                driver = GraphDatabase.driver(NEO4J_URI, auth=(NEO4J_USER, NEO4J_PASSWORD))
            
            with driver.session() as session:
                session.run("RETURN 1")
            driver.close()
            print("Neo4j is ready!")
            print()
            break
        except Exception as e:
            if i < max_retries - 1:
                print(f"  Waiting... ({i+1}/{max_retries}) - {str(e)[:100]}")
                time.sleep(2)
            else:
                print(f"Could not connect to Neo4j after {max_retries} attempts: {e}")
                print("Exiting.")
                sys.exit(1)
    
    # Start watching
    try:
        watch_folder()
    except Exception as e:
        print(f"Fatal error: {e}")
        sys.exit(1)
