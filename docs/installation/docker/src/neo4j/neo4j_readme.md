# Neo4j Graph Database Setup

## Overview

This Docker Compose setup runs Neo4j Community Edition on a single Windows machine. 
Drop `.cypher` files into a folder and they automatically execute - **zero manual steps required**.

---

## Architecture

```
┌─────────────────────────────────────────────────┐
│              Neo4j Browser UI                   │
│           (Web Interface - Port 7474)           │
└─────────────────┬───────────────────────────────┘
                  │
┌─────────────────▼───────────────────────────────┐
│              Neo4j Database                     │
│           (Graph DB - Port 7687)                │
└─────────────────┬───────────────────────────────┘
                  │
┌─────────────────▼───────────────────────────────┐
│           Update Watcher Service                │
│   (Monitors /updates folder every 10 seconds)   │
│   Auto-runs new .cypher files → moves to        │
│   /processed with timestamp                     │
└──────────────────────────────────────────────────┘
```

---

## Components

### 1. Neo4j Database

- **Version:** 2025.08 Community Edition (latest stable)
- **Ports:** 7474 (browser), 7687 (bolt protocol)
- **Memory:** 4GB heap + 2GB page cache = 6GB total
- **APOC Plugin:** Pre-installed with 300+ procedures
- **Data:** Persisted in `./neo4j-data/`

### 2. Update Watcher (THE MAGIC!)

- **What it does:** Watches `updates/` folder for new `.cypher` files
- **When:** Checks every 10 seconds
- **Action:** Auto-executes files against Neo4j
- **After:** Moves processed files to `updates/processed/` with timestamp
- **Logs:** Everything logged - success or error
- **Heartbeat:** Shows "alive" message every 1 minute in logs

**This means: Drop file → Wait 10 seconds → Done!**

---

## File Structure

```
C:\Docker\neo4j\
├── docker-compose.yml                   # Main configuration
├── .env                                 # Credentials (secure!)
├── backup.ps1                  		 # Backup script
├── restore.ps1                 	     # Restore script
├── watcher.py                           # Auto-runner script
├── init-scripts\                        # FIRST-TIME ONLY (runs once)
├── updates\                             # DROP NEW FILES HERE!
│   └── processed\                       # Auto-moved after execution
└── neo4j-data\                          # Persistent data
    ├── data\                            # Database files
    ├── logs\                            # Neo4j logs
    ├── plugins\                         # APOC jars
    ├── import\                          # CSV/JSON imports
	├── backups\                         # Your backup storage
```

---

## Backup & Restore

### ⚠️ Important: Community Edition Limitations

**Neo4j Community Edition requires stopping the database for clean backups.** Online backups without downtime require Enterprise Edition.

### Manual Offline Backup (Recommended)

**Safest method - ensures data consistency:**

```powershell
powershell -ExecutionPolicy Bypass -File .\backup.ps1
```

**What it does:**
1. Stops Docker containers (downtime starts)
2. Creates timestamped folder: `neo4j-data\backups\20251023_143052\`
3. Copies `neo4j-data\data`, `neo4j-data\plugins`, `.env`, `docker-compose.yml`
4. Restarts containers (downtime ends)
5. Auto-deletes backups older than 30 days

**Expected downtime:** 2-5 minutes per backup

### Restore from Backup

```powershell
powershell -ExecutionPolicy Bypass -File .\restore.ps1
```

**What it does:**
1. Shows list of available backups
2. Requires typing "yes" for safety
3. Creates automatic rollback backup (named `timestamp_ROLLBACK`)
4. Stops services
5. Restores all data from selected backup
6. Optionally restores configuration files
7. Restarts services

**Features:**
- ✅ Automatic rollback protection
- ✅ No rollback created when restoring from a rollback (prevents chains)
- ✅ Interactive selection of backup to restore
- ✅ Optional restoration of docker-compose.yml

### Backup Strategy Recommendations

**Development Environment:**
- Backup before major changes
- Keep last 5-10 backups

**Production Environment:**
- Daily automated backups (use Task Scheduler)
- Keep 7 daily + 4 weekly + 3 monthly backups
- Test restores regularly!

**Before Updates:**
```powershell
# Always backup before upgrading Neo4j versions
powershell -ExecutionPolicy Bypass -File .\backup.ps1
```

### Automated Backups (Windows Task Scheduler)

Create a scheduled task to run backups automatically:

1. Open Task Scheduler
2. Create Basic Task
3. Name: "Neo4j Daily Backup"
4. Trigger: Daily at 2 AM
5. Action: Start a program
   - Program: `powershell.exe`
   - Arguments: `-ExecutionPolicy Bypass -File "C:\Docker\neo4j\backup.ps1"`
   - Start in: `C:\Docker\neo4j`

---

## How to Apply Updates

### For End Users (Simple!)

**Step 1:** You receive a file like `add-email-field.cypher`
**Step 2:** Copy it to `C:\Docker\neo4j\updates\`
**Step 3:** Wait 5-10 seconds
**Step 4:** Check `updates\processed\` - file will be there with timestamp

**Done!** Update applied automatically.

### For Administrators

**Monitor what's happening:**

```cmd
docker-compose logs -f neo4j-watcher
```

**See processed files:**

```cmd
dir updates\processed
```

**If an update fails:**
- File moved to `processed/` with `ERROR_` prefix
- Check watcher logs for error message
- Fix the `.cypher` file and drop it again

---

## Configuration Details

### Memory Settings

- **Heap:** 4GB for query execution
- **Page Cache:** 2GB for graph data caching
- **Total:** ~6GB RAM allocated

**To increase for larger graphs:**

```yaml
environment:
  - NEO4J_server_memory_heap_max__size=8G
  - NEO4J_server_memory_pagecache_size=4G
```

### APOC Features Enabled

- File import/export
- Triggers (event-driven actions)
- UUID generation
- TTL (time-to-live for auto-cleanup)

### Security Settings

```yaml
# Development: All procedures allowed
- NEO4J_dbms_security_procedures_unrestricted=apoc.*

# Production: Whitelist only what you need
# - NEO4J_dbms_security_procedures_allowlist=apoc.load.*,apoc.export.*
```

### Performance Tuning

- Query cache: 1000 compiled queries
- Connection pool: Up to 400 concurrent connections
- Transaction timeout: 60 seconds

---

## Troubleshooting

### Services won't start

```cmd
# Check logs
docker-compose logs

# Check status
docker-compose ps

# Restart services
docker-compose restart
```
### Updates not processing

```cmd
# Check watcher is running
docker-compose ps neo4j-watcher

# View watcher logs
docker-compose logs -f neo4j-watcher

# Restart watcher
docker-compose restart neo4j-watcher
```
### File stuck in updates folder

**Possible causes:**
1. **Syntax error in .cypher file** - Check watcher logs for error
2. **Watcher not running** - Run `docker-compose ps`
3. **File permissions** - Ensure file is not locked/open

**Solution:**
- Check logs: `docker-compose logs neo4j-watcher`
- Look for `ERROR_` prefix in `processed/` folder
- Fix the file and drop it again

### Neo4j Browser won't connect

- **Wait 60 seconds** after startup (Neo4j is slow to start)
- Check Neo4j is running: `docker-compose ps neo4j-graph`
- Check logs: `docker-compose logs neo4j-graph`
- Verify port not in use: `netstat -ano | findstr :7474`

### Out of memory

**Increase Docker Desktop memory:**
- Docker Desktop → Settings → Resources → Memory
- Set to at least 10GB for Neo4j + Watcher

**Or reduce Neo4j memory:**

```yaml
environment:
  - NEO4J_server_memory_heap_max__size=2G
  - NEO4J_server_memory_pagecache_size=1G
```

---

## Maintenance

### View All Processed Updates

```cmd
dir updates\processed /O-D
```

Shows files ordered by date (newest first).
### Clean Old Processed Files

```cmd
REM Keep last 30 days, delete older
forfiles /P "updates\processed" /D -30 /C "cmd /c del @path"
```
### Restart Everything

```cmd
docker-compose restart
```
### Update Neo4j Version

```yaml
# In docker-compose.yml, change:
image: neo4j:2025.08-community
# To:
image: neo4j:2025.09-community
```

Then:

```cmd
docker-compose down
docker-compose pull
docker-compose up -d
```

---

## Useful Commands

```cmd
# View all logs
docker-compose logs -f

# View only watcher logs
docker-compose logs -f neo4j-watcher

# View only Neo4j logs
docker-compose logs -f neo4j-graph

# Stop everything
docker-compose down

# Enter Neo4j container
docker-compose exec neo4j bash

# Run cypher from command line
docker-compose exec neo4j cypher-shell -u neo4j -p your_password

# Check resource usage
docker stats
```

---

## Security Best Practices

### Change Default Password

```cmd
# Edit .env file
notepad .env
```

Set a strong password, then restart:

```cmd
docker-compose restart
```

### SSL/TLS Encryption

Neo4j supports SSL/TLS encryption for both the browser UI and Bolt protocol connections.

#### **SSL Configuration Options**

**Option 1: Self-Signed Certificates (Development/Testing)**
```powershell
# Generate self-signed certificates
.\management\manage-ssl.ps1 generate -Domain "your-domain.com"

# Enable SSL
.\management\manage-ssl.ps1 enable
```

**Option 2: CA-Provided Certificates (Production)**
```powershell
# Install CA-provided certificates
.\management\manage-ssl.ps1 install-ca -ServerCertPath "C:\certs\server.crt" -ServerKeyPath "C:\certs\server.key" -CACertPath "C:\certs\ca.crt"

# Enable SSL
.\management\manage-ssl.ps1 enable
```

#### **SSL Ports and Access**
- **HTTPS Browser UI**: https://localhost:7473 (when SSL enabled)
- **Bolt+TLS Protocol**: bolt+s://localhost:7687 (when SSL enabled)
- **HTTP Browser UI**: http://localhost:7474 (disabled when SSL enabled)
- **Bolt Protocol**: bolt://localhost:7687 (disabled when SSL enabled)

#### **Client Certificate Distribution**
For self-signed certificates, client machines need the CA certificate:

**CA Certificate Location**: `certs/bolt/trusted/ca.crt` or `certs/https/trusted/ca.crt`

**Install on Client Machines:**
```powershell
# Install CA certificate to Windows trusted root store
Import-Certificate -FilePath "ca.crt" -CertStoreLocation Cert:\LocalMachine\Root
```

**Neo4j Client Configuration:**
```python
# Python neo4j driver with SSL
from neo4j import GraphDatabase
driver = GraphDatabase.driver(
    "bolt+s://your-server:7687",
    auth=("neo4j", "password"),
    trusted_certificates=["path/to/ca.crt"]
)
```

#### **SSL Management Commands**
```powershell
# Check SSL status
.\management\manage-ssl.ps1 status

# Generate new certificates
.\management\manage-ssl.ps1 generate -Domain "neo4j.company.com" -ValidDays 730

# Renew existing certificates
.\management\manage-ssl.ps1 renew

# Disable SSL
.\management\manage-ssl.ps1 disable
```

### Don't Expose to Internet

- Keep ports bound to localhost only (already configured)
- Use VPN or SSH tunnel for remote access
- Never open 7474/7687 to public internet without SSL
- Use SSL/TLS encryption for any network access
### Regular Backups

- Schedule automated backups (see backup section)
- Test restore process quarterly
- Keep backups off-site or in cloud storage
### Monitor Processed Files

- Review `updates/processed/` regularly
- Check for `ERROR_` prefixed files
- Investigate any unexpected changes

---

## When to Upgrade to Enterprise

Consider Neo4j Enterprise Edition if you need:
- **Online backups:** Zero downtime backups with `neo4j-admin backup`
- **Hot backups:** Scheduled backups without stopping database
- **Clustering:** Multiple servers, high availability
- **RBAC:** Fine-grained user permissions
- **Bloom:** Advanced graph visualization
- **Official Support:** Neo4j support contract

**For single-machine setups with maintenance windows, Community Edition works great!**

**Pricing:** Contact Neo4j sales - typically $50K+ per year for production licenses.

---

## Support Resources

- **Neo4j Docs:** https://neo4j.com/docs/
- **Cypher Manual:** https://neo4j.com/docs/cypher-manual/current/
- **APOC Docs:** https://neo4j.com/docs/apoc/current/
- **Community Forum:** https://community.neo4j.com/
- **GraphAcademy (Free Training):** https://graphacademy.neo4j.com/

---

## Version Info

- **Neo4j:** 2025.08 Community Edition
- **APOC:** 2025.08.0 Core (auto-matched)
- **Python Watcher:** Python 3.11
- **Neo4j Driver:** Latest (auto-installed)

---

## FAQ

**Q: What happens if I drop multiple files at once?**  
A: Watcher processes them alphabetically, one at a time. Use numeric prefixes for ordering (e.g., `01-`, `02-`).

**Q: Can I see what a file will do before it runs?**  
A: Yes, open the `.cypher` file in a text editor before dropping it in `updates/`.

**Q: What if an update fails?**  
A: File moved to `processed/` with `ERROR_` prefix. Check watcher logs, fix file, drop again.

**Q: How do I undo an update?**  
A: Write a new `.cypher` file that reverses the change. Neo4j doesn't have automatic rollback for schema changes.

**Q: Can I schedule updates for specific times?**  
A: Yes, use Windows Task Scheduler to copy files to `updates/` at scheduled times.

**Q: Does this work on Linux/Mac?**  
A: Yes! Just adjust file paths (use `/` instead of `\`) and use cron instead of Task Scheduler.

**Q: Can I backup without stopping Neo4j?**  
A: Not with Community Edition. APOC exports work while running but aren't full backups. Enterprise Edition supports online backups.

**Q: How long does a backup take?**  
A: Typically 2-5 minutes depending on database size. Schedule during off-hours to minimize impact.

**Q: Where are backups stored?**  
A: `C:\Docker\neo4j\neo4j-data\backups\` with timestamped folders (e.g., `20251023_143052\`). Everything stays in your Neo4j directory. Copy to network/cloud storage for off-site protection.

**Q: What happens if backup.bat fails?**  
A: Neo4j restarts automatically. Check Task Scheduler history and batch script output for errors.

**Q: Can I run backups while users are connected?**  
A: No - Community Edition requires stopping the database. Schedule during maintenance windows or off-hours.

---

**Last Updated:** October 24, 2025  
**Maintained by:** Gavin Green
