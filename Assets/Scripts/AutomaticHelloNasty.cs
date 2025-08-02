using UnityEngine;

#if UNITY_EDITOR
using UnityEditor;

[InitializeOnLoad]
public class AutomaticHelloNasty
{
    static AutomaticHelloNasty()
    {
        EditorApplication.delayCall += RunTest;
    }

    private static void RunTest()
    {
        EditorApplication.delayCall -= RunTest;
        Debug.Log("Hello Nasty!");
    }
}
#endif