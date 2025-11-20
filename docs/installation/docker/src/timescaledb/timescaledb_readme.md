# TimescaleDB Time-Series Database - Docker Deployment

This directory contains the Docker deployment configuration for TimescaleDB, a PostgreSQL extension optimized for time-series data.

## Overview

TimescaleDB extends PostgreSQL with time-series capabilities, providing:
- **Hypertables**: Automatic partitioning for time-series data
- **Continuous Aggregates**: Materialized views optimized for time-series queries
- **Compression**: Automatic data compression for older data
- **Data Retention**: Automated data retention policies
- **High Performance**: Optimized for high-volume time-series workloads

## Quick Start

### Installation

Use the installation script to set up TimescaleDB:

**Windows (PowerShell):**
```powershell
cd timescaledb\management
.\install.ps1
```

**Linux/macOS (Bash):**
```bash
cd timescaledb/management
chmod +x install.sh
./install.sh
```

### Configuration Options

The installation script supports several options:

- `-Force`: Skip confirmation prompts
- `-EnableSSL`: Enable SSL/TLS encryption
- `-Domain <domain>`: Specify domain for SSL certificates (default: localhost)
- `-Password <password>`: Set database password (not recommended for security)

**Recommended:** Use environment variables for passwords:
```bash
export TIMESCALEDB_PASSWORD="your_secure_password"
```

## Directory Structure

```
timescaledb/
├── docker-compose.yml          # Docker Compose configuration
├── docker-entrypoint.sh        # Custom entrypoint (fixes SSL cert permissions)
├── timescaledb_readme.md       # This file
├── .env                        # Environment variables (created during install)
├── config/
│   ├── postgresql.conf.template # PostgreSQL config template
│   └── postgresql.conf         # PostgreSQL configuration (generated)
├── init/
│   └── 01-init-timescaledb.sql # Initialization SQL scripts
├── certs/                      # SSL certificates (if SSL enabled)
│   ├── ca.crt                  # Certificate Authority
│   ├── server.crt              # Server certificate
│   └── server.key              # Server private key
├── backups/                    # Automated backups (pgBackRest)
├── pgadmin/
│   └── servers.json            # pgAdmin server configuration
├── pgbackrest/
│   ├── pgbackrest.conf         # pgBackRest configuration
│   └── cron                    # Backup schedule
└── management/                 # Management scripts
    ├── install.ps1/sh          # Installation scripts
    └── manage-ssl.ps1/sh       # SSL management scripts
```

## Included Services

### TimescaleDB
- **Container**: `timescaledb`
- **Port**: 5432
- **Purpose**: Time-series database with PostgreSQL compatibility

### pgAdmin
- **Container**: `timescaledb-pgadmin`
- **Port**: 5050
- **Purpose**: Web-based database administration interface
- **Pre-configured**: TimescaleDB server connection ready to use

### pgBackRest
- **Container**: `timescaledb-pgbackrest`
- **Purpose**: Automated backup and restore system
- **Schedule**: Daily full backups + hourly incrementals
- **Features**: Compression, retention policies, point-in-time recovery

## Accessing TimescaleDB

### Connection Information

**Default Access:**
- **Host**: localhost (or your machine's IP/DNS for remote access)
- **Port**: 5432
- **Database**: timescaledb (configurable during installation)
- **User**: postgres (configurable during installation)
- **Password**: (set during installation, check .env file)

**pgAdmin Web UI:**
- **URL (HTTP)**: http://localhost:5050
- **URL (HTTPS)**: https://localhost:5051 (when SSL is enabled)
- **Email**: admin@timescaledb.local
- **Password**: (generated during installation, check .env file)
- **Note**: TimescaleDB server is pre-configured in pgAdmin
- **SSL**: Automatically enabled when TimescaleDB SSL is enabled

### Connection String

**Without SSL:**
```
postgresql://postgres:your_password@localhost:5432/timescaledb
```

**With SSL:**
```
postgresql://postgres:your_password@localhost:5432/timescaledb?sslmode=require
```

**Remote Access:**
```
postgresql://postgres:your_password@YOUR_MACHINE_IP:5432/timescaledb
```

## Performance Tuning

### Memory Configuration

The installation creates a tuned `postgresql.conf` with production-grade settings:

- **shared_buffers**: 25% of system RAM
- **effective_cache_size**: 75% of system RAM
- **work_mem**: Based on concurrent connections
- **maintenance_work_mem**: For maintenance operations

### Monitoring Queries

```sql
-- Check hypertable stats
SELECT * FROM timescaledb_information.hypertables;

-- Check chunk information
SELECT * FROM timescaledb_information.chunks
WHERE hypertable_name = 'sensor_data';

-- Check compression stats
SELECT * FROM timescaledb_information.compression_settings;

-- View active queries
SELECT * FROM pg_stat_activity
WHERE state = 'active';
```

## Backup and Restore

### Automated Backup System (pgBackRest)

TimescaleDB includes **pgBackRest**, a production-grade automated backup solution that runs continuously.

**Backup Schedule:**
- **Full Backup**: Daily at 2:00 AM
- **Incremental Backup**: Every hour
- **Retention**: Configurable during installation (default: 30 days)
- **Compression**: Enabled (gzip)
- **Storage**: `./backups` directory

**Data Storage:**
- **Database Data**: Docker volume `timescaledb_data` (persistent, survives container recreation)
- **Automated Backups**: `./backups` directory (managed by pgBackRest)

### View Backup Information

```bash
# List all backups
docker exec timescaledb-pgbackrest pgbackrest --stanza=timescaledb info

# View detailed backup info
docker exec timescaledb-pgbackrest pgbackrest --stanza=timescaledb info --output=json
```

### Manual Backup (On-Demand)

**Using pgBackRest (Recommended):**
```bash
# Create full backup manually
docker exec timescaledb-pgbackrest pgbackrest --stanza=timescaledb --type=full backup

# Create incremental backup manually
docker exec timescaledb-pgbackrest pgbackrest --stanza=timescaledb --type=incr backup
```

### Restore from Backup

**Restore to Latest:**
```bash
# Stop TimescaleDB
docker-compose stop timescaledb

# Restore latest backup
docker exec timescaledb-pgbackrest pgbackrest --stanza=timescaledb restore

# Start TimescaleDB
docker-compose start timescaledb
```

**Point-in-Time Recovery (PITR):**
```bash
# Restore to specific time
docker exec timescaledb-pgbackrest pgbackrest --stanza=timescaledb \
  --type=time --target="2024-01-15 14:30:00" restore
```

**Restore Specific Backup:**
```bash
# List backups to find backup label
docker exec timescaledb-pgbackrest pgbackrest --stanza=timescaledb info

# Restore specific backup
docker exec timescaledb-pgbackrest pgbackrest --stanza=timescaledb \
  --set=20240115-143000F restore
```

### Backup Best Practices

1. **Monitor Backup Status**: Regularly check `docker-compose logs pgbackrest`
2. **Test Restores**: Periodically test backup restoration
3. **Offsite Storage**: Copy backups to offsite location for disaster recovery
4. **Retention Policy**: Adjust retention based on compliance requirements
5. **Disk Space**: Monitor `./backups` directory size

## SSL/TLS Configuration

### Enable SSL

Use the SSL management script:

**Windows:**
```powershell
.\management\manage-ssl.ps1 -Enable -Domain "your-domain.com"
```

**Linux:**
```bash
./management/manage-ssl.sh --enable --domain your-domain.com
```

### Connect with SSL

```bash
psql "postgresql://postgres:password@localhost:5432/timescaledb?sslmode=require"
```

## Production Considerations

### Security

1. **Change Default Password**: Always use a strong, unique password
2. **Enable SSL**: Use SSL/TLS for encrypted connections
3. **Firewall Rules**: Restrict access to port 5432
4. **Regular Updates**: Keep TimescaleDB and PostgreSQL updated
5. **User Permissions**: Create limited-privilege users for applications

### High Availability

For production deployments, consider:
- **Replication**: Set up streaming replication for failover
- **Connection Pooling**: Use PgBouncer for connection management
- **Monitoring**: Implement comprehensive monitoring (Prometheus, Grafana)
- **Load Balancing**: Distribute read queries across replicas

### Resource Planning

- **Storage**: Time-series data grows quickly - plan for 3-5x compression ratios
- **Memory**: More RAM = better performance (aim for 16GB+ for production)
- **CPU**: Multi-core processors for parallel query execution
- **I/O**: Fast SSD storage for optimal performance

## Troubleshooting

### Check Container Status

```bash
docker-compose ps
docker-compose logs -f timescaledb
```

### Connection Issues

```bash
# Test connection
docker exec timescaledb pg_isready -U postgres

# Check listening ports
docker exec timescaledb netstat -tulpn | grep 5432
```

### Performance Issues

```sql
-- Identify slow queries
SELECT query, calls, mean_exec_time, total_exec_time
FROM pg_stat_statements
ORDER BY total_exec_time DESC
LIMIT 10;

-- Check table sizes
SELECT 
    hypertable_name,
    pg_size_pretty(hypertable_size) as size
FROM timescaledb_information.hypertables;
```

### Recovery

If the database becomes corrupted:

1. Stop the container: `docker-compose down`
2. Restore from backup using pgBackRest (see "Restore from Backup" section above)
3. Start the container: `docker-compose up -d`

## Common Operations

### Stop Database

```bash
docker-compose down
```

### Start Database

```bash
docker-compose up -d
```

### Restart Database

```bash
docker-compose restart
```

### View Logs

```bash
docker-compose logs -f
```

### Update to Latest Version

```bash
docker-compose pull
docker-compose up -d
```

## Additional Resources

- [TimescaleDB Documentation](https://docs.timescale.com/)
- [PostgreSQL Documentation](https://www.postgresql.org/docs/)
- [TimescaleDB Best Practices](https://docs.timescale.com/timescaledb/latest/how-to-guides/)
- [Time-Series Data Management](https://docs.timescale.com/timescaledb/latest/overview/core-concepts/)

## Support

For issues or questions:
- Check container logs: `docker-compose logs -f`
- Verify configuration: `cat .env`
- Test connectivity: `docker exec -it timescaledb psql -U postgres -d timescaledb`
- Review PostgreSQL logs: `docker exec timescaledb cat /var/log/postgresql/postgresql.log`
