# Core-Instances.ps1 — High-Performance Instance Discovery, Precompiled C# Native Engine, Hardlink Sync & Shortcuts

Add-Type -AssemblyName System.Drawing

$script:CIMVersion = "1.3.0"
$script:CIMRootDir = Join-Path $env:LOCALAPPDATA "Claude-Instances"
$script:CIMStateFile = Join-Path $script:CIMRootDir "cim-state.json"
$script:CIMIconsDir = Join-Path $script:CIMRootDir "icons"
$script:CIMBackupsDir = Join-Path $script:CIMRootDir "Backups"
$script:CIMNativeDllPath = Join-Path $script:CIMRootDir "CIMNative.v10.dll"
$script:ReservedFolderNames = @("icons", "Backups", "Manager", "logs", "temp")
$script:CachedClaudeExePath = $null
$script:PidCommandLineCache = @{}

function Initialize-CIMDirectories {
    foreach ($d in @($script:CIMRootDir, $script:CIMIconsDir, $script:CIMBackupsDir)) {
        if (-not (Test-Path $d)) {
            New-Item -ItemType Directory -Path $d -Force | Out-Null
        }
    }
}

function Initialize-CIMNativeEngine {
    if ("CIMNative.FastMetricsScanner" -as [type]) { return }
    Initialize-CIMDirectories

    if (Test-Path $script:CIMNativeDllPath) {
        try {
            Add-Type -Path $script:CIMNativeDllPath -ErrorAction Stop
            if ("CIMNative.FastMetricsScanner" -as [type]) { return }
        } catch {}
    }

    $csCode = @"
using System;
using System.Collections.Generic;
using System.IO;
using System.Runtime.InteropServices;
using System.Text;
using System.Text.RegularExpressions;

namespace CIMNative {
    public static class HardLink {
        [DllImport("Kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
        public static extern bool CreateHardLink(string lpFileName, string lpExistingFileName, IntPtr lpSecurityAttributes);

        public static int SyncTree(string srcRoot, string dstRoot, string[] excludeNames) {
            if (!Directory.Exists(srcRoot)) return 0;
            if (!Directory.Exists(dstRoot)) Directory.CreateDirectory(dstRoot);

            var excludeSet = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
            if (excludeNames != null) {
                foreach (var n in excludeNames) excludeSet.Add(n);
            }

            int linked = 0;
            string srcPrefix = srcRoot.EndsWith("\\") ? srcRoot : srcRoot + "\\";
            foreach (string srcFile in Directory.EnumerateFiles(srcRoot, "*", SearchOption.AllDirectories)) {
                string fileName = Path.GetFileName(srcFile);
                if (excludeSet.Contains(fileName)) continue;

                string rel = srcFile.Substring(srcPrefix.Length);
                string dstFile = Path.Combine(dstRoot, rel);
                string dstDir = Path.GetDirectoryName(dstFile);
                if (!Directory.Exists(dstDir)) Directory.CreateDirectory(dstDir);

                if (File.Exists(dstFile)) {
                    var sInfo = new FileInfo(srcFile);
                    var dInfo = new FileInfo(dstFile);
                    if (sInfo.Length == dInfo.Length) continue;
                    try { File.Delete(dstFile); } catch {}
                }

                if (!CreateHardLink(dstFile, srcFile, IntPtr.Zero)) {
                    try { File.Copy(srcFile, dstFile, true); } catch {}
                }
                linked++;
            }
            return linked;
        }
    }

    public static class Assoc {
        [DllImport("Shlwapi.dll", CharSet = CharSet.Unicode)]
        public static extern uint AssocQueryString(uint flags, uint str, string pszAssoc, string pszExtra, StringBuilder pszOut, ref uint pcchOut);

        public static string Query(uint strType, string protocol) {
            uint len = 1024;
            var sb = new StringBuilder((int)len);
            AssocQueryString(0, strType, protocol, "open", sb, ref len);
            return sb.ToString();
        }
    }

    public static class FastProcessReader {
        [DllImport("kernel32.dll", SetLastError = true)]
        static extern IntPtr OpenProcess(uint dwDesiredAccess, bool bInheritHandle, int dwProcessId);

        [DllImport("kernel32.dll", SetLastError = true)]
        static extern bool CloseHandle(IntPtr hObject);

        [DllImport("kernel32.dll", SetLastError = true)]
        static extern bool ReadProcessMemory(IntPtr hProcess, IntPtr lpBaseAddress, byte[] lpBuffer, int dwSize, out IntPtr lpNumberOfBytesRead);

        [DllImport("ntdll.dll")]
        static extern int NtQueryInformationProcess(IntPtr processHandle, int processInformationClass, ref PROCESS_BASIC_INFORMATION processInformation, int processInformationLength, out int returnLength);

        [StructLayout(LayoutKind.Sequential)]
        struct PROCESS_BASIC_INFORMATION {
            public IntPtr Reserved1;
            public IntPtr PebBaseAddress;
            public IntPtr Reserved2_0;
            public IntPtr Reserved2_1;
            public IntPtr UniqueProcessId;
            public IntPtr Reserved3;
        }

        public static string GetCommandLine(int pid) {
            IntPtr h = OpenProcess(0x0410, false, pid);
            if (h == IntPtr.Zero) return "";
            try {
                var pbi = new PROCESS_BASIC_INFORMATION();
                int retLen;
                if (NtQueryInformationProcess(h, 0, ref pbi, Marshal.SizeOf(pbi), out retLen) != 0) return "";
                if (pbi.PebBaseAddress == IntPtr.Zero) return "";

                IntPtr nRead;
                byte[] ptrBuf = new byte[8];
                if (!ReadProcessMemory(h, IntPtr.Add(pbi.PebBaseAddress, 0x20), ptrBuf, 8, out nRead)) return "";
                IntPtr procParams = (IntPtr)BitConverter.ToInt64(ptrBuf, 0);

                byte[] usBuf = new byte[16];
                if (!ReadProcessMemory(h, IntPtr.Add(procParams, 0x70), usBuf, 16, out nRead)) return "";
                ushort len = BitConverter.ToUInt16(usBuf, 0);
                IntPtr strPtr = (IntPtr)BitConverter.ToInt64(usBuf, 8);
                if (len == 0 || strPtr == IntPtr.Zero) return "";

                byte[] strBuf = new byte[len];
                if (!ReadProcessMemory(h, strPtr, strBuf, len, out nRead)) return "";
                return Encoding.Unicode.GetString(strBuf);
            } catch {
                return "";
            } finally {
                CloseHandle(h);
            }
        }
    }

    public class SessionMeta {
        public string SessionId;
        public string CliSessionId;
        public string FileName;
        public string FullPath;
        public string Kind;
        public string Title;
        public string Cwd;
        public string ProjectName;
        public string Model;
        public long LastActivityAt;
        public string LastActivityFormatted;
        public string ParentSessionId;
        public bool HasSideNotes;
        public bool IsArchived;
        public string AccountUuid;
        public string OrgUuid;
        public string DisplayLabel;
    }

    public static class FastSessionScanner {
        private static string ExtractJsonString(string json, string key) {
            string pattern = "\"" + key + "\"\\s*:\\s*\"((?:\\\\.|[^\"\\\\])*)\"";
            var m = Regex.Match(json, pattern);
            if (!m.Success) return "";
            return Regex.Unescape(m.Groups[1].Value);
        }

        private static long ExtractJsonLong(string json, string key) {
            string pattern = "\"" + key + "\"\\s*:\\s*(\\d+)";
            var m = Regex.Match(json, pattern);
            if (!m.Success) return 0;
            long val = 0;
            long.TryParse(m.Groups[1].Value, out val);
            return val;
        }

        private static bool ExtractJsonBool(string json, string key) {
            string pattern = "\"" + key + "\"\\s*:\\s*(true|false)";
            var m = Regex.Match(json, pattern);
            return m.Success && m.Groups[1].Value == "true";
        }

        public static List<SessionMeta> ScanInstance(string instanceDataDir) {
            var list = new List<SessionMeta>();
            if (string.IsNullOrEmpty(instanceDataDir) || !Directory.Exists(instanceDataDir)) return list;

            string sideNotesRoot = Path.Combine(instanceDataDir, "side-session-notes");
            string[,] roots = new string[,] {
                { "Code", Path.Combine(instanceDataDir, "claude-code-sessions") },
                { "Cowork", Path.Combine(instanceDataDir, "local-agent-mode-sessions") }
            };

            for (int r = 0; r < 2; r++) {
                string kind = roots[r, 0];
                string rootPath = roots[r, 1];
                if (!Directory.Exists(rootPath)) continue;

                foreach (string file in Directory.EnumerateFiles(rootPath, "local_*.json", SearchOption.AllDirectories)) {
                    try {
                        // Read only the metadata portion (skipping huge remoteMcpServersConfig tool schemas)
                        string text;
                        using (var fs = new FileStream(file, FileMode.Open, FileAccess.Read, FileShare.ReadWrite))
                        using (var sr = new StreamReader(fs, Encoding.UTF8)) {
                            text = sr.ReadToEnd();
                        }

                        // Cut out remoteMcpServersConfig array if present to speed up regex 50x
                        int mcpIdx = text.IndexOf("\"remoteMcpServersConfig\"");
                        string fastHeader = mcpIdx > 0 ? text.Substring(0, mcpIdx) : text;

                        string sid = ExtractJsonString(fastHeader, "sessionId");
                        if (string.IsNullOrEmpty(sid)) sid = Path.GetFileNameWithoutExtension(file);

                        string cliSid = ExtractJsonString(fastHeader, "cliSessionId");
                        string cwd = ExtractJsonString(fastHeader, "cwd");
                        string title = ExtractJsonString(fastHeader, "title");
                        if (string.IsNullOrEmpty(title) && mcpIdx > 0) {
                            // Sometimes title is after remoteMcpServersConfig
                            int tailStart = Math.Max(0, text.Length - 2048);
                            title = ExtractJsonString(text.Substring(tailStart), "title");
                        }
                        if (string.IsNullOrEmpty(title)) title = sid;

                        string model = ExtractJsonString(fastHeader, "model");
                        if (string.IsNullOrEmpty(model)) model = "default";

                        long lastAct = ExtractJsonLong(fastHeader, "lastActivityAt");
                        string parentSid = ExtractJsonString(fastHeader, "parentSessionId");
                        if (string.IsNullOrEmpty(parentSid) && text.Length > 2048) {
                            int tailStart = Math.Max(0, text.Length - 2048);
                            parentSid = ExtractJsonString(text.Substring(tailStart), "parentSessionId");
                        }
                        bool isArch = ExtractJsonBool(fastHeader, "isArchived");

                        string projName = "(General)";
                        if (!string.IsNullOrEmpty(cwd)) {
                            string trimmed = cwd.TrimEnd('\\', '/');
                            int lastSlash = trimmed.LastIndexOfAny(new char[] { '\\', '/' });
                            projName = lastSlash >= 0 ? trimmed.Substring(lastSlash + 1) : trimmed;
                        }

                        string dateStr;
                        if (lastAct > 0) {
                            dateStr = DateTimeOffset.FromUnixTimeMilliseconds(lastAct).LocalDateTime.ToString("dd/MM/yyyy HH:mm");
                        } else {
                            dateStr = File.GetLastWriteTime(file).ToString("dd/MM/yyyy HH:mm");
                        }

                        bool hasNotes = Directory.Exists(Path.Combine(sideNotesRoot, sid));
                        var dirInfo = new DirectoryInfo(Path.GetDirectoryName(file));
                        string orgUuid = dirInfo != null ? dirInfo.Name : "";
                        string accUuid = (dirInfo != null && dirInfo.Parent != null) ? dirInfo.Parent.Name : "";

                        string prefix = !string.IsNullOrEmpty(parentSid) ? "  -> " : "";
                        string notesTag = hasNotes ? " [Notes]" : "";

                        list.Add(new SessionMeta {
                            SessionId = sid,
                            CliSessionId = cliSid,
                            FileName = Path.GetFileName(file),
                            FullPath = file,
                            Kind = kind,
                            Title = title,
                            Cwd = cwd,
                            ProjectName = projName,
                            Model = model,
                            LastActivityAt = lastAct,
                            LastActivityFormatted = dateStr,
                            ParentSessionId = parentSid,
                            HasSideNotes = hasNotes,
                            IsArchived = isArch,
                            AccountUuid = accUuid,
                            OrgUuid = orgUuid,
                            DisplayLabel = "[" + projName + "] " + prefix + title + " (" + dateStr + ")" + notesTag
                        });
                    } catch {}
                }
            }
            list.Sort((a, b) => {
                int cmp = string.Compare(a.ProjectName, b.ProjectName, StringComparison.OrdinalIgnoreCase);
                if (cmp != 0) return cmp;
                return b.LastActivityAt.CompareTo(a.LastActivityAt);
            });
            return list;
        }
    }

    public class TurnUsageRecord {
        public string MsgId;
        public string CliSessionId;
        public string EncodedProjectDir;
        public string Cwd;
        public bool IsSubagent;
        public string DateLocal;
        public string TimestampIso;
        public string Model;
        public int TurnCount;
        public long InputTokens;
        public long OutputTokens;
        public long ThinkingTokens;
        public long CacheReadTokens;
        public long CacheWriteTokens;
        public long LinesAdded;
        public long LinesRemoved;
        public int EditCount;
        public int BashCount;
        public int ReadSearchCount;
        public int McpCount;
        public int TotalToolCalls;
    }

    internal class CachedJsonlFile {
        public long LastWriteTicks;
        public long FileLength;
        public List<TurnUsageRecord> Records;
    }

    public static class FastMetricsScanner {
        private static readonly object SyncLock = new object();
        private static readonly Dictionary<string, CachedJsonlFile> FileCache = new Dictionary<string, CachedJsonlFile>(StringComparer.OrdinalIgnoreCase);
        private static List<TurnUsageRecord> LastFullScanResult = null;
        private static DateTime LastFullScanTime = DateTime.MinValue;
        private static bool DiskCacheLoaded = false;
        private static bool PrewarmRunning = false;

        public static void StartBackgroundPrewarm(string claudeProjectsRoot) {
            if (PrewarmRunning) return;
            PrewarmRunning = true;
            System.Threading.Tasks.Task.Run(() => {
                try {
                    ScanAllProjects(claudeProjectsRoot, false);
                } catch {} finally {
                    PrewarmRunning = false;
                }
            });
        }

        public static List<TurnUsageRecord> ScanAllProjects(string claudeProjectsRoot) {
            return ScanAllProjects(claudeProjectsRoot, false);
        }

        private static readonly Regex RxMsgId = new Regex("\"id\"\\s*:\\s*\"(msg_[^\"]+)\"", RegexOptions.Compiled);
        private static readonly Regex RxUuid = new Regex("\"uuid\"\\s*:\\s*\"([^\"]+)\"", RegexOptions.Compiled);
        private static readonly Regex RxTimestamp = new Regex("\"timestamp\"\\s*:\\s*\"([^\"]+)\"", RegexOptions.Compiled);
        private static readonly Regex RxModel = new Regex("\"model\"\\s*:\\s*\"([^\"]+)\"", RegexOptions.Compiled);
        private static readonly Regex RxCwd = new Regex("\"cwd\"\\s*:\\s*\"((?:\\\\.|[^\"\\\\])*)\"", RegexOptions.Compiled);
        private static readonly Regex RxToolId = new Regex("\"id\"\\s*:\\s*\"(toolu_[^\"]+)\"", RegexOptions.Compiled);
        private static readonly Regex RxToolName = new Regex("\"name\"\\s*:\\s*\"([^\"]+)\"", RegexOptions.Compiled);

        private static readonly Regex RxInTok = new Regex("\"input_tokens\"\\s*:\\s*(\\d+)", RegexOptions.Compiled);
        private static readonly Regex RxOutTok = new Regex("\"output_tokens\"\\s*:\\s*(\\d+)", RegexOptions.Compiled);
        private static readonly Regex RxThinkTok = new Regex("\"thinking_tokens\"\\s*:\\s*(\\d+)", RegexOptions.Compiled);
        private static readonly Regex RxCacheRead = new Regex("\"cache_read_input_tokens\"\\s*:\\s*(\\d+)", RegexOptions.Compiled);
        private static readonly Regex RxCacheCreate = new Regex("\"cache_creation_input_tokens\"\\s*:\\s*(\\d+)", RegexOptions.Compiled);

        private static int CountJsonStringLines(string text, int startSearch, string fieldPrefix) {
            int totalLines = 0;
            int pos = startSearch;
            while (pos < text.Length) {
                int idx = text.IndexOf(fieldPrefix, pos, StringComparison.Ordinal);
                if (idx < 0) break;
                int valStart = idx + fieldPrefix.Length;
                int lines = 1;
                bool hasChars = false;
                int i = valStart;
                while (i < text.Length) {
                    char c = text[i];
                    if (c == '\\') {
                        if (i + 1 < text.Length && text[i + 1] == 'n') {
                            lines++;
                        }
                        hasChars = true;
                        i += 2;
                        continue;
                    }
                    if (c == '"') {
                        break;
                    }
                    hasChars = true;
                    i++;
                }
                if (hasChars) totalLines += lines;
                pos = i + 1;
            }
            return totalLines;
        }

        private static string GetDiskCachePath() {
            string dir = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "Claude-Instances");
            if (!Directory.Exists(dir)) Directory.CreateDirectory(dir);
            return Path.Combine(dir, "cim-metrics-cache.v3.tsv");
        }

        private static void LoadDiskCacheIfNeeded() {
            if (DiskCacheLoaded) return;
            DiskCacheLoaded = true;
            string cachePath = GetDiskCachePath();
            if (!File.Exists(cachePath)) return;
            try {
                CachedJsonlFile currentFile = null;
                foreach (string line in File.ReadLines(cachePath, Encoding.UTF8)) {
                    if (string.IsNullOrEmpty(line)) continue;
                    if (line.StartsWith("F\t", StringComparison.Ordinal)) {
                        string[] parts = line.Split('\t');
                        if (parts.Length >= 4) {
                            long ticks = 0, len = 0;
                            long.TryParse(parts[2], out ticks);
                            long.TryParse(parts[3], out len);
                            currentFile = new CachedJsonlFile {
                                LastWriteTicks = ticks,
                                FileLength = len,
                                Records = new List<TurnUsageRecord>()
                            };
                            FileCache[parts[1]] = currentFile;
                        }
                    } else if (line.StartsWith("B\t", StringComparison.Ordinal) && currentFile != null) {
                        string[] parts = line.Split('\t');
                        if (parts.Length >= 20) {
                            int tCount = 1, edC = 0, baC = 0, rsC = 0, mcC = 0, ttC = 0;
                            int.TryParse(parts[1], out tCount);
                            long inT = 0, outT = 0, thT = 0, crT = 0, cwT = 0, lAdd = 0, lRem = 0;
                            long.TryParse(parts[8], out inT);
                            long.TryParse(parts[9], out outT);
                            long.TryParse(parts[10], out thT);
                            long.TryParse(parts[11], out crT);
                            long.TryParse(parts[12], out cwT);
                            long.TryParse(parts[13], out lAdd);
                            long.TryParse(parts[14], out lRem);
                            int.TryParse(parts[15], out edC);
                            int.TryParse(parts[16], out baC);
                            int.TryParse(parts[17], out rsC);
                            int.TryParse(parts[18], out mcC);
                            int.TryParse(parts[19], out ttC);
                            currentFile.Records.Add(new TurnUsageRecord {
                                TurnCount = tCount,
                                CliSessionId = parts[2],
                                EncodedProjectDir = parts[3],
                                Cwd = parts[4],
                                IsSubagent = parts[5] == "1",
                                DateLocal = parts[6],
                                Model = parts[7],
                                InputTokens = inT,
                                OutputTokens = outT,
                                ThinkingTokens = thT,
                                CacheReadTokens = crT,
                                CacheWriteTokens = cwT,
                                LinesAdded = lAdd,
                                LinesRemoved = lRem,
                                EditCount = edC,
                                BashCount = baC,
                                ReadSearchCount = rsC,
                                McpCount = mcC,
                                TotalToolCalls = ttC
                            });
                        }
                    }
                }
            } catch {}
        }

        private static void SaveDiskCache() {
            try {
                string cachePath = GetDiskCachePath();
                using (var sw = new StreamWriter(cachePath, false, Encoding.UTF8)) {
                    foreach (var kv in FileCache) {
                        sw.Write("F\t");
                        sw.Write(kv.Key);
                        sw.Write('\t');
                        sw.Write(kv.Value.LastWriteTicks);
                        sw.Write('\t');
                        sw.WriteLine(kv.Value.FileLength);
                        foreach (var r in kv.Value.Records) {
                            sw.Write("B\t");
                            sw.Write(r.TurnCount); sw.Write('\t');
                            sw.Write(r.CliSessionId ?? ""); sw.Write('\t');
                            sw.Write(r.EncodedProjectDir ?? ""); sw.Write('\t');
                            sw.Write((r.Cwd ?? "").Replace("\t", " ")); sw.Write('\t');
                            sw.Write(r.IsSubagent ? "1" : "0"); sw.Write('\t');
                            sw.Write(r.DateLocal ?? ""); sw.Write('\t');
                            sw.Write(r.Model ?? ""); sw.Write('\t');
                            sw.Write(r.InputTokens); sw.Write('\t');
                            sw.Write(r.OutputTokens); sw.Write('\t');
                            sw.Write(r.ThinkingTokens); sw.Write('\t');
                            sw.Write(r.CacheReadTokens); sw.Write('\t');
                            sw.Write(r.CacheWriteTokens); sw.Write('\t');
                            sw.Write(r.LinesAdded); sw.Write('\t');
                            sw.Write(r.LinesRemoved); sw.Write('\t');
                            sw.Write(r.EditCount); sw.Write('\t');
                            sw.Write(r.BashCount); sw.Write('\t');
                            sw.Write(r.ReadSearchCount); sw.Write('\t');
                            sw.Write(r.McpCount); sw.Write('\t');
                            sw.WriteLine(r.TotalToolCalls);
                        }
                    }
                }
            } catch {}
        }

        private static long ExtractFirstLong(Regex rx, string text) {
            var m = rx.Match(text);
            if (!m.Success) return 0;
            long v = 0;
            long.TryParse(m.Groups[1].Value, out v);
            return v;
        }

        private static long SumAllLongs(Regex rx, string text) {
            long sum = 0;
            foreach (Match m in rx.Matches(text)) {
                long v = 0;
                if (long.TryParse(m.Groups[1].Value, out v)) sum += v;
            }
            return sum;
        }

        public static List<TurnUsageRecord> ScanAllProjects(string claudeProjectsRoot, bool forceDiskRescan) {
            lock (SyncLock) {
                if (!forceDiskRescan && LastFullScanResult != null && (DateTime.UtcNow - LastFullScanTime).TotalSeconds < 30) {
                    return LastFullScanResult;
                }

                var allRecords = new List<TurnUsageRecord>();
                if (string.IsNullOrEmpty(claudeProjectsRoot) || !Directory.Exists(claudeProjectsRoot)) return allRecords;

                LoadDiskCacheIfNeeded();
                bool cacheDirty = false;

                foreach (string projDir in Directory.EnumerateDirectories(claudeProjectsRoot)) {
                    string encodedProjName = Path.GetFileName(projDir);
                    foreach (string jsonlFile in Directory.EnumerateFiles(projDir, "*.jsonl", SearchOption.AllDirectories)) {
                        try {
                            var fi = new FileInfo(jsonlFile);
                            CachedJsonlFile cached;
                            if (FileCache.TryGetValue(jsonlFile, out cached)) {
                                if (cached.LastWriteTicks == fi.LastWriteTimeUtc.Ticks && cached.FileLength == fi.Length) {
                                    allRecords.AddRange(cached.Records);
                                    continue;
                                }
                            }

                            var fileRecords = ParseJsonlFile(jsonlFile, encodedProjName, projDir);
                            FileCache[jsonlFile] = new CachedJsonlFile {
                                LastWriteTicks = fi.LastWriteTimeUtc.Ticks,
                                FileLength = fi.Length,
                                Records = fileRecords
                            };
                            cacheDirty = true;
                            allRecords.AddRange(fileRecords);
                        } catch {}
                    }
                }

                if (cacheDirty) {
                    SaveDiskCache();
                }
                LastFullScanResult = allRecords;
                LastFullScanTime = DateTime.UtcNow;
                return allRecords;
            }
        }

        private static List<TurnUsageRecord> ParseJsonlFile(string filePath, string encodedProjName, string projRootDir) {
            string fileNameNoExt = Path.GetFileNameWithoutExtension(filePath);
            bool isSubagent = fileNameNoExt.StartsWith("agent-", StringComparison.OrdinalIgnoreCase) ||
                              filePath.IndexOf("\\subagents\\", StringComparison.OrdinalIgnoreCase) >= 0;

            string cliSessionId = fileNameNoExt;
            if (isSubagent) {
                var dir = Directory.GetParent(filePath);
                if (dir != null && dir.Name.Equals("subagents", StringComparison.OrdinalIgnoreCase) && dir.Parent != null) {
                    cliSessionId = dir.Parent.Name;
                }
            }

            var byMsgId = new Dictionary<string, TurnUsageRecord>(StringComparer.Ordinal);
            var seenToolIds = new HashSet<string>(StringComparer.Ordinal);
            string detectedCwd = "";
            int lineNum = 0;

            using (var fs = new FileStream(filePath, FileMode.Open, FileAccess.Read, FileShare.ReadWrite, 65536))
            using (var sr = new StreamReader(fs, Encoding.UTF8, true, 65536)) {
                string line;
                while ((line = sr.ReadLine()) != null) {
                    lineNum++;
                    string head = line.Length > 1200 ? line.Substring(0, 1200) : line;

                    if (string.IsNullOrEmpty(detectedCwd) && head.IndexOf("\"cwd\":", StringComparison.Ordinal) >= 0) {
                        var mCwd = RxCwd.Match(head);
                        if (mCwd.Success) {
                            try { detectedCwd = Regex.Unescape(mCwd.Groups[1].Value); } catch { detectedCwd = mCwd.Groups[1].Value; }
                        }
                    }

                    int usageIdx = line.LastIndexOf("\"usage\":", StringComparison.Ordinal);
                    if (usageIdx < 0) continue;

                    string tail = line.Substring(Math.Max(0, usageIdx - 250));
                    string metaZone = head + "\n" + tail;

                    string msgId = "";
                    var mId = RxMsgId.Match(metaZone);
                    if (mId.Success) {
                        msgId = mId.Groups[1].Value;
                    } else {
                        var mUuid = RxUuid.Match(metaZone);
                        msgId = mUuid.Success ? mUuid.Groups[1].Value : ("line_" + lineNum);
                    }

                    string model = "unknown";
                    var mMod = RxModel.Match(metaZone);
                    if (mMod.Success) model = mMod.Groups[1].Value;
                    if (model.StartsWith("<synthetic>", StringComparison.OrdinalIgnoreCase)) continue;

                    string tsIso = "";
                    string dateLocal = "";
                    var mTs = RxTimestamp.Match(metaZone);
                    if (mTs.Success) {
                        tsIso = mTs.Groups[1].Value;
                        DateTimeOffset dto;
                        if (DateTimeOffset.TryParse(tsIso, out dto)) {
                            dateLocal = dto.LocalDateTime.ToString("yyyy-MM-dd");
                        }
                    }
                    if (string.IsNullOrEmpty(dateLocal)) {
                        dateLocal = File.GetLastWriteTime(filePath).ToString("yyyy-MM-dd");
                    }

                    string usageSegment = line.Substring(usageIdx);
                    int iterIdx = usageSegment.IndexOf("\"iterations\":", StringComparison.Ordinal);
                    string topUsage = iterIdx > 0 ? usageSegment.Substring(0, iterIdx) : usageSegment;

                    long inTok = ExtractFirstLong(RxInTok, topUsage);
                    long outTok = ExtractFirstLong(RxOutTok, topUsage);
                    long thinkTok = ExtractFirstLong(RxThinkTok, topUsage);
                    long cRead = ExtractFirstLong(RxCacheRead, topUsage);
                    long cWrite = ExtractFirstLong(RxCacheCreate, topUsage);

                    if ((inTok + outTok + cRead + cWrite) == 0 && iterIdx > 0) {
                        string iterSegment = usageSegment.Substring(iterIdx);
                        inTok = SumAllLongs(RxInTok, iterSegment);
                        outTok = SumAllLongs(RxOutTok, iterSegment);
                        cRead = SumAllLongs(RxCacheRead, iterSegment);
                        cWrite = SumAllLongs(RxCacheCreate, iterSegment);
                    }

                    long total = inTok + outTok + cRead + cWrite;
                    if (total <= 0) continue;

                    // Parse tool_use & code line additions/removals on this line
                    long lineAdd = 0;
                    long lineRem = 0;
                    int edCnt = 0;
                    int baCnt = 0;
                    int rsCnt = 0;
                    int mcCnt = 0;
                    int ttCnt = 0;

                    int toolIdx = line.IndexOf("\"type\":\"tool_use\"", StringComparison.Ordinal);
                    if (toolIdx >= 0) {
                        string toolHeader = line.Substring(toolIdx, Math.Min(320, line.Length - toolIdx));
                        var mToolId = RxToolId.Match(toolHeader);
                        string toolId = mToolId.Success ? mToolId.Groups[1].Value : ("t_" + lineNum);
                        if (seenToolIds.Add(toolId)) {
                            ttCnt = 1;
                            var mName = RxToolName.Match(toolHeader);
                            string tName = mName.Success ? mName.Groups[1].Value : "";
                            if (tName.Equals("Edit", StringComparison.OrdinalIgnoreCase) ||
                                tName.Equals("MultiEdit", StringComparison.OrdinalIgnoreCase)) {
                                edCnt = 1;
                                lineRem = CountJsonStringLines(line, toolIdx, "\"old_string\":\"");
                                lineAdd = CountJsonStringLines(line, toolIdx, "\"new_string\":\"");
                            } else if (tName.Equals("Write", StringComparison.OrdinalIgnoreCase)) {
                                edCnt = 1;
                                lineAdd = CountJsonStringLines(line, toolIdx, "\"content\":\"");
                            } else if (tName.Equals("Bash", StringComparison.OrdinalIgnoreCase)) {
                                baCnt = 1;
                            } else if (tName.Equals("Read", StringComparison.OrdinalIgnoreCase) ||
                                       tName.Equals("Grep", StringComparison.OrdinalIgnoreCase) ||
                                       tName.Equals("Glob", StringComparison.OrdinalIgnoreCase) ||
                                       tName.Equals("LS", StringComparison.OrdinalIgnoreCase)) {
                                rsCnt = 1;
                            } else if (tName.StartsWith("mcp__", StringComparison.OrdinalIgnoreCase)) {
                                mcCnt = 1;
                            }
                        }
                    }

                    TurnUsageRecord existing;
                    if (byMsgId.TryGetValue(msgId, out existing)) {
                        long prevTotal = existing.InputTokens + existing.OutputTokens + existing.CacheReadTokens + existing.CacheWriteTokens;
                        if (total >= prevTotal) {
                            existing.InputTokens = inTok;
                            existing.OutputTokens = outTok;
                            existing.ThinkingTokens = Math.Max(existing.ThinkingTokens, thinkTok);
                            existing.CacheReadTokens = cRead;
                            existing.CacheWriteTokens = cWrite;
                            if (!string.IsNullOrEmpty(detectedCwd)) existing.Cwd = detectedCwd;
                        }
                        existing.LinesAdded += lineAdd;
                        existing.LinesRemoved += lineRem;
                        existing.EditCount += edCnt;
                        existing.BashCount += baCnt;
                        existing.ReadSearchCount += rsCnt;
                        existing.McpCount += mcCnt;
                        existing.TotalToolCalls += ttCnt;
                    } else {
                        byMsgId[msgId] = new TurnUsageRecord {
                            MsgId = msgId,
                            CliSessionId = cliSessionId,
                            EncodedProjectDir = encodedProjName,
                            Cwd = detectedCwd,
                            IsSubagent = isSubagent,
                            DateLocal = dateLocal,
                            TimestampIso = tsIso,
                            Model = model,
                            InputTokens = inTok,
                            OutputTokens = outTok,
                            ThinkingTokens = thinkTok,
                            CacheReadTokens = cRead,
                            CacheWriteTokens = cWrite,
                            LinesAdded = lineAdd,
                            LinesRemoved = lineRem,
                            EditCount = edCnt,
                            BashCount = baCnt,
                            ReadSearchCount = rsCnt,
                            McpCount = mcCnt,
                            TotalToolCalls = ttCnt
                        };
                    }
                }
            }

            var buckets = new Dictionary<string, TurnUsageRecord>(StringComparer.Ordinal);
            foreach (var r in byMsgId.Values) {
                if (string.IsNullOrEmpty(r.Cwd) && !string.IsNullOrEmpty(detectedCwd)) r.Cwd = detectedCwd;
                string bKey = (r.DateLocal ?? "") + "|" + (r.Model ?? "");
                TurnUsageRecord b;
                if (buckets.TryGetValue(bKey, out b)) {
                    b.TurnCount += 1;
                    b.InputTokens += r.InputTokens;
                    b.OutputTokens += r.OutputTokens;
                    b.ThinkingTokens += r.ThinkingTokens;
                    b.CacheReadTokens += r.CacheReadTokens;
                    b.CacheWriteTokens += r.CacheWriteTokens;
                    b.LinesAdded += r.LinesAdded;
                    b.LinesRemoved += r.LinesRemoved;
                    b.EditCount += r.EditCount;
                    b.BashCount += r.BashCount;
                    b.ReadSearchCount += r.ReadSearchCount;
                    b.McpCount += r.McpCount;
                    b.TotalToolCalls += r.TotalToolCalls;
                } else {
                    r.TurnCount = 1;
                    buckets[bKey] = r;
                }
            }
            return new List<TurnUsageRecord>(buckets.Values);
        }
    }
}
"@

    try {
        Add-Type -TypeDefinition $csCode -OutputAssembly $script:CIMNativeDllPath -ErrorAction Stop
        Add-Type -Path $script:CIMNativeDllPath -ErrorAction Stop
    } catch {
        Add-Type -TypeDefinition $csCode -ErrorAction SilentlyContinue
    }
}

Initialize-CIMNativeEngine

function Get-CIMState {
    Initialize-CIMDirectories
    $defaultLang = if ([System.Globalization.CultureInfo]::CurrentUICulture.Name -like "pt*") { "pt-BR" } else { "en-US" }
    $defaultState = @{
        language  = $defaultLang
        instances = @{
            "Primary" = @{
                displayName  = "Principal"
                badgeText    = "P1"
                badgeColor   = "#2563EB"
                accountLabel = "Primary Account (MSIX)"
                iconPath     = (Join-Path $script:CIMIconsDir "claude-primary.ico")
            }
        }
        protocol = @{
            mode                  = "ask"
            pinnedInstanceId      = "Primary"
            armedLoginInstanceId  = ""
            armedLoginExpiresAt   = ""
            backupDelegateExecute = "{A56A841F-E974-45C1-8001-7E3F8A085917}"
        }
    }

    if (Test-Path $script:CIMStateFile) {
        try {
            $raw = Get-Content $script:CIMStateFile -Raw -Encoding UTF8 | ConvertFrom-Json
            if ($raw.language) { $defaultState.language = [string]$raw.language }
            if ($raw.instances) {
                foreach ($prop in $raw.instances.PSObject.Properties) {
                    $defaultState.instances[$prop.Name] = @{
                        displayName  = if ($prop.Value.displayName) { [string]$prop.Value.displayName } else { $prop.Name }
                        badgeText    = if ($prop.Value.badgeText) { [string]$prop.Value.badgeText } else { $prop.Name.Substring(0, [Math]::Min(2, $prop.Name.Length)).ToUpper() }
                        badgeColor   = if ($prop.Value.badgeColor) { [string]$prop.Value.badgeColor } else { "#D97757" }
                        accountLabel = if ($prop.Value.accountLabel) { [string]$prop.Value.accountLabel } else { "" }
                        iconPath     = if ($prop.Value.iconPath) { [string]$prop.Value.iconPath } else { Join-Path $script:CIMIconsDir "claude-$($prop.Name.ToLower()).ico" }
                    }
                }
            }
            if ($raw.protocol) {
                foreach ($p in $raw.protocol.PSObject.Properties) {
                    $defaultState.protocol[$p.Name] = $p.Value
                }
            }
        } catch {}
    } else {
        Save-CIMState -State $defaultState
    }
    return $defaultState
}

function Save-CIMState([hashtable]$State) {
    Initialize-CIMDirectories
    $json = $State | ConvertTo-Json -Depth 10
    [System.IO.File]::WriteAllText($script:CIMStateFile, $json, (New-Object System.Text.UTF8Encoding($false)))
}

function Get-PrimaryClaudeDataDir {
    $newPath = Join-Path $env:LOCALAPPDATA "Claude-Data\claude_pzs8sxrjxfjjc"
    if (Test-Path $newPath) { return $newPath }
    $legacyPath = Join-Path $env:LOCALAPPDATA "Packages\Claude_pzs8sxrjxfjjc\LocalCache\Roaming\Claude"
    if (Test-Path $legacyPath) { return $legacyPath }
    $roamingPath = Join-Path $env:APPDATA "Claude"
    if (Test-Path $roamingPath) { return $roamingPath }
    return $newPath
}

function Get-ClaudeExePath {
    if ($script:CachedClaudeExePath -and (Test-Path $script:CachedClaudeExePath)) {
        return $script:CachedClaudeExePath
    }
    $alias = Join-Path $env:LOCALAPPDATA "Microsoft\WindowsApps\claude-desktop.exe"
    if (Test-Path $alias) {
        $script:CachedClaudeExePath = $alias
        return $alias
    }
    try {
        $pkg = Get-AppxPackage -Name "*Claude*" -ErrorAction SilentlyContinue | Sort-Object Version -Descending | Select-Object -First 1
        if ($pkg -and $pkg.InstallLocation) {
            $exe = Join-Path $pkg.InstallLocation "app\Claude.exe"
            if (Test-Path $exe) {
                $script:CachedClaudeExePath = $exe
                return $exe
            }
        }
    } catch {}
    return $alias
}

function Ensure-UniqueConfigFile([string]$FilePath) {
    if (-not (Test-Path $FilePath)) { return }
    try {
        $links = @(fsutil hardlink list $FilePath 2>$null)
        if ($links.Count -gt 1) {
            $bytes = [System.IO.File]::ReadAllBytes($FilePath)
            Remove-Item -Path $FilePath -Force
            [System.IO.File]::WriteAllBytes($FilePath, $bytes)
        }
    } catch {}
}

function Resolve-InstanceIdentity([string]$DataDir) {
    $accUuid = $null
    $orgUuid = $null

    $cfgPath = Join-Path $DataDir "config.json"
    if (Test-Path $cfgPath) {
        try {
            $cfg = Get-Content $cfgPath -Raw -Encoding UTF8 | ConvertFrom-Json
            if ($cfg.lastKnownAccountUuid) { $accUuid = [string]$cfg.lastKnownAccountUuid }
            if ($cfg.sshTransportFlagLastAnswer -and $cfg.sshTransportFlagLastAnswer.orgUuid) {
                $orgUuid = [string]$cfg.sshTransportFlagLastAnswer.orgUuid
            }
        } catch {}
    }

    $sessionsRoot = Join-Path $DataDir "claude-code-sessions"
    if (Test-Path $sessionsRoot) {
        $accDirs = @(Get-ChildItem -Path $sessionsRoot -Directory -ErrorAction SilentlyContinue)
        if (-not $accUuid -and $accDirs.Count -gt 0) {
            $accUuid = ($accDirs | Sort-Object LastWriteTime -Descending | Select-Object -First 1).Name
        }
        if ($accUuid) {
            $accPath = Join-Path $sessionsRoot $accUuid
            if (Test-Path $accPath) {
                $orgDirs = @(Get-ChildItem -Path $accPath -Directory -ErrorAction SilentlyContinue)
                if ($orgDirs.Count -gt 0) {
                    if (-not $orgUuid -or -not (Test-Path (Join-Path $accPath $orgUuid))) {
                        $bestOrg = $orgDirs | Sort-Object { @([System.IO.Directory]::GetFiles($_.FullName, "local_*.json")).Count } -Descending | Select-Object -First 1
                        $orgUuid = $bestOrg.Name
                    }
                }
            }
        }
    }

    return [PSCustomObject]@{
        AccountUuid = $accUuid
        OrgUuid     = $orgUuid
    }
}

function Get-ClaudeInstances {
    $state = Get-CIMState
    $primaryDir = Get-PrimaryClaudeDataDir

    # Ultra-fast native PEB CommandLine lookup + PID cache (< 20ms cold, < 1ms cached, zero WMI overhead)
    $claudeProcs = @()
    $fastProcs = @([System.Diagnostics.Process]::GetProcessesByName("claude"))
    if ($fastProcs.Count -gt 0) {
        foreach ($fp in $fastProcs) {
            if (-not $script:PidCommandLineCache.ContainsKey($fp.Id)) {
                $script:PidCommandLineCache[$fp.Id] = [CIMNative.FastProcessReader]::GetCommandLine($fp.Id)
            }
            $claudeProcs += [PSCustomObject]@{
                ProcessId      = $fp.Id
                CommandLine    = $script:PidCommandLineCache[$fp.Id]
                WorkingSetSize = $fp.WorkingSet64
            }
        }
    }

    $rawList = @(
        [PSCustomObject]@{
            Id        = "Primary"
            DataDir   = $primaryDir
            IsPrimary = $true
        }
    )

    if (Test-Path $script:CIMRootDir) {
        $subDirs = Get-ChildItem -Path $script:CIMRootDir -Directory -ErrorAction SilentlyContinue |
            Where-Object { $script:ReservedFolderNames -notcontains $_.Name }
        foreach ($d in $subDirs) {
            $rawList += [PSCustomObject]@{
                Id        = $d.Name
                DataDir   = $d.FullName
                IsPrimary = $false
            }
        }
    }

    $results = @()
    foreach ($item in $rawList) {
        $meta = $state.instances[$item.Id]
        if (-not $meta) {
            $meta = @{
                displayName  = $item.Id
                badgeText    = $item.Id.Substring(0, [Math]::Min(2, $item.Id.Length)).ToUpper()
                badgeColor   = "#D97757"
                accountLabel = "Isolated Instance"
                iconPath     = (Join-Path $script:CIMIconsDir "claude-$($item.Id.ToLower()).ico")
            }
        }

        $ident = Resolve-InstanceIdentity -DataDir $item.DataDir

        $instProcs = @()
        if ($claudeProcs.Count -gt 0) {
            if ($item.IsPrimary) {
                $instProcs = @($claudeProcs | Where-Object { $_.CommandLine -notmatch "--user-data-dir" })
            } else {
                $escapedDir = [regex]::Escape($item.DataDir)
                $instProcs = @($claudeProcs | Where-Object { $_.CommandLine -match $escapedDir })
            }
        }

        $ramBytes = 0
        foreach ($p in $instProcs) {
            if ($p.WorkingSetSize) { $ramBytes += [int64]$p.WorkingSetSize }
        }
        $ramMB = [math]::Round($ramBytes / 1MB, 1)

        $sessionCount = 0
        $sessionsBase = Join-Path $item.DataDir "claude-code-sessions"
        if (Test-Path $sessionsBase) {
            try {
                $sessionCount = [System.IO.Directory]::GetFiles($sessionsBase, "local_*.json", [System.IO.SearchOption]::AllDirectories).Length
            } catch {}
        }

        $vhdxPath = Join-Path $item.DataDir "vm_bundles\claudevm.bundle\sessiondata.vhdx"
        $vmPresent = Test-Path $vhdxPath

        $dispatchEnabled = $false
        $bridgePath = Join-Path $item.DataDir "bridge-state.json"
        if (Test-Path $bridgePath) {
            try {
                $bRaw = [System.IO.File]::ReadAllText($bridgePath)
                if ($bRaw -match '"enabled"\s*:\s*true') { $dispatchEnabled = $true }
            } catch {}
        }

        $results += [PSCustomObject]@{
            Id              = $item.Id
            DisplayName     = $meta.displayName
            DataDir         = $item.DataDir
            IsPrimary       = $item.IsPrimary
            AccountUuid     = if ($ident.AccountUuid) { $ident.AccountUuid } else { "Unauthenticated" }
            OrgUuid         = if ($ident.OrgUuid) { $ident.OrgUuid } else { "—" }
            AccountLabel    = $meta.accountLabel
            BadgeText       = $meta.badgeText
            BadgeColor      = $meta.badgeColor
            IconPath        = $meta.iconPath
            IsRunning       = ($instProcs.Count -gt 0)
            ProcessCount    = $instProcs.Count
            RamMB           = $ramMB
            VmDiskPresent   = $vmPresent
            SessionCount    = $sessionCount
            DispatchEnabled = $dispatchEnabled
        }
    }

    return $results
}

function Get-PrimaryClaudeStamp([string]$PrimaryDir) {
    $ccDir = Join-Path $PrimaryDir "claude-code"
    $vmRootfs = Join-Path $PrimaryDir "vm_bundles\claudevm.bundle\rootfs.vhdx"
    $s1 = if (Test-Path $ccDir) { (Get-Item $ccDir).LastWriteTimeUtc.Ticks } else { 0 }
    $s2 = if (Test-Path $vmRootfs) { (Get-Item $vmRootfs).Length } else { 0 }
    return "$s1-$s2"
}

function Sync-ClaudeInstanceLinks([string]$TargetDir, [switch]$Force) {
    $primaryDir = Get-PrimaryClaudeDataDir
    if (-not (Test-Path $primaryDir)) {
        throw "Primary instance directory not found: $primaryDir"
    }
    if (-not (Test-Path $TargetDir)) {
        New-Item -ItemType Directory -Path $TargetDir -Force | Out-Null
    }

    $stampFile = Join-Path $TargetDir ".cim-sync-stamp"
    $currentStamp = Get-PrimaryClaudeStamp -PrimaryDir $primaryDir

    if (-not $Force -and (Test-Path $stampFile)) {
        $savedStamp = [System.IO.File]::ReadAllText($stampFile).Trim()
        if ($savedStamp -eq $currentStamp) {
            return [PSCustomObject]@{ LinkedCount = 0; SkippedCount = 1 }
        }
    }

    $sharedDirs = @(
        "claude-code",
        "claude-code-vm",
        "claude-ssh-remote",
        "terminal-shell-integration",
        "Claude Extensions"
    )

    $linked = 0
    foreach ($dirName in $sharedDirs) {
        $linked += [CIMNative.HardLink]::SyncTree(
            (Join-Path $primaryDir $dirName),
            (Join-Path $TargetDir $dirName),
            [string[]]@()
        )
    }

    $linked += [CIMNative.HardLink]::SyncTree(
        (Join-Path $primaryDir "vm_bundles\claudevm.bundle"),
        (Join-Path $TargetDir "vm_bundles\claudevm.bundle"),
        [string[]]@("sessiondata.vhdx", "sessiondata.img")
    )

    foreach ($cfgName in @("claude_desktop_config.json", "config.json", "bridge-state.json")) {
        $cfgTarget = Join-Path $TargetDir $cfgName
        if (Test-Path $cfgTarget) {
            Ensure-UniqueConfigFile -FilePath $cfgTarget
        } elseif ($cfgName -eq "claude_desktop_config.json") {
            $primaryCfg = Join-Path $primaryDir "claude_desktop_config.json"
            if (Test-Path $primaryCfg) {
                Copy-Item -Path $primaryCfg -Destination $cfgTarget -Force
                Ensure-UniqueConfigFile -FilePath $cfgTarget
            } else {
                '{"preferences":{"orgRestrictions":{"off":["auto_updates"],"at":1794000000000}}}' | Set-Content -Path $cfgTarget -Encoding UTF8
            }
        }
    }

    [System.IO.File]::WriteAllText($stampFile, $currentStamp)

    return [PSCustomObject]@{
        LinkedCount  = $linked
        SkippedCount = 0
    }
}

function Get-ClaudeBaseBitmap {
    try {
        $pkg = Get-AppxPackage -Name "*Claude*" -ErrorAction SilentlyContinue | Sort-Object Version -Descending | Select-Object -First 1
        if ($pkg -and $pkg.InstallLocation) {
            $candidates = Get-ChildItem -Path (Join-Path $pkg.InstallLocation "Assets") -Filter "Square150x150Logo*.png" -ErrorAction SilentlyContinue |
                Sort-Object Length -Descending
            if ($candidates -and $candidates.Count -gt 0) {
                return [System.Drawing.Bitmap]::FromFile($candidates[0].FullName)
            }
        }
    } catch {}

    $bmp = New-Object System.Drawing.Bitmap(256, 256)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $brush = New-Object System.Drawing.SolidBrush([System.Drawing.ColorTranslator]::FromHtml("#D97757"))
    $g.FillEllipse($brush, 20, 20, 216, 216)
    $brush.Dispose()
    $g.Dispose()
    return $bmp
}

function New-ClaudeBadgeIcon([string]$OutputIcoPath, [string]$BadgeText, [string]$BadgeColorHex) {
    $parent = Split-Path -Parent $OutputIcoPath
    if (-not (Test-Path $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }

    $baseBmp = Get-ClaudeBaseBitmap
    $sizes = @(256, 48, 32, 16)
    $pngBuffers = @()

    try {
        $badgeColor = [System.Drawing.ColorTranslator]::FromHtml($BadgeColorHex)
    } catch {
        $badgeColor = [System.Drawing.ColorTranslator]::FromHtml("#2563EB")
    }

    foreach ($sz in $sizes) {
        $canvas = New-Object System.Drawing.Bitmap($sz, $sz, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
        $g = [System.Drawing.Graphics]::FromImage($canvas)
        $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
        $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit

        $g.DrawImage($baseBmp, 0, 0, $sz, $sz)

        $bDiam = [Math]::Max(8, [int][Math]::Round($sz * 0.46))
        $bx = $sz - $bDiam
        $by = $sz - $bDiam

        $fillBrush = New-Object System.Drawing.SolidBrush($badgeColor)
        $borderPen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(240, 20, 20, 24), [Math]::Max(1.0, [float]($sz * 0.04)))

        $g.FillEllipse($fillBrush, $bx, $by, $bDiam - 1, $bDiam - 1)
        $g.DrawEllipse($borderPen, $bx, $by, $bDiam - 1, $bDiam - 1)

        if (-not [string]::IsNullOrWhiteSpace($BadgeText) -and $sz -ge 24) {
            $txt = $BadgeText.Trim().ToUpper()
            $fontScale = if ($txt.Length -ge 2) { 0.42 } else { 0.52 }
            $fontSize = [Math]::Max(6.0, [float]($bDiam * $fontScale))
            $font = New-Object System.Drawing.Font("Segoe UI", $fontSize, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel)
            $sf = New-Object System.Drawing.StringFormat
            $sf.Alignment = [System.Drawing.StringAlignment]::Center
            $sf.LineAlignment = [System.Drawing.StringAlignment]::Center
            $rect = New-Object System.Drawing.RectangleF([float]$bx, [float]$by, [float]$bDiam, [float]$bDiam)
            $textBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::White)
            $g.DrawString($txt, $font, $textBrush, $rect, $sf)
            $textBrush.Dispose()
            $font.Dispose()
            $sf.Dispose()
        }

        $fillBrush.Dispose()
        $borderPen.Dispose()
        $g.Dispose()

        $ms = New-Object System.IO.MemoryStream
        $canvas.Save($ms, [System.Drawing.Imaging.ImageFormat]::Png)
        $pngBuffers += ,($ms.ToArray())
        $ms.Dispose()
        $canvas.Dispose()
    }
    $baseBmp.Dispose()

    $fs = [System.IO.File]::Open($OutputIcoPath, [System.IO.FileMode]::Create, [System.IO.FileAccess]::Write)
    $bw = New-Object System.IO.BinaryWriter($fs)
    $bw.Write([uint16]0)
    $bw.Write([uint16]1)
    $bw.Write([uint16]$sizes.Count)

    $offset = 6 + (16 * $sizes.Count)
    for ($i = 0; $i -lt $sizes.Count; $i++) {
        $s = $sizes[$i]
        $bVal = if ($s -ge 256) { [byte]0 } else { [byte]$s }
        $len = $pngBuffers[$i].Length
        $bw.Write($bVal)
        $bw.Write($bVal)
        $bw.Write([byte]0)
        $bw.Write([byte]0)
        $bw.Write([uint16]1)
        $bw.Write([uint16]32)
        $bw.Write([uint32]$len)
        $bw.Write([uint32]$offset)
        $offset += $len
    }

    for ($i = 0; $i -lt $sizes.Count; $i++) {
        $bw.Write($pngBuffers[$i])
    }

    $bw.Flush()
    $bw.Close()
    $fs.Close()
}

function New-ClaudeInstanceShortcuts([string]$InstanceId, [string]$DisplayName, [string]$DataDir, [string]$IconPath, [bool]$IsPrimary) {
    Initialize-CIMDirectories
    $exePath = Get-ClaudeExePath
    $wsh = New-Object -ComObject WScript.Shell
    $desktopDir = [Environment]::GetFolderPath("Desktop")
    $startMenuDir = Join-Path ([Environment]::GetFolderPath("Programs")) "Claude Instances"
    if (-not (Test-Path $startMenuDir)) {
        New-Item -ItemType Directory -Path $startMenuDir -Force | Out-Null
    }

    if ($IsPrimary) {
        foreach ($folder in @($desktopDir, $startMenuDir)) {
            $lnkPath = Join-Path $folder "Claude - $DisplayName.lnk"
            $sc = $wsh.CreateShortcut($lnkPath)
            $sc.TargetPath = $exePath
            $sc.Arguments = ""
            if (Test-Path $IconPath) { $sc.IconLocation = "$IconPath,0" }
            $sc.Description = "Claude Desktop ($DisplayName)"
            $sc.Save()
        }
    } else {
        $vbsPath = Join-Path $script:CIMRootDir "Launch-$InstanceId.vbs"
        $vbsContent = @"
Set WshShell = CreateObject("WScript.Shell")
WshShell.Run """$exePath"" --user-data-dir=""$DataDir""", 1, False
"@
        [System.IO.File]::WriteAllText($vbsPath, $vbsContent, [System.Text.Encoding]::ASCII)

        foreach ($folder in @($desktopDir, $startMenuDir)) {
            $lnkPath = Join-Path $folder "Claude - $DisplayName.lnk"
            $sc = $wsh.CreateShortcut($lnkPath)
            $sc.TargetPath = "C:\Windows\System32\wscript.exe"
            $sc.Arguments = "`"$vbsPath`""
            if (Test-Path $IconPath) { $sc.IconLocation = "$IconPath,0" }
            $sc.Description = "Claude Desktop ($DisplayName)"
            $sc.Save()
        }
    }
}

function New-ClaudeInstance([string]$Id, [string]$DisplayName, [string]$BadgeText, [string]$BadgeColor, [string]$AccountLabel) {
    $cleanId = ($Id -replace '[^a-zA-Z0-9_-]', '')
    if ([string]::IsNullOrWhiteSpace($cleanId)) {
        throw "Instance ID must contain alphanumeric characters."
    }
    if ($script:ReservedFolderNames -contains $cleanId -or $cleanId -eq "Primary") {
        throw "Reserved instance name: $cleanId"
    }

    $targetDir = Join-Path $script:CIMRootDir $cleanId
    if (-not (Test-Path $targetDir)) {
        New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
    }

    $icoPath = Join-Path $script:CIMIconsDir "claude-$($cleanId.ToLower()).ico"
    New-ClaudeBadgeIcon -OutputIcoPath $icoPath -BadgeText $BadgeText -BadgeColorHex $BadgeColor

    $state = Get-CIMState
    $state.instances[$cleanId] = @{
        displayName  = if ($DisplayName) { $DisplayName } else { $cleanId }
        badgeText    = if ($BadgeText) { $BadgeText } else { $cleanId.Substring(0, [Math]::Min(2, $cleanId.Length)).ToUpper() }
        badgeColor   = if ($BadgeColor) { $BadgeColor } else { "#F59E0B" }
        accountLabel = if ($AccountLabel) { $AccountLabel } else { "Secondary Instance" }
        iconPath     = $icoPath
    }
    Save-CIMState -State $state

    $syncRes = Sync-ClaudeInstanceLinks -TargetDir $targetDir -Force
    New-ClaudeInstanceShortcuts -InstanceId $cleanId -DisplayName $state.instances[$cleanId].displayName -DataDir $targetDir -IconPath $icoPath -IsPrimary $false
    return $syncRes
}

function Update-ClaudeInstanceMetadata([string]$InstanceId, [string]$DisplayName, [string]$BadgeText, [string]$BadgeColor, [string]$AccountLabel, [bool]$RecreateShortcuts = $true) {
    $state = Get-CIMState
    $inst = Get-ClaudeInstances | Where-Object { $_.Id -eq $InstanceId } | Select-Object -First 1
    if (-not $inst) { throw "Instance not found: $InstanceId" }

    $icoPath = Join-Path $script:CIMIconsDir "claude-$($InstanceId.ToLower()).ico"
    New-ClaudeBadgeIcon -OutputIcoPath $icoPath -BadgeText $BadgeText -BadgeColorHex $BadgeColor

    $state.instances[$InstanceId] = @{
        displayName  = $DisplayName
        badgeText    = $BadgeText
        badgeColor   = $BadgeColor
        accountLabel = $AccountLabel
        iconPath     = $icoPath
    }
    Save-CIMState -State $state

    if ($RecreateShortcuts) {
        New-ClaudeInstanceShortcuts -InstanceId $InstanceId -DisplayName $DisplayName -DataDir $inst.DataDir -IconPath $icoPath -IsPrimary $inst.IsPrimary
    }
}

function Start-ClaudeInstance([string]$InstanceId) {
    $inst = Get-ClaudeInstances | Where-Object { $_.Id -eq $InstanceId } | Select-Object -First 1
    if (-not $inst) { throw "Instance not found: $InstanceId" }
    $exePath = Get-ClaudeExePath

    if ($inst.IsPrimary) {
        Start-Process -FilePath $exePath
    } else {
        # Stamp check makes this < 1ms if already synced
        Sync-ClaudeInstanceLinks -TargetDir $inst.DataDir | Out-Null
        Start-Process -FilePath $exePath -ArgumentList "--user-data-dir=`"$($inst.DataDir)`""
    }
}

function Stop-ClaudeInstance([string]$InstanceId) {
    $inst = Get-ClaudeInstances | Where-Object { $_.Id -eq $InstanceId } | Select-Object -First 1
    if (-not $inst) { throw "Instance not found: $InstanceId" }

    $fastProcs = @([System.Diagnostics.Process]::GetProcessesByName("claude"))
    $stopped = 0
    foreach ($fp in $fastProcs) {
        $cmd = if ($script:PidCommandLineCache.ContainsKey($fp.Id)) {
            $script:PidCommandLineCache[$fp.Id]
        } else {
            [CIMNative.FastProcessReader]::GetCommandLine($fp.Id)
        }
        $match = if ($inst.IsPrimary) {
            ($cmd -notmatch "--user-data-dir")
        } else {
            ($cmd -match [regex]::Escape($inst.DataDir))
        }
        if ($match) {
            Stop-Process -Id $fp.Id -Force -ErrorAction SilentlyContinue
            $stopped++
        }
    }
    return $stopped
}

function Clear-ClaudeInstanceAuth([string]$InstanceId) {
    $inst = Get-ClaudeInstances | Where-Object { $_.Id -eq $InstanceId } | Select-Object -First 1
    if (-not $inst) { throw "Instance not found: $InstanceId" }

    Stop-ClaudeInstance -InstanceId $InstanceId | Out-Null
    Start-Sleep -Milliseconds 500

    $authPaths = @(
        (Join-Path $inst.DataDir "Network\Cookies"),
        (Join-Path $inst.DataDir "Network\Cookies-journal"),
        (Join-Path $inst.DataDir "Session Storage"),
        (Join-Path $inst.DataDir "Local Storage")
    )
    foreach ($ap in $authPaths) {
        if (Test-Path $ap) {
            Remove-Item -Path $ap -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    $cfgPath = Join-Path $inst.DataDir "config.json"
    if (Test-Path $cfgPath) {
        Ensure-UniqueConfigFile -FilePath $cfgPath
        try {
            $cfg = Get-Content $cfgPath -Raw -Encoding UTF8 | ConvertFrom-Json
            if ($cfg.PSObject.Properties["oauth:tokenCache"]) {
                $cfg.PSObject.Properties.Remove("oauth:tokenCache")
            }
            $json = $cfg | ConvertTo-Json -Depth 10
            [System.IO.File]::WriteAllText($cfgPath, $json, (New-Object System.Text.UTF8Encoding($false)))
        } catch {}
    }

    return $true
}

function Repair-ClaudeInstanceSessionOwnership([string]$InstanceId) {
    $inst = Get-ClaudeInstances | Where-Object { $_.Id -eq $InstanceId } | Select-Object -First 1
    if (-not $inst) { throw "Instance not found: $InstanceId" }

    $cfgPath = Join-Path $inst.DataDir "config.json"
    if (-not (Test-Path $cfgPath)) { return 0 }
    $cfg = Get-Content $cfgPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $activeAcc = [string]$cfg.lastKnownAccountUuid
    $activeOrg = if ($cfg.sshTransportFlagLastAnswer) { [string]$cfg.sshTransportFlagLastAnswer.orgUuid } else { $null }
    if ([string]::IsNullOrWhiteSpace($activeAcc) -or [string]::IsNullOrWhiteSpace($activeOrg)) {
        return 0
    }

    $sessionsRoot = Join-Path $inst.DataDir "claude-code-sessions"
    if (-not (Test-Path $sessionsRoot)) { return 0 }

    $targetFolder = Join-Path $sessionsRoot "$activeAcc\$activeOrg"
    if (-not (Test-Path $targetFolder)) {
        New-Item -ItemType Directory -Path $targetFolder -Force | Out-Null
    }

    $migrated = 0
    $allSessionFiles = Get-ChildItem -Path $sessionsRoot -Filter "local_*.json" -Recurse -ErrorAction SilentlyContinue
    foreach ($sf in $allSessionFiles) {
        if ($sf.DirectoryName -ne $targetFolder) {
            $dest = Join-Path $targetFolder $sf.Name
            if (-not (Test-Path $dest)) {
                Move-Item -Path $sf.FullName -Destination $dest -Force
                $migrated++
            }
        }
    }
    return $migrated
}
