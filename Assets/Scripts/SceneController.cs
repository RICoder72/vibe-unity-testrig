using UnityEngine;
using UnityEngine.UI;

public class SceneController : MonoBehaviour
{
    [SerializeField] private Button pushMeButton;
    
    void Start()
    {
        if (pushMeButton != null)
        {
            pushMeButton.onClick.AddListener(OnPushMeButtonClicked);
        }
    }
    
    void OnPushMeButtonClicked()
    {
        Debug.Log("Push Me button was clicked!");
    }
}