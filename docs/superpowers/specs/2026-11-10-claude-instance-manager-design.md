# Claude Instance Manager (CIM) — Design Specification

## 1. Overview & Purpose
**Claude Instance Manager (CIM)** is a native Windows GUI application built with PowerShell 5.1/7+ and WPF (XAML) with zero external dependencies, compiled into a standalone Windows executable (`Claude-Instance-Manager.exe`). It manages multiple isolated instances of the MSIX-packaged Claude Desktop application on Windows (`Claude_pzs8sxrjxfjjc`), automates NTFS hardlink sharing of heavy read-only assets (~8.8 GB per instance), routes `claude://` deep links (OAuth login & MCP callbacks) to the appropriate instance, migrates/clones Claude Code & Cowork sessions across accounts, and controls auto-update, Gateway (`1p`/`3p`), and Dispatch (`sessions-bridge`) settings.

## 2. Target Paths & Environment
- **Primary Claude Data Dir:** `%LOCALAPPDATA%\Claude-Data\claude_pzs8sxrjxfjjc` (fallback: `%LOCALAPPDATA%\Packages\Claude_pzs8sxrjxfjjc\LocalCache\Roaming\Claude`)
- **Secondary Instances Root:** `%LOCALAPPDATA%\Claude-Instances\`
- **Managed Policy Dir (`Claude-3p`):** `%LOCALAPPDATA%\Claude-3p\configLibrary\00000000-0000-4000-8000-000000000001.json` + `_meta.json`
- **CIM Metadata & State File:** `%LOCALAPPDATA%\Claude-Instances\cim-state.json`
- **Backups Directory:** `%LOCALAPPDATA%\Claude-Instances\Backups\`
- **Icons Directory:** `%LOCALAPPDATA%\Claude-Instances\icons\`

## 3. Architecture & File Structure
```text
Claude-Instance-Manager\
├── Claude-Instance-Manager.ps1       # Main WPF GUI entry point
├── Launch-CIM.vbs                    # Hidden-console WScript launcher for the GUI
├── build.ps1                         # Native C# compiler script producing standalone .exe
├── src\
│   ├── Core-Instances.ps1            # Discovery, creation, hardlink sync, process/RAM/VM monitor, icon & shortcut generator
│   ├── Core-Sessions.ps1             # Project/Session discovery, copy/move across accounts, UUID remapping, folder permissions
│   ├── Core-ProtocolRouter.ps1       # Registry inspection/override via AssocQueryString & claude:// deep-link dispatcher
│   ├── Core-SettingsBackup.ps1       # Auto-update modes, 1p anti-gateway fix, Dispatch toggle, MCP/Config sync, ZIP backup/restore
│   └── Protocol-Popup.ps1            # Standalone lightweight WPF popup invoked by Windows when claude:// is clicked
└── tests\
    └── CIM.Tests.ps1                 # Automated verification script testing core modules
```
