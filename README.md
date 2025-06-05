# 🚀 SCP File Transfer Manager v3.0.0                                                                                                                                                                               
## Program developed by Gustavo Wydler Azuaga - 2025-06-03

![SCP Manager](https://img.shields.io/badge/Version-3.0.0-blue.svg) ![Bash](https://img.shields.io/badge/Language-Bash-green.svg) 

An advanced interactive SCP file transfer utility with comprehensive debugging and logging capabilities. This powerful bash script provides a user-friendly interface for secure file transfers between local and remote systems with extensive monitoring and analysis features.

## 🚀 Key Features

### Core Functionality
- **Interactive SSH Connection Management** - Save, manage, and quickly reconnect to multiple remote hosts
- **Advanced Remote Directory Navigation** - Browse and explore remote directories with detailed file listings
- **Bidirectional File Transfers** - Upload and download files with progress tracking and error analysis
- **Multiple Authentication Methods** - SSH keys, password authentication, and automatic key detection
- **Enhanced Transfer Modes** - Standard transfers, quick transfers, and batch operations

### Version 3.0.0 New Features
- **Comprehensive Logging System** - 11 advanced log analysis and search options
- **Intelligent Color-Coded Debug Messages** - Red for errors, yellow for warnings, green for success
- **Real-Time Debug/Verbose Status Indicators** - Visual status circles in main menu
- **Advanced Transfer Analysis** - Success/failure classification with detailed statistics
- **Enhanced Command Display** - Tree-like file path formatting for better readability
- **Toggleable Debug Modes** - Independent control for different operation types
- **Export Functionality** - Generate detailed analysis reports and statistics
- **Improved Error Detection** - Advanced error classification and pattern recognition

## 🛠️ Installation

1. **Download the script according to the desired version:**
   ```bash
   wget https://github.com/username/scp-manager/raw/main/(scp_manager_version_file)
   chmod +x (scp_manager_version_file)
   ```

2. **Run the script:**
   ```bash
   ./(scp_manager_version_file)
   ```

## 📊 Advanced Debugging & Logging System

### Command Line Debug Options
```bash
# Basic debugging
./scp_manager.sh --debug              # Enable comprehensive debug output
./scp_manager.sh --verbose            # Enable verbose mode

# Specific operation debugging
./scp_manager.sh --verbose-ssh        # SSH-specific verbose output
./scp_manager.sh --verbose-scp        # SCP-specific verbose output with analysis
./scp_manager.sh --verbose-json       # JSON operations debugging
./scp_manager.sh --verbose-file       # File operations debugging
./scp_manager.sh --verbose-network    # Network operations debugging

# Advanced debugging
./scp_manager.sh --debug-functions    # Function entry/exit tracing
./scp_manager.sh --debug-variables    # Variable tracking and validation
./scp_manager.sh --debug-commands     # Command execution logging
./scp_manager.sh --debug-all          # Enable all debugging modes
```

### Comprehensive Logging Menu (Option 12)

The advanced logging system provides 11 powerful analysis options:

1. **View Recent Logs** - Last 50 entries with intelligent color coding
2. **View Full Log** - Complete log with pagination support using `less`
3. **Search by Section** - Filter by operation type (SSH, SCP, FILE, NET, JSON)
4. **Search by Regex** - Advanced pattern matching with helpful examples
5. **Filter by Time** - Time-based filtering with flexible date/time patterns
6. **Error Analysis** - Comprehensive error statistics and recent error display
7. **Transfer Analysis** - SCP transfer patterns, success rates, and detailed statistics
8. **Connection Analysis** - SSH connection patterns and authentication tracking
9. **Clear Debug Log** - Safe log clearing with confirmation prompts
10. **Export Analysis** - Generate detailed analysis reports with comprehensive statistics
11. **Back to Main Menu** - Return to main menu

### Visual Status Indicators

The main menu displays real-time debug/verbose status with colored indicators:
- **Green circles (●)** - Mode enabled
- **Red circles (●)** - Mode disabled
- **Organized layout** - Pipe-separated display for clarity

Example display:
```
🛠️ Debug & Verbose Status:
| General Verbose: ● | SSH: ● | SCP: ● | JSON: ● | FILE: ● | NET: ● |
| General Debug: ● | Functions: ● | Variables: ● | Commands: ● |
```

## 🔍 Color-Coded Debug Messages

The system uses intelligent color coding throughout:
- **🔴 Red**: Errors, failures, and critical issues
- **🟡 Yellow**: Warnings, partial successes, and cautions
- **🟢 Green**: Successful operations and confirmations
- **🔵 Cyan**: SSH-related operations and information
- **🟣 Purple**: Function tracing and authentication details
- **⚪ White**: File operations and general information

## 📁 File Structure & Locations

```
~/.scp_manager/
├── debug.log                          # Comprehensive debug log file
├── connections.json                   # Saved connection profiles
├── saved_paths.json                  # Saved upload/download paths
└── log_analysis_YYYYMMDD_HHMMSS.txt  # Exported analysis reports
```

## 🔧 Enhanced Transfer Features

### Advanced SCP Command Construction
- **Enhanced parameter handling** with validation
- **Transfer type detection** (upload/download)
- **Progress monitoring** with real-time feedback
- **Error classification** and detailed analysis
- **Native SCP output preservation** with proper TTY handling

### Transfer Analysis Capabilities
- **Success/Failure Classification** - Accurate transfer result detection
- **Partial Transfer Detection** - Identify incomplete operations
- **Error Count Tracking** - Real-time error monitoring
- **Statistical Analysis** - Transfer patterns and success rates
- **Performance Metrics** - Transfer speed and efficiency tracking

### Enhanced Command Preview
```
🔍 Command that will be executed:
├── Command: scp
├── Options: -P 22 -o ConnectTimeout=10 -o StrictHostKeyChecking=no
├── Authentication: SSH Key (/path/to/key)
├── Source Files:
│   ├── /local/path/file1.txt
│   ├── /local/path/file2.txt
│   └── /local/path/directory/
└── Destination: user@host:/remote/path/
```

## 📋 Menu System

### Main Menu Options
1. **Setup Connection** - Configure SSH connection to remote host
2. **Manage Connections** - View, edit, and manage saved connections
3. **Manage Saved Paths** - View, edit, and manage saved upload/download paths
4. **Browse Remote Files** - Navigate and explore remote directories
5. **Upload Files** - Transfer files from local to remote
6. **Download Files** - Transfer files from remote to local
7. **Manage Transfers** - Create, edit, and manage saved transfer configurations
8. **Folder Navigator** - Interactive local folder navigation with multiple views
9. **Remote Navigator** - Interactive remote folder navigation with multiple views
10. **Quick Transfer** - Fast file transfer with current settings
11. **Settings** - Configure application settings and debug modes
12. **Logging** - Comprehensive log viewing, searching, and analysis
13. **Help** - Show detailed help and usage information
14. **Exit** - Quit the application

## 🚀 Quick Start Guide

1. **Launch the application:**
   ```bash
   ./scp_manager.sh
   ```

2. **Setup your first connection:**
   - Select option 1 (Setup Connection)
   - Enter host, username, and authentication method
   - Test the connection

3. **Enable debugging (optional):**
   ```bash
   ./scp_manager.sh --debug-all
   ```

4. **Perform file transfers:**
   - Use option 5 for uploads or option 6 for downloads
   - Select files and destinations interactively

5. **Monitor and analyze:**
   - Use option 12 (Logging) to view detailed logs
   - Export analysis reports for detailed statistics

## 🔬 Advanced Usage Examples

### Debugging SSH Connection Issues
```bash
# Enable SSH-specific debugging
./scp_manager.sh --verbose-ssh --debug-functions

# Then use the Logging menu to search for SSH errors:
# Option 12 → Option 3 → Option 1 (SSH)
```

### Analyzing Transfer Performance
```bash
# Enable SCP debugging with full analysis
./scp_manager.sh --verbose-scp --debug-all

# Use Transfer Analysis in Logging menu:
# Option 12 → Option 7 (Transfer Analysis)
```

### Exporting Detailed Reports
```bash
# Run with comprehensive debugging
./scp_manager.sh --debug-all

# After operations, export analysis:
# Option 12 → Option 10 (Export Analysis)
```

## 🔍 Log Analysis Examples

### Search for Connection Errors
```
Menu → Logging → Search by Regex
Pattern: "Connection.*failed|Permission denied|refused"
```

### Find Transfer Statistics
```
Menu → Logging → Transfer Analysis
View success rates, error patterns, and performance metrics
```

### Time-Based Filtering
```
Menu → Logging → Filter by Time
Pattern: "20:30" (after 8:30 PM)
Pattern: "2025-06-04" (specific date)
```

## 🛡️ Security Features

- **SSH Key Validation** - Comprehensive key file verification
- **Secure Password Handling** - No password storage or logging
- **Connection Timeout Management** - Configurable timeout settings
- **Strict Host Key Checking** - Optional for enhanced security
- **Debug Log Security** - No sensitive information in logs

## 🔧 Configuration Options

### Command Line Arguments
```bash
-h, --help              Show comprehensive help message
-t, --timeout SEC       Set SSH connection timeout (default: 10)
--version              Display detailed version information
```

### Debug Environment Variables
The script respects standard SSH environment variables and creates its own debug configuration.

## 🐛 Troubleshooting

### Common Issues and Solutions

1. **SSH Connection Failures**
   - Enable `--verbose-ssh` for detailed connection debugging
   - Check the Connection Analysis in Logging menu
   - Verify SSH key permissions and paths

2. **Transfer Errors**
   - Use `--verbose-scp` for detailed transfer debugging
   - Check Transfer Analysis for patterns
   - Verify file permissions and disk space

3. **Permission Issues**
   - Review Error Analysis in Logging menu
   - Check file/directory permissions
   - Verify SSH key ownership and permissions

4. **Debug Log Issues**
   - Check `~/.scp_manager/debug.log` permissions
   - Use Clear Debug Log option if file becomes too large
   - Export analysis before clearing for record keeping

## 🔄 Version History

### Version 3.0.0 (Current)
- **🆕 Comprehensive Logging System** - 11 advanced analysis options
- **🆕 Intelligent Color-Coded Messages** - Context-aware color coding
- **🆕 Real-Time Status Indicators** - Visual debug/verbose mode status
- **🆕 Advanced Transfer Analysis** - Success/failure classification
- **🆕 Enhanced Command Display** - Tree-like formatting
- **🆕 Export Functionality** - Detailed analysis reports
- **🆕 Improved Error Detection** - Advanced classification system

### Version 2.0.0
- Interactive menu system
- Saved connection profiles
- Remote directory browsing
- Enhanced file transfer capabilities
- Basic debugging features

### Version 1.0.0
- Basic SCP transfer functionality
- Simple command-line interface
- SSH key support

## 📞 Support

For support and questions:
- Check the built-in help system (Option 13)
- Review the comprehensive logging system (Option 12)
- Use debug modes for detailed troubleshooting
- Export analysis reports for detailed diagnostics


------------------------------------------------------------------------------------


