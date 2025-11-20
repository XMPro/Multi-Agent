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
├── timescaledb_readme.md       # This file
├── .env                        # Environment variables (created during install)
├── config/
│   └── postgresql.conf         # PostgreSQL configuration
├── init/
│   └── 01-init-timescaledb.sql # Initialization SQL scripts
├── certs/                      # SSL certificates (if SSL enabled)
│   ├── ca.crt
│   ├── server.crt
│   └── server.key
├── backups/                    # Database backups
└── management/                 # Management scripts
    ├── install.ps1/sh          # Installation scripts
    ├── backup.ps1/sh           # Backup scripts
    ├── restore.ps1/sh          # Restore scripts
    └── manage-ssl.ps1/sh       # SSL management scripts
```

## Accessing TimescaleDB

### Connection Information

**Default Access:**
- **Host**: localhost
- **Port**: 5432
- **Database**: timescaledb
- **User**: postgres
- **Password**: (set during installation)

### Connection String

```
postgresql://postgres:your_password@localhost:5432/timescaledb
```

### Using psql

```bash
# Connect to database
docker exec -it timescaledb psql -U postgres -d timescaledb

# Or from host (if psql installed)
psql -h localhost -U postgres -d timescaledb
```

### Using Programming Languages

**Python (psycopg2):**
```python
import psycopg2

conn = psycopg2.connect(
    host="localhost",
    port=5432,
    database="timescaledb",
    user="postgres",
    password="your_password"
)
```

**Node.js (pg):**
```javascript
const { Client } = require('pg');

const client = new Client({
    host: 'localhost',
    port: 5432,
    database: 'timescaledb',
    user: 'postgres',
    password: 'your_password'
});
```

## Working with Time-Series Data

### Creating a Hypertable

```sql
-- Create a regular table
CREATE TABLE sensor_data (
    time TIMESTAMPTZ NOT NULL,
    sensor_id INTEGER,
    temperature DOUBLE PRECISION,
    humidity DOUBLE PRECISION
);

-- Convert to hypertable
SELECT create_hypertable('sensor_data', 'time');

-- Create index for better query performance
CREATE INDEX ON sensor_data (sensor_id, time DESC);
```

### Inserting Data

```sql
INSERT INTO sensor_data VALUES
    (NOW(), 1, 23.5, 45.2),
    (NOW(), 2, 24.1, 43.8);
```

### Querying Time-Series Data

```sql
-- Get recent data
SELECT * FROM sensor_data
WHERE time > NOW() - INTERVAL '1 hour'
ORDER BY time DESC;

-- Aggregate data
SELECT 
    time_bucket('5 minutes', time) AS bucket,
    sensor_id,
    AVG(temperature) as avg_temp
FROM sensor_data
WHERE time > NOW() - INTERVAL '1 day'
GROUP BY bucket, sensor_id
ORDER BY bucket DESC;
```

### Continuous Aggregates

```sql
-- Create continuous aggregate for faster queries
CREATE MATERIALIZED VIEW sensor_data_hourly
WITH (timescaledb.continuous) AS
SELECT 
    time_bucket('1 hour', time) AS bucket,
    sensor_id,
    AVG(temperature) as avg_temperature,
    MAX(temperature) as max_temperature,
    MIN(temperature) as min_temperature
FROM sensor_data
GROUP BY bucket, sensor_id;

-- Refresh policy (automatic updates)
SELECT add_continuous_aggregate_policy('sensor_data_hourly',
    start_offset => INTERVAL '3 hours',
    end_offset => INTERVAL '1 hour',
    schedule_interval => INTERVAL '1 hour');
```

### Data Compression

```sql
-- Enable compression
ALTER TABLE sensor_data SET (
    timescaledb.compress,
    timescaledb.compress_segmentby = 'sensor_id'
);

-- Add compression policy (compress data older than 7 days)
SELECT add_compression_policy('sensor_data', INTERVAL '7 days');
```

### Data Retention

```sql
-- Drop data older than 90 days
SELECT add_retention_policy('sensor_data', INTERVAL '90 days');
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

### Create Backup

**Windows:**
```powershell
.\management\backup.ps1 -BackupName "my_backup"
```

**Linux:**
```bash
./management/backup.sh --name my_backup
```

### Restore Backup

**Windows:**
```powershell
.\management\restore.ps1 -BackupFile "backups/my_backup.sql.gz"
```

**Linux:**
```bash
./management/restore.sh --file backups/my_backup.sql.gz
```

### Automated Backups

Consider setting up automated backups using cron (Linux) or Task Scheduler (Windows):

```bash
# Daily backup at 2 AM
0 2 * * * /path/to/timescaledb/management/backup.sh --name daily_$(date +\%Y\%m\%d)
```

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
2. Restore from backup: `./management/restore.sh`
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
