using UnityEngine;
using UnityEngine.Serialization;

[ExecuteInEditMode]
public class OmnidirectionalLight : MonoBehaviour
{
    /// <summary>
    /// The parameter name. This must match the one in your shaders
    /// </summary>
    private static readonly string ShaderPosName = "_OmniLightPos";

    private static readonly string ShaderColorName = "_OmniLightColor";

    [FormerlySerializedAs("_lightColor")] [SerializeField] private Color lightColor;
    
    public void Update()
    {
        Shader.SetGlobalVector(ShaderPosName, transform.position);
        Shader.SetGlobalVector(ShaderColorName, lightColor);
    }
}