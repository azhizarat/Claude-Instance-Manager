# Claude Instance Manager (CIM) Implementation Plan

**Goal:** Build a native Windows PowerShell + WPF (XAML) GUI application, standalone `.exe` wrapper, and `claude://` protocol router to manage multiple isolated Claude Desktop instances, migrate/copy sessions across accounts, route `claude://` login links, and manage updates/Dispatch/backups.

**Architecture:** Modular PowerShell 5.1/7+ backend in `src/` (`Core-Instances.ps1`, `Core-Sessions.ps1`, `Core-ProtocolRouter.ps1`, `Core-SettingsBackup.ps1`) paired with a main WPF Dark Mode GUI (`Claude-Instance-Manager.ps1`), a standalone `claude://` protocol handler popup (`src/Protocol-Popup.ps1` + `src/Launch-ProtocolPopup.vbs`), and a self-extracting native C# WinExe (`Claude-Instance-Manager.exe`).

**Tech Stack:** PowerShell 5.1+, C# (.NET Framework 4.x `csc.exe`), WPF (`PresentationFramework`, `PresentationCore`, `WindowsBase`), `System.Drawing` (multi-size PNG `.ico` generation), Win32 P/Invoke (`Kernel32.CreateHardLink`, `Shlwapi.AssocQueryString`), `System.IO.Compression.FileSystem` (ZIP backups).
