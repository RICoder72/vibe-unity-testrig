using UnityEngine;

[UnityEditor.InitializeOnLoadAttribute]
public class AutomaticHelloNasty
{
    static AutomaticHelloNasty()
    {
        UnityEditor.EditorApplication.delayCall += () =>
        {
            Debug.Log("Hello Nasty!");
        };
    }
}