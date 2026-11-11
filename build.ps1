$ErrorActionPreference = "Stop"

$ProjectRoot = $PSScriptRoot
$DistDir = Join-Path $ProjectRoot "dist"
if (Test-Path $DistDir) { Remove-Item -Path $DistDir -Recurse -Force }
New-Item -ItemType Directory -Path $DistDir -Force | Out-Null

. (Join-Path $ProjectRoot "src\Core-Instances.ps1")

$IcoPath = Join-Path $DistDir "cim.ico"
New-ClaudeBadgeIcon -OutputIcoPath $IcoPath -BadgeText "CIM" -BadgeColorHex "#D97757"

$CsSource = @"
using System;
using System.Diagnostics;
using System.IO;
using System.Reflection;

[assembly: AssemblyTitle("Claude Instance Manager")]
[assembly: AssemblyDescription("Multi-Instance Manager, Session Migrator, and claude:// Router for Claude Desktop on Windows")]
[assembly: AssemblyProduct("Claude Instance Manager (CIM)")]
[assembly: AssemblyVersion("1.0.0.0")]
[assembly: AssemblyFileVersion("1.0.0.0")]

namespace ClaudeInstanceManager {
    public static class Program {
        private static readonly string[,] EmbeddedFiles = new string[,] {
            { "Claude-Instance-Manager.ps1", "Claude-Instance-Manager.ps1" },
            { "Launch-CIM.vbs",              "Launch-CIM.vbs" },
            { "Core-Instances.ps1",          "src\\Core-Instances.ps1" },
            { "Core-Sessions.ps1",           "src\\Core-Sessions.ps1" },
            { "Core-ProtocolRouter.ps1",     "src\\Core-ProtocolRouter.ps1" },
            { "Core-SettingsBackup.ps1",     "src\\Core-SettingsBackup.ps1" },
            { "Protocol-Popup.ps1",          "src\\Protocol-Popup.ps1" },
            { "Launch-ProtocolPopup.vbs",    "src\\Launch-ProtocolPopup.vbs" }
        };

        [STAThread]
        public static int Main(string[] args) {
            try {
                string exeDir = AppDomain.CurrentDomain.BaseDirectory;
                string localPs1 = Path.Combine(exeDir, "Claude-Instance-Manager.ps1");
                string localSrc = Path.Combine(exeDir, "src", "Core-Instances.ps1");

                string runtimeRoot = exeDir;
                if (!File.Exists(localPs1) || !File.Exists(localSrc)) {
                    runtimeRoot = Path.Combine(
                        Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
                        "Claude-Instances",
                        "Manager"
                    );
                    ExtractEmbeddedFiles(runtimeRoot);
                }

                string targetScript = Path.Combine(runtimeRoot, "Claude-Instance-Manager.ps1");
                string scriptArgs = "";

                if (args != null && args.Length > 0) {
                    if (args[0].StartsWith("claude://", StringComparison.OrdinalIgnoreCase)) {
                        targetScript = Path.Combine(runtimeRoot, "src", "Protocol-Popup.ps1");
                        scriptArgs = "-Url \"" + args[0].Replace("\"", "\\\"") + "\"";
                    } else {
                        scriptArgs = string.Join(" ", args);
                    }
                }

                var psi = new ProcessStartInfo {
                    FileName = "powershell.exe",
                    Arguments = "-NoProfile -ExecutionPolicy Bypass -STA -WindowStyle Hidden -File \"" + targetScript + "\" " + scriptArgs,
                    WorkingDirectory = runtimeRoot,
                    UseShellExecute = false,
                    CreateNoWindow = true
                };

                var proc = Process.Start(psi);
                if (args != null && args.Length > 0 && args[0].Equals("-CheckOnly", StringComparison.OrdinalIgnoreCase)) {
                    proc.WaitForExit();
                    return proc.ExitCode;
                }
                return 0;
            } catch (Exception ex) {
                System.Windows.Forms.MessageBox.Show(ex.Message, "Claude Instance Manager Error");
                return 1;
            }
        }

        private static void ExtractEmbeddedFiles(string targetRoot) {
            var asm = Assembly.GetExecutingAssembly();
            for (int i = 0; i < EmbeddedFiles.GetLength(0); i++) {
                string resName = EmbeddedFiles[i, 0];
                string relPath = EmbeddedFiles[i, 1];
                string fullDest = Path.Combine(targetRoot, relPath);
                string parent = Path.GetDirectoryName(fullDest);
                if (!Directory.Exists(parent)) {
                    Directory.CreateDirectory(parent);
                }
                using (Stream s = asm.GetManifestResourceStream(resName)) {
                    if (s == null) continue;
                    using (FileStream fs = new FileStream(fullDest, FileMode.Create, FileAccess.Write)) {
                        s.CopyTo(fs);
                    }
                }
            }
        }
    }
}
"@

$CsFile = Join-Path $DistDir "Launcher.cs"
[System.IO.File]::WriteAllText($CsFile, $CsSource, (New-Object System.Text.UTF8Encoding($false)))

$CscPath = "C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe"
$ExeOut = Join-Path $DistDir "Claude-Instance-Manager.exe"

$cscArgs = @(
    "/nologo",
    "/target:winexe",
    "/optimize+",
    "/out:$ExeOut",
    "/win32icon:$IcoPath",
    "/reference:System.Windows.Forms.dll",
    "/resource:`"$(Join-Path $ProjectRoot 'Claude-Instance-Manager.ps1')`",Claude-Instance-Manager.ps1",
    "/resource:`"$(Join-Path $ProjectRoot 'Launch-CIM.vbs')`",Launch-CIM.vbs",
    "/resource:`"$(Join-Path $ProjectRoot 'src\Core-Instances.ps1')`",Core-Instances.ps1",
    "/resource:`"$(Join-Path $ProjectRoot 'src\Core-Sessions.ps1')`",Core-Sessions.ps1",
    "/resource:`"$(Join-Path $ProjectRoot 'src\Core-ProtocolRouter.ps1')`",Core-ProtocolRouter.ps1",
    "/resource:`"$(Join-Path $ProjectRoot 'src\Core-SettingsBackup.ps1')`",Core-SettingsBackup.ps1",
    "/resource:`"$(Join-Path $ProjectRoot 'src\Protocol-Popup.ps1')`",Protocol-Popup.ps1",
    "/resource:`"$(Join-Path $ProjectRoot 'src\Launch-ProtocolPopup.vbs')`",Launch-ProtocolPopup.vbs",
    "`"$CsFile`""
)

& $CscPath @cscArgs
if ($LASTEXITCODE -ne 0 -or -not (Test-Path $ExeOut)) {
    throw "Compilation failed with exit code $LASTEXITCODE"
}

Remove-Item -Path $CsFile -Force -ErrorAction SilentlyContinue
Remove-Item -Path $IcoPath -Force -ErrorAction SilentlyContinue

# Also copy the compiled standalone .exe to project root for immediate use
Copy-Item -Path $ExeOut -Destination (Join-Path $ProjectRoot "Claude-Instance-Manager.exe") -Force

# Package Portable ZIP
$StageZipDir = Join-Path $DistDir "Claude-Instance-Manager-Portable"
New-Item -ItemType Directory -Path (Join-Path $StageZipDir "src") -Force | Out-Null
Copy-Item -Path $ExeOut -Destination (Join-Path $StageZipDir "Claude-Instance-Manager.exe") -Force
Copy-Item -Path (Join-Path $ProjectRoot "Claude-Instance-Manager.ps1") -Destination $StageZipDir -Force
Copy-Item -Path (Join-Path $ProjectRoot "Launch-CIM.vbs") -Destination $StageZipDir -Force
Copy-Item -Path (Join-Path $ProjectRoot "src\*") -Destination (Join-Path $StageZipDir "src") -Force
if (Test-Path (Join-Path $ProjectRoot "README.md")) {
    Copy-Item -Path (Join-Path $ProjectRoot "README.md") -Destination $StageZipDir -Force
}

Add-Type -AssemblyName System.IO.Compression.FileSystem
$ZipOut = Join-Path $DistDir "Claude-Instance-Manager-v1.0.0-Portable.zip"
if (Test-Path $ZipOut) { Remove-Item -Path $ZipOut -Force }
[System.IO.Compression.ZipFile]::CreateFromDirectory($StageZipDir, $ZipOut)
Remove-Item -Path $StageZipDir -Recurse -Force

Write-Host "Build complete:" -ForegroundColor Green
Write-Host "  Standalone EXE: $ExeOut"
Write-Host "  Portable ZIP  : $ZipOut"
