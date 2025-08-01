using UnityEngine;
using UnityEngine.UI;

public class HelloNastyController : MonoBehaviour
{
    [SerializeField] private Button helloButton;
    
    void Start()
    {
        if (helloButton == null)
        {
            helloButton = GameObject.Find("HelloButton")?.GetComponent<Button>();
        }
        
        if (helloButton != null)
        {
            helloButton.onClick.AddListener(OnHelloButtonClicked);
        }
        else
        {
            Debug.LogError("HelloButton not found!");
        }
    }
    
    private void OnHelloButtonClicked()
    {
        Debug.Log("Hello Nasty!");
    }
}