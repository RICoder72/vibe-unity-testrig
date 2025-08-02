using UnityEngine;
using UnityEngine.UI;

public class HelloNastyController : MonoBehaviour
{
    [SerializeField] private Button helloNastyButton;

    void Start()
    {
        if (helloNastyButton == null)
        {
            helloNastyButton = GameObject.Find("HelloNastyButton")?.GetComponent<Button>();
        }

        if (helloNastyButton != null)
        {
            helloNastyButton.onClick.AddListener(OnHelloNastyButtonClicked);
            Debug.Log("HelloNastyController: Button wired up successfully!");
        }
        else
        {
            Debug.LogError("HelloNastyController: HelloNastyButton not found! Make sure the button exists in the scene.");
        }
    }

    public void OnHelloNastyButtonClicked()
    {
        Debug.Log("Hello Nasty!");
    }
}