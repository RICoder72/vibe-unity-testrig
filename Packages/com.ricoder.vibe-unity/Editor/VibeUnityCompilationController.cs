#if UNITY_EDITOR
using UnityEditor;
using UnityEditor.Compilation;
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
    [InitializeOnLoad]
    public class VibeUnityCompilationController : AssetPostprocessor
    {
        private static bool wasCompiling = false;
        private static DateTime compilationStartTime;
        private static DateTime compilationEndTime;
        private static string currentRequestId = null;
        private static string projectHash;
        private static string commandsDir;
        private static string statusDir;
        private static readonly bool debugMode = true; // Keep status files for debugging
        
        // CompilationPipeline error collection
        private static List<CompilerMessage> compilationMessages = new List<CompilerMessage>();
        private static bool compilationHasStarted = false;
        
        static VibeUnityCompilationController()
        {
            Initialize();
        }
        
        [InitializeOnLoadMethod]
        private static void Initialize()
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
            EditorApplication.update -= MonitorCompilation; // Remove first to avoid duplicates
            EditorApplication.update += MonitorCompilation;
            
            // Subscribe to CompilationPipeline events for better error detection
            CompilationPipeline.compilationStarted -= OnCompilationStarted;
            CompilationPipeline.compilationStarted += OnCompilationStarted;
            CompilationPipeline.assemblyCompilationFinished -= OnAssemblyCompilationFinished;
            CompilationPipeline.assemblyCompilationFinished += OnAssemblyCompilationFinished;
            CompilationPipeline.compilationFinished -= OnCompilationFinished;
            CompilationPipeline.compilationFinished += OnCompilationFinished;
            
            Debug.Log($"[VibeUnity] CompilationController initialized for project {projectHash}");
            Debug.Log($"[VibeUnity] Monitoring directory: {commandsDir}");
            Debug.Log($"[VibeUnity] CompilationPipeline events subscribed");
            
            // Process any pending command files immediately
            ProcessCommandFiles();
        }
        
        // CompilationPipeline event handlers
        private static void OnCompilationStarted(object context)
        {
            compilationHasStarted = true;
            compilationMessages.Clear();
            Debug.Log($"[VibeUnity] 🔧 CompilationPipeline: Compilation started");
        }
        
        private static void OnAssemblyCompilationFinished(string assemblyPath, CompilerMessage[] messages)
        {
            // Collect all compilation messages (errors, warnings, info)
            compilationMessages.AddRange(messages);
            
            int errors = messages.Count(m => m.type == CompilerMessageType.Error);
            int warnings = messages.Count(m => m.type == CompilerMessageType.Warning);
            
            if (messages.Length > 0)
            {
                string assemblyName = System.IO.Path.GetFileNameWithoutExtension(assemblyPath);
                Debug.Log($"[VibeUnity] 📝 Assembly '{assemblyName}' compiled: {errors} errors, {warnings} warnings");
                
                // Log errors for debugging
                foreach (var msg in messages.Where(m => m.type == CompilerMessageType.Error))
                {
                    Debug.Log($"[VibeUnity] ERROR: {msg.file}:{msg.line} - {msg.message}");
                }
            }
        }
        
        private static void OnCompilationFinished(object context)
        {
            compilationHasStarted = false;
            
            int totalErrors = compilationMessages.Count(m => m.type == CompilerMessageType.Error);
            int totalWarnings = compilationMessages.Count(m => m.type == CompilerMessageType.Warning);
            
            Debug.Log($"[VibeUnity] ✅ CompilationPipeline: Compilation finished - {totalErrors} errors, {totalWarnings} warnings total");
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
            
            // Use CompilationPipeline collected messages
            if (compilationMessages != null && compilationMessages.Count > 0)
            {
                foreach (var message in compilationMessages)
                {
                    if (message.type == CompilerMessageType.Error)
                    {
                        errors++;
                        string detail = string.IsNullOrEmpty(message.file) ? 
                            $"ERROR: {message.message}" : 
                            $"[{message.file}:{message.line}] ERROR: {message.message}";
                        details.Add(detail);
                    }
                    else if (message.type == CompilerMessageType.Warning)
                    {
                        warnings++;
                        string detail = string.IsNullOrEmpty(message.file) ? 
                            $"WARNING: {message.message}" : 
                            $"[{message.file}:{message.line}] WARNING: {message.message}";
                        details.Add(detail);
                    }
                }
            }
            
            // If no CompilationPipeline messages but Unity shows compilation errors, add a note
            if (errors == 0 && warnings == 0 && EditorUtility.scriptCompilationFailed)
            {
                errors = 1; // At least mark as having errors
                details.Add("ERROR: Script compilation failed (details not captured via CompilationPipeline)");
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
        
        // Menu items for testing and debugging
        [MenuItem("Tools/Vibe Unity/Debug/Check Compilation System")]
        public static void CheckCompilationSystem()
        {
            Debug.Log("[VibeUnity] === Compilation System Status ===");
            Debug.Log($"[VibeUnity] Project Hash: {projectHash ?? "NOT INITIALIZED"}");
            Debug.Log($"[VibeUnity] Commands Dir: {commandsDir ?? "NOT SET"}");
            Debug.Log($"[VibeUnity] Status Dir: {statusDir ?? "NOT SET"}");
            Debug.Log($"[VibeUnity] Current Request: {currentRequestId ?? "none"}");
            Debug.Log($"[VibeUnity] Is Compiling: {EditorApplication.isCompiling}");
            Debug.Log($"[VibeUnity] CompilationPipeline Active: {compilationHasStarted}");
            Debug.Log($"[VibeUnity] Collected Messages: {compilationMessages?.Count ?? 0}");
            
            if (compilationMessages != null && compilationMessages.Count > 0)
            {
                int errors = compilationMessages.Count(m => m.type == CompilerMessageType.Error);
                int warnings = compilationMessages.Count(m => m.type == CompilerMessageType.Warning);
                Debug.Log($"[VibeUnity] Last Compilation: {errors} errors, {warnings} warnings");
            }
            
            if (!string.IsNullOrEmpty(commandsDir) && Directory.Exists(commandsDir))
            {
                var files = Directory.GetFiles(commandsDir, "*.json");
                Debug.Log($"[VibeUnity] Pending command files: {files.Length}");
                foreach (var file in files)
                {
                    Debug.Log($"[VibeUnity]   - {Path.GetFileName(file)}");
                }
            }
            
            if (string.IsNullOrEmpty(projectHash))
            {
                Debug.LogWarning("[VibeUnity] System not initialized! Initializing now...");
                Initialize();
            }
        }
        
        [MenuItem("Tools/Vibe Unity/Debug/Force Initialize Compilation System")]
        public static void ForceInitialize()
        {
            Debug.Log("[VibeUnity] Force initializing compilation system...");
            Initialize();
            Debug.Log("[VibeUnity] Initialization complete. Check console for status.");
        }
        
        [MenuItem("Tools/Vibe Unity/Debug/Process Pending Commands")]
        public static void ManualProcessCommands()
        {
            if (string.IsNullOrEmpty(projectHash))
            {
                Debug.LogError("[VibeUnity] System not initialized! Initialize first.");
                Initialize();
            }
            
            Debug.Log("[VibeUnity] Manually processing command files...");
            ProcessCommandFiles();
        }
    }
}
#endif