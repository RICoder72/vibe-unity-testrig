using UnityEngine;
using UnityEngine.UI;

public class SceneController : MonoBehaviour
{
    private Button helloButton;

    void Start()
    {
        GameObject buttonObject = GameObject.Find("HelloButton");
        if (buttonObject != null)
        {
            helloButton = buttonObject.GetComponent<Button>();
            if (helloButton != null)
            {
                helloButton.onClick.AddListener(OnHelloButtonClicked);
            }
            else
            {
                Debug.LogError("HelloButton GameObject found but Button component missing!");
            }
        }
        else
        {
            Debug.LogError("HelloButton GameObject not found!");
        }
    }

    void OnHelloButtonClicked()
    {
        Debug.Log("Hello Nasty!");
    }
}