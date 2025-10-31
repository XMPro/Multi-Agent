# MQTT Mosquitto Production Setup

A production-ready MQTT broker setup using Eclipse Mosquitto with Docker Compose, featuring authentication, SSL/TLS support, persistence, backups, and comprehensive management tools.

## 🚀 Quick Start

### Prerequisites
- Docker Desktop installed and running
- PowerShell (Windows)
- OpenSSL (optional, for SSL certificate management)

### Installation
1. **Run the installation script:**
   ```powershell
   .\management\install.ps1
   ```
   This will:
   - Create directory structure
   - Prompt for SSL/TLS preference
   - Generate secure credentials (or prompt for custom password)
   - Create mosquitto.conf and acl.txt configuration files
   - Set up authentication with proper password hashing
   - Initialize backup system

2. **Installation Script Options:**
   ```powershell
   # Normal installation (preserves existing config files)
   .\management\install.ps1
   
   # Force overwrite existing files
   .\management\install.ps1 -Force
   
   # Custom username and password
   .\management\install.ps1 -Username "myuser" -Password "mypassword" -Force
   
   # Enable SSL during installation
   .\management\install.ps1 -EnableSSL
   ```

3. **Config File Behavior:**
   - **Existing files**: Preserved by default (shows "already exists" message)
   - **Missing files**: Created automatically
   - **Force overwrite**: Use `-Force` parameter to replace existing files
   - **Safe by default**: Won't accidentally overwrite your customizations

4. **Start the MQTT broker:**
   ```powershell
   docker-compose up -d
   ```

5. **Verify the installation:**
   ```powershell
   docker-compose ps
   docker-compose logs mosquitto
   ```

## 📁 Directory Structure

```
mqtt/
├── config/
│   ├── mosquitto.conf      # Main broker configuration
│   ├── passwords.txt       # User authentication (hashed)
│   └── acl.txt            # Access control list
├── data/
│   ├── mosquitto.db       # Persistent message store
│   └── backups/           # Backup storage
├── logs/
│   └── mosquitto.log      # Broker logs
├── certs/                 # SSL certificates (if enabled)
│   ├── ca.crt
│   ├── ca.key
│   ├── server.crt
│   └── server.key
├── docker-compose.yml     # Docker configuration
├── .env                   # Environment variables
├── install.ps1           # Installation script
├── backup.ps1            # Backup script
├── restore.ps1           # Restore script
├── manage-users.ps1      # User management
├── manage-ssl.ps1        # SSL certificate management
└── mqtt_readme.md        # This documentation
```

## 🔧 Configuration

### Environment Variables (.env)
```bash
# MQTT Broker Configuration
MQTT_PORT=1883
MQTT_SSL_PORT=8883
MQTT_WS_PORT=9001

# Timezone
TZ=America/Chicago

# Backup Configuration
BACKUP_RETENTION_DAYS=30

# SSL Configuration
ENABLE_SSL=false

# Performance Tuning
MAX_CONNECTIONS=1000
MAX_QUEUED_MESSAGES=1000
MESSAGE_SIZE_LIMIT=268435456
```

### Broker Configuration (mosquitto.conf)
The broker is configured for production use with:
- **Persistence enabled** - Messages survive broker restarts
- **Authentication required** - No anonymous connections
- **Access control** - Fine-grained topic permissions
- **Multiple listeners** - MQTT, SSL, and WebSocket support
- **Comprehensive logging** - Error, warning, notice, and info levels
- **Performance tuning** - Optimized for production workloads

## 🔐 User Management

### User Management Commands:

**Add a new user:**
```powershell
# Add user with auto-generated password and interactive ACL selection
.\management\manage-users.ps1 add -Username "sensor01"

# Add user with custom password
.\management\manage-users.ps1 add -Username "device01" -Password "mypassword"

# Force overwrite existing user
.\management\manage-users.ps1 add -Username "existinguser" -Force
```

**Remove a user:**
```powershell
# Remove user with confirmation prompt
.\management\manage-users.ps1 remove -Username "olduser"

# Remove user without confirmation
.\management\manage-users.ps1 remove -Username "olduser" -Force
```

**Change user password:**
```powershell
# Change password (auto-generated)
.\management\manage-users.ps1 change-password -Username "user01"

# Change to specific password
.\management\manage-users.ps1 change-password -Username "user01" -Password "newpassword"
```

**List all users:**
```powershell
# Show all users and their ACL permissions
.\management\manage-users.ps1 list
```

### User Management Parameters:
- **`-Username`** - Username to add/remove/modify
- **`-Password`** - Password for user (auto-generated if not provided)
- **`-Force`** - Skip confirmation prompts and overwrite existing users

### ACL Permission Options:

When adding a new user, you'll be prompted to choose ACL permissions:

**1. Full Access (`readwrite #`):**
- **What it does:** User can read and write to ALL topics
- **Use for:** Admin users, trusted systems, development/testing
- **Security level:** High trust required
- **Example topics:** Any topic (sensors/temp, actuators/lights, etc.)

**2. User-Specific Topics (`readwrite user/username/+`):**
- **What it does:** User can only access topics under their own namespace
- **Use for:** Individual devices, isolated users, multi-tenant systems
- **Security level:** Medium - isolated access
- **Example topics:** `user/sensor01/data`, `user/sensor01/status`

**3. Read-Only Access (`read #`):**
- **What it does:** User can read all topics but cannot publish
- **Use for:** Monitoring systems, dashboards, data collection
- **Security level:** Low risk - cannot modify data
- **Example topics:** Can read any topic but cannot publish

**4. Custom Permissions:**
- **What it does:** You specify exact topic patterns and permissions
- **Use for:** Specific use cases, fine-grained control
- **Security level:** As restrictive as you make it
- **Examples:**
  - `readwrite sensors/+` - Read/write only sensor topics
  - `read status/#` - Read-only access to status topics
  - `write actuators/lights` - Write only to light controls

**5. No ACL Entry (Pattern Inheritance):**
- **What it does:** User inherits only pattern-based permissions from ACL file
- **Use for:** When you have complex pattern rules already defined
- **Security level:** Depends on existing patterns
- **Example:** User gets access based on `pattern read sensors/%u/+` rules

### ACL Best Practices:

**For Production:**
- **Sensors/Devices:** Use option 2 (user-specific topics) or 4 (custom read/write to specific sensor topics)
- **Monitoring Systems:** Use option 3 (read-only) or 4 (custom read access)
- **Control Systems:** Use option 4 (custom write access to actuator topics)
- **Admin Users:** Use option 1 (full access) sparingly
- **Multi-tenant:** Use option 2 (user-specific topics) for isolation

## 🔒 SSL/TLS Security

MQTT supports SSL/TLS encryption for secure message transmission and client authentication.

### **SSL Configuration Options**

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

### **SSL Ports and Access**
- **MQTT SSL**: localhost:8883 (encrypted MQTT connections)
- **MQTT Standard**: localhost:1883 (disabled when SSL enabled)
- **WebSocket**: ws://localhost:9002 (can be configured for WSS)

### **Client Certificate Distribution**
For self-signed certificates, client machines need the CA certificate:

**CA Certificate Location**: `certs/ca.crt`

**Install on Client Machines:**
```powershell
# Install CA certificate to Windows trusted root store
Import-Certificate -FilePath "ca.crt" -CertStoreLocation Cert:\LocalMachine\Root
```

**MQTT Client Configuration:**
```python
# Python paho-mqtt with SSL
import paho.mqtt.client as mqtt
import ssl

client = mqtt.Client()
client.username_pw_set("username", "password")
context = ssl.create_default_context(ssl.Purpose.SERVER_AUTH)
context.load_verify_locations("path/to/ca.crt")
client.tls_set_context(context)
client.connect("your-server", 8883, 60)
```

### SSL Management Commands:

**Generate SSL certificates:**
```powershell
# Basic generation (localhost)
.\management\manage-ssl.ps1 generate

# Custom domain and validity
.\management\manage-ssl.ps1 generate -Domain "your-domain.com" -ValidDays 730

# Force overwrite existing certificates
.\management\manage-ssl.ps1 generate -Force
```

**Enable SSL:**
```powershell
# Enable SSL (requires certificates to exist first)
.\management\manage-ssl.ps1 enable
```

**Disable SSL:**
```powershell
# Disable SSL encryption
.\management\manage-ssl.ps1 disable
```

**Check SSL status:**
```powershell
# View certificate status, expiry dates, and configuration
.\management\manage-ssl.ps1 status
```

**Renew certificates:**
```powershell
# Renew with default settings
.\management\manage-ssl.ps1 renew

# Renew with custom domain and validity
.\management\manage-ssl.ps1 renew -Domain "new-domain.com" -ValidDays 365
```

### SSL Parameters:
- **`-Domain`** - Certificate domain name (default: "localhost")
- **`-ValidDays`** - Certificate validity in days (default: 365)
- **`-Force`** - Overwrite existing certificates without prompting

### SSL Certificate Backup:
- **Automatic backup** during renewal to `certs\backup-YYYYMMDD_HHMMSS\`
- **Timestamped folders** prevent overwriting previous backups
- **Easy rollback** if new certificates don't work

## 💾 Backup & Restore

### Create a backup:
```powershell
.\backup.ps1
```

### Create a named backup:
```powershell
.\backup.ps1 -BackupName "before-upgrade"
```

### Restore from backup:
```powershell
.\restore.ps1 -BackupPath "data\backups\20241024_140000"
```

### Automated backups:
Set up Windows Task Scheduler to run backups automatically:
```powershell
# Example: Daily backup at 2 AM
schtasks /create /tn "MQTT Backup" /tr "powershell.exe -File C:\path\to\mqtt\backup.ps1" /sc daily /st 02:00
```

## 🌐 Connection Details

### Standard MQTT Connection
- **Host:** localhost (or your server IP)
- **Port:** 1883
- **Protocol:** MQTT
- **Security:** Username/Password

### SSL/TLS Connection (if enabled)
- **Host:** localhost (or your server IP)
- **Port:** 8883
- **Protocol:** MQTT over SSL/TLS
- **Security:** Username/Password + SSL

### WebSocket Connection
- **URL:** ws://localhost:9001
- **Protocol:** MQTT over WebSockets
- **Security:** Username/Password

## 📊 Monitoring & Health Checks

### Check broker status:
```powershell
docker-compose ps
```

### View logs:
```powershell
# Real-time logs
docker-compose logs -f mosquitto

# Last 100 lines
docker-compose logs --tail 100 mosquitto
```

### System topics (for monitoring):
- `$SYS/broker/uptime` - Broker uptime
- `$SYS/broker/clients/connected` - Connected clients
- `$SYS/broker/messages/received` - Messages received
- `$SYS/broker/messages/sent` - Messages sent

### Health check endpoint:
The Docker container includes a health check that monitors broker availability.

## 🔧 Troubleshooting

### Common Issues

**1. Broker won't start:**
```powershell
# Check configuration
docker-compose config

# Check logs for errors
docker-compose logs mosquitto
```

**2. Authentication failures:**
```powershell
# Verify user exists
.\manage-users.ps1 list

# Check password file
Get-Content config\passwords.txt
```

**3. SSL connection issues:**
```powershell
# Check SSL status
.\manage-ssl.ps1 status

# Verify certificates
openssl x509 -in certs\server.crt -text -noout
```

**4. Permission denied errors:**
```powershell
# Check ACL configuration
Get-Content config\acl.txt

# Verify user permissions
.\manage-users.ps1 list
```

### Log Analysis
```powershell
# Search for errors
docker-compose logs mosquitto | Select-String "error"

# Monitor connections
docker-compose logs mosquitto | Select-String "New connection"

# Check authentication attempts
docker-compose logs mosquitto | Select-String "authentication"
```

## 🚀 Performance Tuning

### For High-Volume Environments

1. **Increase connection limits** in `.env`:
   ```bash
   MAX_CONNECTIONS=5000
   MAX_QUEUED_MESSAGES=5000
   ```

2. **Adjust persistence settings** in `mosquitto.conf`:
   ```
   autosave_interval 300    # Save every 5 minutes
   autosave_on_changes false # Disable immediate saves
   ```

3. **Optimize Docker resources**:
   ```yaml
   # In docker-compose.yml
   deploy:
     resources:
       limits:
         memory: 2G
         cpus: '2.0'
   ```

## 🔄 Maintenance

### Regular Tasks

1. **Monitor disk space:**
   ```powershell
   Get-ChildItem data -Recurse | Measure-Object -Property Length -Sum
   ```

2. **Clean old logs:**
   ```powershell
   # Rotate logs (built into Docker logging)
   docker-compose restart mosquitto
   ```

3. **Update broker:**
   ```powershell
   # Backup first
   .\backup.ps1 -BackupName "before-update"
   
   # Update image
   docker-compose pull
   docker-compose up -d
   ```

4. **Certificate renewal:**
   ```powershell
   # Check expiry
   .\manage-ssl.ps1 status
   
   # Renew if needed
   .\manage-ssl.ps1 renew
   ```

## 📈 Scaling Considerations

### Clustering (Bridge Configuration)
For multi-broker setups, configure bridges in `mosquitto.conf`:
```
connection bridge-01
address remote-broker:1883
topic sensors/# out 0
topic actuators/# in 0
```

### Load Balancing
Use a load balancer (nginx, HAProxy) to distribute connections across multiple broker instances.

### Database Integration
Consider using MQTT-to-database bridges for long-term data storage and analytics.

## 🛡️ Security Best Practices

1. **Use strong passwords** - Generated automatically by scripts
2. **Enable SSL/TLS** - For production deployments
3. **Implement ACLs** - Restrict topic access per user
4. **Regular backups** - Automated and tested
5. **Monitor connections** - Watch for unusual activity
6. **Update regularly** - Keep broker and Docker images current
7. **Network security** - Use firewalls and VPNs
8. **Certificate management** - Regular renewal and monitoring

## 📞 Support & Resources

### MQTT Client Testing Tools
- **MQTT Explorer** - GUI client for testing
- **mosquitto_pub/sub** - Command-line tools
- **MQTT.fx** - Java-based client
- **Postman** - REST client with MQTT support

### Useful Commands
```powershell
# Test publish
docker run --rm -it --network mqtt-network eclipse-mosquitto:2.0.18 mosquitto_pub -h mosquitto -t "test/topic" -m "Hello World" -u username -P password

# Test subscribe
docker run --rm -it --network mqtt-network eclipse-mosquitto:2.0.18 mosquitto_sub -h mosquitto -t "test/topic" -u username -P password
```

### Documentation Links
- [Eclipse Mosquitto Documentation](https://mosquitto.org/documentation/)
- [MQTT Protocol Specification](https://mqtt.org/mqtt-specification/)
- [Docker Compose Reference](https://docs.docker.com/compose/)

---

## 📝 Version History

- **v1.0** - Initial production setup with authentication, SSL, backups
- **v1.1** - Added user management and SSL certificate tools
- **v1.2** - Enhanced monitoring and health checks
- **v1.3** - Performance optimizations and clustering support

---

*This MQTT setup is designed for production use with enterprise-grade features including security, persistence, monitoring, and automated management tools.*
