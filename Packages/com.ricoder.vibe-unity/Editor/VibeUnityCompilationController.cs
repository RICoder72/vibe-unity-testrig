#if UNITY_EDITOR
using UnityEditor;
using UnityEngine;
using System;
using System.IO;
using System.Collections.Generic;
using System.Linq;
using System.Text;

namespace VibeUnity.Editor
{
    /// <summary>
    /// Controls and monitors Unity compilation for external tools like claude-code
    /// Provides hardened triggers, precise timing, and detailed error/warning reporting
    /// </summary>
    public class VibeUnityCompilationController : AssetPostprocessor
    {
        private static bool wasCompiling = false;
        private static DateTime compilationStartTime;
        private static DateTime compilationEndTime;
        private static string currentRequestId = null;
        private static readonly string projectHash;
        private static readonly string commandsDir;
        private static readonly string statusDir;
        private static readonly bool debugMode = true; // Keep status files for debugging
        
        static VibeUnityCompilationController()
        {
            // Generate unique project identifier
            string projectPath = Application.dataPath;
            projectHash = Math.Abs(projectPath.GetHashCode()).ToString("X8");
            
            // Setup directory paths
            string projectRoot = Directory.GetParent(Application.dataPath).FullName;
            commandsDir = Path.Combine(projectRoot, ".vibe-unity", "compile-commands");
            statusDir = Path.Combine(projectRoot, ".vibe-unity", "compile-status");
            
            // Ensure directories exist
            Directory.CreateDirectory(commandsDir);
            Directory.CreateDirectory(statusDir);
            
            // Start monitoring
            EditorApplication.update += MonitorCompilation;
            
            Debug.Log($"[VibeUnity] CompilationController initialized for project {projectHash}");
        }
        
        private static void MonitorCompilation()
        {
            // Check for compilation state changes
            bool isCompiling = EditorApplication.isCompiling;
            
            if (isCompiling && !wasCompiling)
            {
                // Compilation started
                compilationStartTime = DateTime.UtcNow;
                Debug.Log($"[VibeUnity] ✓ Compilation STARTED at {compilationStartTime:HH:mm:ss.fff}");
                
                if (!string.IsNullOrEmpty(currentRequestId))
                {
                    WriteStatusFile(currentRequestId, "compiling", compilationStartTime, DateTime.MinValue, 0, 0, 
                        new List<string> { "Compilation in progress..." });
                    Debug.Log($"[VibeUnity] Status update sent: compiling (Request: {currentRequestId})");
                }
            }
            else if (!isCompiling && wasCompiling)
            {
                // Compilation finished
                compilationEndTime = DateTime.UtcNow;
                var duration = compilationEndTime - compilationStartTime;
                
                Debug.Log($"[VibeUnity] ✓ Compilation FINISHED at {compilationEndTime:HH:mm:ss.fff} (Duration: {duration.TotalMilliseconds:F0}ms)");
                
                if (!string.IsNullOrEmpty(currentRequestId))
                {
                    // Small delay to ensure console logs are captured
                    EditorApplication.delayCall += () =>
                    {
                        // Capture compilation results after a brief delay
                        var (errors, warnings, details) = GetCompilationResults();
                        WriteStatusFile(currentRequestId, "complete", compilationStartTime, compilationEndTime, errors, warnings, details);
                        Debug.Log($"[VibeUnity] Final status sent: complete (Errors: {errors}, Warnings: {warnings}, Request: {currentRequestId})");
                        currentRequestId = null;
                    };
                }
            }
            else if (!string.IsNullOrEmpty(currentRequestId) && !isCompiling)
            {
                // Check if we have a pending request but Unity isn't compiling
                // This might mean Unity determined no compilation was needed
                var timeSinceRequest = DateTime.UtcNow - compilationStartTime;
                if (timeSinceRequest.TotalSeconds > 5) // Wait 5 seconds to be sure
                {
                    Debug.Log($"[VibeUnity] ⚠ No compilation detected after 5s - Unity may not need to recompile");
                    var (errors, warnings, details) = GetCompilationResults();
                    WriteStatusFile(currentRequestId, "complete", DateTime.UtcNow, DateTime.UtcNow, errors, warnings, 
                        new List<string> { "No compilation required - scripts are up to date" });
                    currentRequestId = null;
                }
            }
            
            wasCompiling = isCompiling;
            
            // Check for new command files
            ProcessCommandFiles();
        }
        
        private static void ProcessCommandFiles()
        {
            try
            {
                var commandFiles = Directory.GetFiles(commandsDir, $"compile-request-{projectHash}-*.json")
                                            .OrderBy(File.GetCreationTime)
                                            .ToArray();
                
                foreach (string commandFile in commandFiles)
                {
                    try
                    {
                        string json = File.ReadAllText(commandFile);
                        var command = JsonUtility.FromJson<CompileCommand>(json);
                        
                        if (command != null && !string.IsNullOrEmpty(command.request_id))
                        {
                            ProcessCompileCommand(command);
                            File.Delete(commandFile);
                        }
                    }
                    catch (Exception e)
                    {
                        Debug.LogError($"[VibeUnity] Failed to process command file {commandFile}: {e.Message}");
                        File.Delete(commandFile); // Remove corrupted file
                    }
                }
            }
            catch (Exception e)
            {
                Debug.LogError($"[VibeUnity] Error processing command files: {e.Message}");
            }
        }
        
        private static void ProcessCompileCommand(CompileCommand command)
        {
            currentRequestId = command.request_id;
            compilationStartTime = DateTime.UtcNow; // Mark when we received the command
            
            Debug.Log($"[VibeUnity] 📝 Processing compile command: {command.action} (Request ID: {command.request_id})");
            
            switch (command.action.ToLower())
            {
                case "force-compile":
                case "force-refresh":
                    // Send initial acknowledgment
                    WriteStatusFile(command.request_id, "processing", DateTime.UtcNow, DateTime.MinValue, 0, 0, 
                        new List<string> { "Command received, forcing compilation..." });
                    
                    // Use EditorApplication.delayCall to ensure this runs on the main thread
                    EditorApplication.delayCall += () =>
                    {
                        Debug.Log($"[VibeUnity] 🔄 Forcing compilation for request {command.request_id}");
                        ForceCompilation();
                        
                        // Reset compilation start time to now (when we actually trigger)
                        compilationStartTime = DateTime.UtcNow;
                    };
                    break;
                    
                case "check-status":
                    // Just report current status without forcing compilation
                    var (errors, warnings, details) = GetCompilationResults();
                    string status = EditorApplication.isCompiling ? "compiling" : "complete";
                    WriteStatusFile(command.request_id, status, DateTime.UtcNow, DateTime.UtcNow, errors, warnings, details);
                    Debug.Log($"[VibeUnity] 📊 Status check complete for request {command.request_id}: {status}");
                    currentRequestId = null;
                    break;
                    
                default:
                    Debug.LogWarning($"[VibeUnity] ❌ Unknown compile command: {command.action}");
                    WriteStatusFile(command.request_id, "error", DateTime.UtcNow, DateTime.UtcNow, 0, 0, 
                        new List<string> { $"Unknown command: {command.action}" });
                    currentRequestId = null;
                    break;
            }
        }
        
        public static void ForceCompilation()
        {
            Debug.Log("[VibeUnity] Forcing asset database refresh and compilation...");
            
            // Method 1: Force asset database refresh
            AssetDatabase.Refresh(ImportAssetOptions.ForceUpdate | ImportAssetOptions.ForceSynchronousImport);
            
            // Method 2: Force reimport of all scripts
            AssetDatabase.ImportAsset("Assets", ImportAssetOptions.ImportRecursive);
            
            Debug.Log("[VibeUnity] Forced compilation requested - monitoring for results...");
        }
        
        private static (int errors, int warnings, List<string> details) GetCompilationResults()
        {
            var errors = 0;
            var warnings = 0;
            var details = new List<string>();
            
            try
            {
                // Use reflection to access Unity's LogEntries
                var logEntriesType = typeof(EditorWindow).Assembly.GetType("UnityEditor.LogEntries");
                if (logEntriesType != null)
                {
                    var getCountMethod = logEntriesType.GetMethod("GetCount");
                    var getEntryMethod = logEntriesType.GetMethod("GetEntryInternal");
                    
                    if (getCountMethod != null && getEntryMethod != null)
                    {
                        int logCount = (int)getCountMethod.Invoke(null, null);
                        var logEntryType = typeof(EditorWindow).Assembly.GetType("UnityEditor.LogEntry");
                        
                        if (logEntryType != null)
                        {
                            var logEntry = Activator.CreateInstance(logEntryType);
                            
                            // Check recent log entries for compilation errors/warnings
                            for (int i = Math.Max(0, logCount - 50); i < logCount; i++)
                            {
                                getEntryMethod.Invoke(null, new object[] { i, logEntry });
                                
                                var messageField = logEntryType.GetField("message");
                                var fileField = logEntryType.GetField("file");
                                var lineField = logEntryType.GetField("line");
                                var modeField = logEntryType.GetField("mode");
                                
                                if (messageField != null && modeField != null)
                                {
                                    string message = (string)messageField.GetValue(logEntry);
                                    int mode = (int)modeField.GetValue(logEntry);
                                    string file = fileField?.GetValue(logEntry) as string ?? "";
                                    int line = (int)(lineField?.GetValue(logEntry) ?? 0);
                                    
                                    // Mode: 0 = Log, 1 = Warning, 2 = Error
                                    if (mode == 2 && (message.Contains("CS") || message.Contains("error")))
                                    {
                                        errors++;
                                        string detail = string.IsNullOrEmpty(file) ? 
                                            $"ERROR: {message}" : 
                                            $"[{file}:{line}] ERROR: {message}";
                                        details.Add(detail);
                                    }
                                    else if (mode == 1 && (message.Contains("CS") || message.Contains("warning")))
                                    {
                                        warnings++;
                                        string detail = string.IsNullOrEmpty(file) ? 
                                            $"WARNING: {message}" : 
                                            $"[{file}:{line}] WARNING: {message}";
                                        details.Add(detail);
                                    }
                                }
                            }
                        }
                    }
                }
            }
            catch (Exception e)
            {
                Debug.LogWarning($"[VibeUnity] Could not access compilation logs via reflection: {e.Message}");
                
                // Fallback: Check if there are compilation errors by attempting to get console window info
                var consoleWindowType = typeof(EditorWindow).Assembly.GetType("UnityEditor.ConsoleWindow");
                if (consoleWindowType != null)
                {
                    // This is a simplified fallback - in practice, more sophisticated log parsing would be needed
                    details.Add("Note: Detailed error parsing not available, check Unity Console");
                }
            }
            
            return (errors, warnings, details);
        }
        
        private static void WriteStatusFile(string requestId, string status, DateTime started, DateTime ended, 
                                          int errors, int warnings, List<string> details)
        {
            try
            {
                var statusData = new CompileStatus
                {
                    request_id = requestId,
                    project_hash = projectHash,
                    status = status,
                    started_ms = started != DateTime.MinValue ? ((DateTimeOffset)started).ToUnixTimeMilliseconds() : 0,
                    ended_ms = ended != DateTime.MinValue ? ((DateTimeOffset)ended).ToUnixTimeMilliseconds() : 0,
                    duration_ms = ended != DateTime.MinValue && started != DateTime.MinValue ? 
                        (long)(ended - started).TotalMilliseconds : 0,
                    errors = errors,
                    warnings = warnings,
                    details = details.ToArray(),
                    timestamp = ((DateTimeOffset)DateTime.UtcNow).ToUnixTimeMilliseconds()
                };
                
                string json = JsonUtility.ToJson(statusData, true);
                string statusFile = Path.Combine(statusDir, $"compile-status-{requestId}.json");
                
                File.WriteAllText(statusFile, json);
                
                Debug.Log($"[VibeUnity] ✅ Status file written: {Path.GetFileName(statusFile)}");
                Debug.Log($"[VibeUnity] Status: {status} (Errors: {errors}, Warnings: {warnings}, Duration: {statusData.duration_ms}ms)");
                
                if (debugMode)
                {
                    Debug.Log($"[VibeUnity] Debug: Status file path: {statusFile}");
                    Debug.Log($"[VibeUnity] Debug: File size: {new FileInfo(statusFile).Length} bytes");
                }
            }
            catch (Exception e)
            {
                Debug.LogError($"[VibeUnity] Failed to write status file: {e.Message}");
            }
        }
        
        [System.Serializable]
        public class CompileCommand
        {
            public string action;
            public string request_id;
            public long timestamp;
        }
        
        [System.Serializable]
        public class CompileStatus
        {
            public string request_id;
            public string project_hash;
            public string status;
            public long started_ms;
            public long ended_ms;
            public long duration_ms;
            public int errors;
            public int warnings;
            public string[] details;
            public long timestamp;
        }
        
        // Public API for menu access
        public static string GetProjectHash() => projectHash;
        public static bool IsCompiling() => EditorApplication.isCompiling;
        public static void TriggerCompilation() => ForceCompilation();
    }
}
#endif