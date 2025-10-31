# =================================================================
# MQTT User Management Script
# =================================================================

param(
    [ValidateSet("add", "remove", "list", "change-password")]
    [string]$Action = "",
    
    [string]$Username = "",
    [string]$Password = "",
    [switch]$Force = $false
)

Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host "MQTT User Management Script" -ForegroundColor Cyan
Write-Host "==================================================================" -ForegroundColor Cyan

# Show help if no action provided
if (-not $Action) {
    Write-Host "Usage: .\manage-users.ps1 <action> [options]" -ForegroundColor White
    Write-Host ""
    Write-Host "Actions:" -ForegroundColor Cyan
    Write-Host "  add             Add a new user" -ForegroundColor White
    Write-Host "  remove          Remove an existing user" -ForegroundColor White
    Write-Host "  list            List all users and their permissions" -ForegroundColor White
    Write-Host "  change-password Change password for existing user" -ForegroundColor White
    Write-Host ""
    Write-Host "Parameters:" -ForegroundColor Cyan
    Write-Host "  -Username   Username to add/remove/modify" -ForegroundColor White
    Write-Host "  -Password   Password for user (auto-generated if not provided)" -ForegroundColor White
    Write-Host "  -Force      Skip confirmation prompts" -ForegroundColor White
    Write-Host ""
    Write-Host "Examples:" -ForegroundColor Cyan
    Write-Host "  .\manage-users.ps1 list" -ForegroundColor Gray
    Write-Host "  .\manage-users.ps1 add -Username 'sensor01'" -ForegroundColor Gray
    Write-Host "  .\manage-users.ps1 add -Username 'device01' -Password 'mypassword'" -ForegroundColor Gray
    Write-Host "  .\manage-users.ps1 remove -Username 'olduser' -Force" -ForegroundColor Gray
    Write-Host "  .\manage-users.ps1 change-password -Username 'user01'" -ForegroundColor Gray
    Write-Host ""
    Write-Host "==================================================================" -ForegroundColor Cyan
    exit 0
}

# Change to parent directory (mqtt folder)
Set-Location ..

# Check if password file exists
if (-not (Test-Path "config\passwords.txt")) {
    Write-Host "Password file not found!" -ForegroundColor Red
    Write-Host "Run .\management\install.ps1 first to set up the MQTT broker." -ForegroundColor Yellow
    exit 1
}

# Function to restart MQTT broker
function Restart-MQTTBroker {
    Write-Host "Restarting MQTT broker to apply changes..." -ForegroundColor Yellow
    docker-compose restart mosquitto
    Start-Sleep -Seconds 5
    Write-Host "MQTT broker restarted" -ForegroundColor Green
}

# Function to generate secure password
function Generate-SecurePassword {
    return -join ((65..90) + (97..122) + (48..57) + (33,35,36,37,38,42,43,45,61,63,64) | Get-Random -Count 16 | ForEach-Object {[char]$_})
}

switch ($Action) {
    "add" {
        if (-not $Username) {
            $Username = Read-Host "Enter username"
        }
        
        if (-not $Username) {
            Write-Host "Username is required!" -ForegroundColor Red
            exit 1
        }
        
        # Check if user already exists
        $ExistingUsers = Get-Content "config\passwords.txt" | ForEach-Object { $_.Split(':')[0] }
        if ($ExistingUsers -contains $Username -and -not $Force) {
            Write-Host "User '$Username' already exists!" -ForegroundColor Red
            Write-Host "Use -Force to overwrite or 'change-password' action to update password." -ForegroundColor Yellow
            exit 1
        }
        
        if (-not $Password) {
            $Password = Generate-SecurePassword
            Write-Host "Generated secure password for user '$Username'" -ForegroundColor Green
        }
        
        Write-Host "Adding user '$Username'..." -ForegroundColor White
        
        # Use mosquitto_passwd to add user
        docker run --rm -v "${PWD}\config:/mosquitto/config" eclipse-mosquitto:2.0.22 mosquitto_passwd -b /mosquitto/config/passwords.txt $Username $Password
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "User '$Username' added successfully" -ForegroundColor Green
            Write-Host "Password: $Password" -ForegroundColor Yellow
            Write-Host "  (Save this password - it won't be shown again)" -ForegroundColor Gray
            
            # Ask for ACL permissions
            Write-Host ""
            Write-Host "ACL Permissions for user '$Username':" -ForegroundColor Cyan
            Write-Host "1. Full access (readwrite #)" -ForegroundColor White
            Write-Host "2. User-specific topics only (readwrite user/$Username/+)" -ForegroundColor White
            Write-Host "3. Read-only access (read #)" -ForegroundColor White
            Write-Host "4. Custom permissions (you specify)" -ForegroundColor White
            Write-Host "5. No ACL entry (inherit pattern permissions only)" -ForegroundColor White
            
            $AclChoice = Read-Host "Choose ACL option (1-5)"
            
            $AclContent = Get-Content "config\acl.txt" -Raw
            $NewUserAcl = "`n# User: $Username`nuser $Username`n"
            
            switch ($AclChoice) {
                "1" {
                    $NewUserAcl += "topic readwrite #`n"
                    Write-Host "Added full access permissions for user '$Username'" -ForegroundColor Green
                }
                "2" {
                    $NewUserAcl += "topic readwrite user/$Username/+`n"
                    Write-Host "Added user-specific topic permissions for user '$Username'" -ForegroundColor Green
                }
                "3" {
                    $NewUserAcl += "topic read #`n"
                    Write-Host "Added read-only permissions for user '$Username'" -ForegroundColor Green
                }
                "4" {
                    Write-Host "Enter custom topic permissions (e.g., 'readwrite sensors/+'):" -ForegroundColor White
                    $CustomPermission = Read-Host "Topic permission"
                    if ($CustomPermission) {
                        $NewUserAcl += "topic $CustomPermission`n"
                        Write-Host "Added custom permissions for user '$Username': $CustomPermission" -ForegroundColor Green
                    } else {
                        $NewUserAcl += "topic readwrite user/$Username/+`n"
                        Write-Host "No custom permission provided, using user-specific topics" -ForegroundColor Yellow
                    }
                }
                "5" {
                    $NewUserAcl = "`n# User: $Username (no specific ACL - inherits patterns)`n"
                    Write-Host "No ACL entry added for user '$Username' (will inherit pattern permissions)" -ForegroundColor Yellow
                }
                default {
                    $NewUserAcl += "topic readwrite user/$Username/+`n"
                    Write-Host "Invalid choice, using default user-specific topic permissions" -ForegroundColor Yellow
                }
            }
            
            $AclContent += $NewUserAcl
            Set-Content -Path "config\acl.txt" -Value $AclContent
            
            Restart-MQTTBroker
        } else {
            Write-Host "Failed to add user '$Username'" -ForegroundColor Red
            exit 1
        }
    }
    
    "remove" {
        if (-not $Username) {
            $Username = Read-Host "Enter username to remove"
        }
        
        if (-not $Username) {
            Write-Host "Username is required!" -ForegroundColor Red
            exit 1
        }
        
        # Check if user exists
        $ExistingUsers = Get-Content "config\passwords.txt" | ForEach-Object { $_.Split(':')[0] }
        if ($ExistingUsers -notcontains $Username) {
            Write-Host "User '$Username' not found!" -ForegroundColor Red
            exit 1
        }
        
        if (-not $Force) {
            $Confirmation = Read-Host "Remove user '$Username'? (y/n)"
            if ($Confirmation -ne "y" -and $Confirmation -ne "Y") {
                Write-Host "Operation cancelled." -ForegroundColor Yellow
                exit 0
            }
        }
        
        Write-Host "Removing user '$Username'..." -ForegroundColor White
        
        # Use mosquitto_passwd to remove user
        docker run --rm -v "${PWD}\config:/mosquitto/config" eclipse-mosquitto:2.0.22 mosquitto_passwd -D /mosquitto/config/passwords.txt $Username
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "User '$Username' removed from password file" -ForegroundColor Green
            
            # Remove user from ACL file
            $AclContent = Get-Content "config\acl.txt"
            $FilteredAcl = @()
            $SkipNext = $false
            
            for ($i = 0; $i -lt $AclContent.Length; $i++) {
                $line = $AclContent[$i]
                
                if ($line -match "^# User: $Username$") {
                    $SkipNext = $true
                    continue
                }
                
                if ($SkipNext -and ($line -match "^user $Username$" -or $line -match "^topic .* user/$Username/")) {
                    continue
                }
                
                if ($SkipNext -and ($line -eq "" -or $line -match "^#" -or $line -match "^user " -or $line -match "^pattern ")) {
                    $SkipNext = $false
                }
                
                if (-not $SkipNext) {
                    $FilteredAcl += $line
                }
            }
            
            Set-Content -Path "config\acl.txt" -Value $FilteredAcl
            Write-Host "Removed ACL permissions for user '$Username'" -ForegroundColor Green
            
            Restart-MQTTBroker
        } else {
            Write-Host "Failed to remove user '$Username'" -ForegroundColor Red
            exit 1
        }
    }
    
    "change-password" {
        if (-not $Username) {
            $Username = Read-Host "Enter username"
        }
        
        if (-not $Username) {
            Write-Host "Username is required!" -ForegroundColor Red
            exit 1
        }
        
        # Check if user exists
        $ExistingUsers = Get-Content "config\passwords.txt" | ForEach-Object { $_.Split(':')[0] }
        if ($ExistingUsers -notcontains $Username) {
            Write-Host "User '$Username' not found!" -ForegroundColor Red
            exit 1
        }
        
        if (-not $Password) {
            $Password = Generate-SecurePassword
            Write-Host "Generated new secure password for user '$Username'" -ForegroundColor Green
        }
        
        Write-Host "Changing password for user '$Username'..." -ForegroundColor White
        
        # Use mosquitto_passwd to change password
        docker run --rm -v "${PWD}\config:/mosquitto/config" eclipse-mosquitto:2.0.22 mosquitto_passwd -b /mosquitto/config/passwords.txt $Username $Password
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "Password changed for user '$Username'" -ForegroundColor Green
            Write-Host "New Password: $Password" -ForegroundColor Yellow
            Write-Host "  (Save this password - it won't be shown again)" -ForegroundColor Gray
            
            Restart-MQTTBroker
        } else {
            Write-Host "Failed to change password for user '$Username'" -ForegroundColor Red
            exit 1
        }
    }
    
    "list" {
        Write-Host "Current MQTT users:" -ForegroundColor White
        Write-Host "==================" -ForegroundColor Gray
        
        $Users = Get-Content "config\passwords.txt" | ForEach-Object { $_.Split(':')[0] }
        
        if ($Users.Count -eq 0) {
            Write-Host "No users found." -ForegroundColor Yellow
        } else {
            foreach ($User in $Users) {
                Write-Host "  • $User" -ForegroundColor Green
            }
            Write-Host ""
            Write-Host "Total users: $($Users.Count)" -ForegroundColor Cyan
        }
        
        # Show ACL summary
        Write-Host ""
        Write-Host "ACL Configuration:" -ForegroundColor White
        Write-Host "==================" -ForegroundColor Gray
        
        $AclContent = Get-Content "config\acl.txt"
        $UserPermissions = @{}
        $CurrentUser = ""
        
        foreach ($line in $AclContent) {
            if ($line -match "^user (.+)$") {
                $CurrentUser = $matches[1]
                $UserPermissions[$CurrentUser] = @()
            } elseif ($line -match "^topic (.+)$" -and $CurrentUser) {
                $UserPermissions[$CurrentUser] += $matches[1]
            }
        }
        
        foreach ($User in $UserPermissions.Keys) {
            Write-Host "  • $User" -ForegroundColor Green
            foreach ($Permission in $UserPermissions[$User]) {
                Write-Host "    - $Permission" -ForegroundColor Gray
            }
        }
    }
}

Write-Host ""
Write-Host "User management completed!" -ForegroundColor Green
Write-Host "==================================================================" -ForegroundColor Cyan

# Return to management directory
Set-Location management
