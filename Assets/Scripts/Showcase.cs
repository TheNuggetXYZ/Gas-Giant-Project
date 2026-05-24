using System;
using UnityEngine;

public class Showcase : MonoBehaviour
{
    [SerializeField] private Transform cameraPivot;
    [SerializeField] private new Transform camera;
    [SerializeField] private float scrollSpeed = 50;
    [SerializeField] private float rotationSpeed = 1;

    private void Update()
    {
        Vector2 lookInput = new Vector2(Input.GetAxis("Horizontal"), Input.GetAxis("Vertical"));
        
        cameraPivot.Rotate(0, -lookInput.x * rotationSpeed, -lookInput.y * rotationSpeed);
        
        float scrollInput = Input.GetAxis("Mouse ScrollWheel");
        
        camera.Translate(Vector3.forward * scrollInput * scrollSpeed, Space.Self);
    }
}
