# 🚀 SCP File Transfer Manager v2.0.0                                                                                                                                                                               
## Program developed by Gustavo Wydler Azuaga - 2025-06-03
                                                                                        

- Comprehensive.
- Interactive bash-based SCP file transfer manager
- Advanced features for efficient remote file operations.

## Overview

The SCP Manager is a feature-rich command-line utility that simplifies and enhances SCP (Secure Copy Protocol) file transfers between local and remote systems. Built entirely in bash, it provides an intuitive menu-driven interface with robust connection management, transfer validation, and progress monitoring.

## Key Features

### 🔐 Connection Management
- **Multiple Connection Support**: Store unlimited SSH connections with unique random IDs (1-1000)
- **Dual Authentication Methods**: SSH key-based and password authentication
- **Connection Validation**: Test connections before transfers with persistent validation tracking
- **Last Validation Tracking**: Automatic recording of connection test results with timestamps

### 📁 Advanced File Transfer Options
- **Transfer Type Selection**: 
  - Single file transfer
  - Whole directory transfer (with `-r` flag)
  - Directory contents transfer (`/path/to/dir/*`)
  - Multiple files transfer (space-separated)
- **Bidirectional Operations**: Both upload and download support
- **Wildcard Support**: Handle complex path patterns and wildcards safely
- **Transfer Type Detection**: Automatic detection for saved transfers

### 🎯 Navigation & Path Management
- **Interactive Local Navigation**: Browse local filesystem with up/down/goto commands
- **Remote Folder Navigator**: Browse remote directories with connection testing
- **Saved Paths**: Store frequently used local and remote paths
- **Path Validation**: Verify source and destination paths before transfer

### 📊 Transfer Monitoring & Analysis
- **Live Progress Display**: Native SCP progress bars with real-time transfer rates
- **Intelligent Transfer Analysis**: 
  - ✅ **Success** (GREEN): All files transferred successfully
  - ⚠️ **Partial** (YELLOW): Some files succeeded, some failed
  - ❌ **Failed** (RED): Transfer failed completely
- **Detailed Logging**: Comprehensive transfer logs with error categorization
- **Exit Code Analysis**: Proper interpretation of SCP exit codes

### 💾 Persistent Storage
- **JSON Configuration**: All settings stored in JSON format
- **Connection Persistence**: Saved connections with validation history
- **Transfer History**: Track previous transfers and their outcomes
- **Settings Management**: Configurable options and preferences

## Installation

1. **Download the script**:
   ```bash
   curl -o ~/scp_manager.sh https://raw.githubusercontent.com/your-repo/scp_manager.sh
   chmod +x ~/scp_manager.sh
   ```

2. **Create configuration directory**:
   ```bash
   mkdir -p ~/.scp_manager
   ```

3. **Install dependencies** (if not already installed):
   ```bash
   # For password authentication (optional)
   sudo apt-get install sshpass  # Ubuntu/Debian
   sudo yum install sshpass      # CentOS/RHEL
   
   # For JSON processing
   sudo apt-get install jq       # Ubuntu/Debian
   sudo yum install jq           # CentOS/RHEL
   ```

## Usage

### Starting the Manager
```bash
./scp_manager.sh
```

### Main Menu Options

1. **Quick Transfer**: Immediate file transfer with connection setup
2. **Manage Connections**: Add, edit, delete, and test SSH connections
3. **Manage Saved Paths**: Store and organize frequently used paths
4. **Execute Saved Transfers**: Run pre-configured transfer operations
5. **Settings**: Configure manager preferences and options

### Connection Setup

#### SSH Key Authentication
```
Host: your-server.com
Username: your-username
SSH Key Path: /home/user/.ssh/id_rsa
```

#### Password Authentication
```
Host: your-server.com
Username: your-username
Authentication: Password (will prompt securely)
```

### Transfer Types

#### Single File Transfer
- **Upload**: `./local-file.txt` → `user@host:/remote/path/file.txt`
- **Download**: `user@host:/remote/file.txt` → `./local-directory/`

#### Directory Transfer
- **Whole Directory**: Transfers directory and all contents recursively
- **Directory Contents**: Transfers only the contents of a directory (using `/*`)

#### Multiple Files
- **Space-separated**: `file1.txt file2.txt file3.txt`
- **Wildcard patterns**: `*.txt`, `data_*.csv`

## Configuration Files

### ~/.scp_manager/connections.json
Stores SSH connection configurations:
```json
[
  {
    "id": 42,
    "host": "server.example.com",
    "username": "admin",
    "ssh_key": "/home/user/.ssh/id_rsa",
    "auth_method": "key"
  },
  {
    "id": 156,
    "host": "backup.example.com", 
    "username": "backup",
    "auth_method": "password"
  }
]
```

### ~/.scp_manager/saved_paths.json
Stores frequently used paths:
```json
{
  "local": [
    "/home/user/documents",
    "/var/log/application"
  ],
  "remote": [
    "/opt/application/config",
    "/backup/daily"
  ]
}
```

### ~/.scp_manager/last_validation.json
Tracks connection validation results:
```json
{
  "connection_id": 42,
  "host": "server.example.com",
  "validation_time": "2024-01-15 14:30:22",
  "validation_success": true,
  "validation_details": "SSH connection successful"
}
```

## Advanced Features

### Transfer Type Detection
The manager automatically detects transfer types for saved transfers:
- Analyzes source and destination paths
- Determines if `-r` flag is needed for directories
- Handles wildcard patterns safely
- Prevents "ambiguous target" errors

### Connection Validation System
- **Pre-transfer Testing**: Validates connections before attempting transfers
- **Authentication Method Aware**: Different validation for SSH keys vs passwords
- **Persistent Tracking**: Remembers last validation results
- **Smart Retry Logic**: Handles temporary connection issues

### Enhanced SCP Command Building
```bash
# Example generated commands:
scp -r /local/directory/ user@host:/remote/path/          # Directory transfer
scp /local/file.txt user@host:/remote/path/file.txt       # Single file
scp -i ~/.ssh/key user@host:/remote/*.txt /local/path/    # Key-based with wildcards
```

### Live Progress Monitoring
Uses `script` command to capture native SCP output:
- Real-time progress bars
- Transfer speed indicators
- File-by-file progress for multiple transfers
- Proper ANSI color handling

## Error Handling & Troubleshooting

### Common Issues

#### Permission Denied
```
Error: Permission denied (publickey,password)
Solution: Check SSH key permissions or password authentication setup
```

#### Connection Timeout
```
Error: Connection timed out
Solution: Verify host connectivity and firewall settings
```

#### File Not Found
```
Error: No such file or directory
Solution: Verify source path exists and is accessible
```

### Transfer Status Indicators

- 🟢 **GREEN Success**: All files transferred successfully (exit code 0)
- 🟡 **YELLOW Partial**: Some files succeeded, some failed (exit code ≠ 0, but some 100% transfers)
- 🔴 **RED Failed**: Transfer failed completely (exit code ≠ 0, no successful transfers)

### Debug Mode
Enable verbose output for troubleshooting:
```bash
DEBUG=1 ./scp_manager.sh
```

## Security Considerations

### SSH Key Security
- Store private keys with proper permissions (600)
- Use passphrase-protected keys when possible
- Regularly rotate SSH keys

### Password Authentication
- Passwords are prompted securely and not stored
- Uses `sshpass` for automated password entry
- Consider using SSH keys for enhanced security

### File Permissions
- Configuration files created with restrictive permissions
- Temporary files cleaned up automatically
- No sensitive data logged in plain text

## Version History

### v2.0.0 (Current)
- **Enhanced Transfer Types**: Comprehensive transfer type selection and detection
- **Live Progress Display**: Native SCP progress bars with real-time monitoring
- **Intelligent Analysis**: Accurate success/partial/failure detection with color coding
- **Wildcard Support**: Safe handling of wildcard patterns in saved transfers
- **Connection Validation**: Robust testing system with persistent tracking
- **Random Connection IDs**: Unique identification system (1-1000) for unlimited connections
- **Password Authentication**: Secure password prompting with sshpass integration
- **Interactive Navigation**: Fixed hanging issues with local/remote folder browsing
- **Enhanced Command Building**: Intelligent SCP command construction with transfer type detection

### v1.0.0
- Initial release with basic SCP transfer functionality
- Connection management and saved paths
- Simple menu-driven interface

## Contributing

Contributions are welcome! Please ensure:
- Bash compatibility across different systems
- Comprehensive error handling
- Consistent code style and documentation
- Thorough testing of new features

## License

This project is open source. Use and modify freely while maintaining attribution.

## Support

For issues, feature requests, or contributions:
- Check the troubleshooting section above
- Review configuration file formats
- Test with debug mode enabled
- Verify dependencies are installed correctly


------------------------------------------------------------------------------------


