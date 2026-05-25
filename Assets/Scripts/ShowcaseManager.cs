using System;
using UnityEngine;

public class ShowcaseManager : MonoBehaviour
{
    [SerializeField] private bool loadShowcasesButton;
    [SerializeField] private bool showAllButton;
    [SerializeField] private bool hideAllButton;
    [SerializeField] private Showcase[] showcases;
    [SerializeField] private int startShowcaseIndex;
    [SerializeField] private int showcaseIndex;

#if UNITY_EDITOR
    
    private void OnValidate()
    {
        SwitchToShowcase(showcaseIndex);
        
        if (loadShowcasesButton)
        {
            loadShowcasesButton = false;
            
            showcases =  FindObjectsByType<Showcase>(FindObjectsSortMode.None);
        }

        if (showAllButton)
        {
            showAllButton = false;
            
            foreach (Showcase showcase in showcases) showcase.gameObject.SetActive(true);
        }
        
        if (hideAllButton)
        {
            hideAllButton = false;
            
            foreach (Showcase showcase in showcases) showcase.gameObject.SetActive(false);
        }
    }
    
#endif

    private void Start()
    {
        showcaseIndex = startShowcaseIndex;
        SwitchToShowcase(startShowcaseIndex);
    }

    private void Update()
    {
        if (Input.GetKeyDown(KeyCode.Space))
        {
            IncrementShowcaseIndexWrap();
            
            SwitchToShowcase(showcaseIndex);
        }
    }

    private void IncrementShowcaseIndexWrap()
    {
        showcaseIndex++;
        
        if (showcaseIndex >= showcases.Length)
            showcaseIndex = 0;
    }

    private void SwitchToShowcase(int index)
    {
        foreach (var sc in showcases)
        {
            sc.gameObject.SetActive(false);
        }
        
        showcases[index].gameObject.SetActive(true);
    }
}
