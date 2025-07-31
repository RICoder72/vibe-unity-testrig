#if UNITY_EDITOR
using UnityEditor;
using UnityEngine;

public class VibeTests : MonoBehaviour
{
    [MenuItem("Testing/GEN TEST", priority = 100)]
    private static void GenericTest()
    {
        Debug.Log("GEN TEST");
        Debug.Log("Server Running: " + VibeUnity.Editor.VibeUnityHttpServer.IsRunning);
        Debug.Log("Menu thinks server enabled: " + VibeUnity.Editor.VibeUnityMenu.IsHttpServerEnabled);
    }
}

#endif