using System;
using UnityEngine;

public class Showcase : MonoBehaviour
{
    [SerializeField] private Transform rotationTransform;
    
    private Transform RotationTransform => rotationTransform != null ? rotationTransform : transform;

    private void Update()
    {
        Vector2 lookInput = new Vector2(Input.GetAxis("Horizontal"), Input.GetAxis("Vertical"));
        
        RotationTransform.Rotate(0, -lookInput.x, -lookInput.y);
    }
}
