Shader "Custom/GasGiant"
{
    Properties
    {
        [Header(Base)]
        _SphereRadius ("Sphere Radius", Float) = 150
        _Density ("Density", Float) = 100
        _FalloffExponent ("Falloff Exponent", Float) = 0.4
        _LightAbsorption ("Light Absorption", Float) = 0.003
        _RimStrength ("Rim Strength", Float) = 1.15
        _RimSharpness ("Rim Sharpness", Float) = 32
        _BaseColor ("Base Color", Color) = (0.8666666666666667, 0.6823529411764706, 0.4823529411764706)
        
        [Header(Noise 1)]
        _N1_NoiseColor ("Noise Color", Color) = (1, 0.8862745098039215, 0.8)
        _N1_ColorNoiseFreq ("Color Noise Freq", Float) = 3
        _N1_ColorNoiseSharpness ("Color Noise Sharpness", Float) = 2
        _N1_ColorNoiseStretching ("Color Noise Stretching", Vector) = (5, 1, 5)
        _N1_Octaves ("Noise Layers", Int) = 5
        _N1_Persistence ("Layer Persistence", Float) = 0.5
        _N1_Lacunarity ("Layer Density Increase", Float) = 2.0
        
        [Header(Noise 2)]
        _N2_NoiseColor ("Noise Color", Color) = (0.788235294117647, 0.5725490196078431, 0.22745098039215686)
        _N2_ColorNoiseFreq ("Color Noise Freq", Float) = 5
        _N2_ColorNoiseSharpness ("Color Noise Sharpness", Float) = 5.5
        _N2_ColorNoiseStretching ("Color Noise Stretching", Vector) = (20, 1, 20)
        _N2_Octaves ("Noise Layers", Int) = 3
        _N2_Persistence ("Layer Persistence", Float) = 0.5
        _N2_Lacunarity ("Layer Density Increase", Float) = 2.0
    }
    SubShader
    {
        Tags { "RenderType"="Transparent" "Queue"="Transparent" "RenderPipeline"="UniversalPipeline" }
        
        LOD 100

        Pass
        {
            Tags {"LightMode"="UniversalForward"}
            Blend SrcAlpha OneMinusSrcAlpha
            ZWrite Off
            ZTest Always
            Cull Front
            
            HLSLPROGRAM

            #pragma target 3.0
            
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"
            #include "noiseSimplex.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float4 vertex : SV_POSITION;
                float3 worldPos : TEXCOORD0;
                float3 screenPos : TEXCOORD1;
                float3 viewSpacePos : TEXCOORD2;
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;
            float _SphereRadius;
            float _Density;
            float _FalloffExponent;
            float _LightAbsorption;
            float _RimStrength;
            float _RimSharpness;
            float4 _BaseColor;
            
            float4 _N1_NoiseColor;
            float _N1_ColorNoiseFreq;
            float _N1_ColorNoiseSharpness;
            float3 _N1_ColorNoiseStretching;
            int _N1_Octaves;
            float _N1_Persistence;
            float _N1_Lacunarity;
            
            float4 _N2_NoiseColor;
            float _N2_ColorNoiseFreq;
            float _N2_ColorNoiseSharpness;
            float3 _N2_ColorNoiseStretching;
            int _N2_Octaves;
            float _N2_Persistence;
            float _N2_Lacunarity;

            float3 _OmniLightPos;

            bool raySphere(float3 origin, float3 direction, float3 center, float radius, out float distanceToEntry, out float distanceToExit)
            {
                float3 oc = origin - center;
                float b = dot(oc, direction);
                float c = dot(oc, oc) - radius * radius;
                float h = b*b - c;
                if (h < 0) return false;
                h = sqrt(h);
                distanceToEntry = -b - h; // distance from origin to entry
                distanceToExit = -b + h; // distance from origin to exit
                return true;
            }

            float getLocalDensity(float density, float3 position, float3 sphereCenter, float sphereRadius, float FalloffExponent)
            {
                // 1 at center, 0 at edge
                float altitude01 = length(position - sphereCenter) / sphereRadius;
                float inverseAltitude = saturate(1.0 - altitude01);
    
                return density * pow(inverseAltitude, FalloffExponent);
            }

            void getDepthPixelWorldPos(float2 UV, out float3 depthWorldPos)
            {
                #if UNITY_REVERSED_Z
                    real depth = SampleSceneDepth(UV);
                #else
                    // Adjust Z to match NDC for OpenGL ([-1, 1])
                    real depth = lerp(UNITY_NEAR_CLIP_VALUE, 1, SampleSceneDepth(UV));
                #endif
                depthWorldPos = ComputeWorldSpacePosition(UV, depth, UNITY_MATRIX_I_VP);
            }

            void getDepthPixelWorldPos(float4 vertex, out float3 depthWorldPos)
            {
                float2 UV = vertex.xy / _ScaledScreenParams.xy;
                getDepthPixelWorldPos(UV, depthWorldPos);
            }
            
            v2f vert (appdata v)
            {
                v2f o;
                
                o.vertex = TransformObjectToHClip(v.vertex.xyz);
                o.worldPos = TransformObjectToWorld(v.vertex.xyz);
                o.screenPos = ComputeScreenPos(o.vertex);
                
                float3 positionWS = TransformObjectToWorld(v.vertex.xyz);
                o.viewSpacePos = TransformWorldToView(positionWS);
                
                return o;
            }
            
            float getLayeredNoise(float3 p, int octaves, float persistence, float lacunarity)
            {
                float amplitude = 1.0;
                float frequency = 1.0;
                float noiseValue = 0.0;
                float maxValue = 0.0; // Used for normalizing the result

                for(int i = 0; i < octaves; i++)
                {
                    // Add noise layer
                    noiseValue += snoise(p * frequency) * amplitude;
        
                    // Track max possible value for normalization
                    maxValue += amplitude;
        
                    // Prepare next layer: higher frequency, lower influence
                    amplitude *= persistence;
                    frequency *= lacunarity;
                }

                // Return normalized 0-1 value
                return noiseValue / maxValue;
            }

            float4 frag (v2f i) : SV_Target
            {
                float3 rayOrigin = _WorldSpaceCameraPos;
                float3 rayDirection = normalize(i.worldPos - rayOrigin);
                float3 sphereCenter = unity_ObjectToWorld._m03_m13_m23;
                float sphereRadius = _SphereRadius;

                float entry, exit;
                if (!raySphere(rayOrigin, rayDirection, sphereCenter, sphereRadius, entry, exit))
                    return float4(0,0,0,0);
                
                // scene depth
                float3 depthWorldPos;
                getDepthPixelWorldPos(i.vertex, depthWorldPos);
                float distanceToDepth = length(depthWorldPos - _WorldSpaceCameraPos);

                // clamp, clamp to depth
                entry = max(entry, 0);
                entry = min(entry, distanceToDepth);
                exit = min(exit, distanceToDepth);
                
                float3 entryPos = rayOrigin + rayDirection * entry;
                
                float midT = entry + max(0, exit - entry) * 0.5;
                float3 midTPos = rayOrigin + rayDirection * midT;

                // gas depth
                float maxGasDepth = _SphereRadius * 2;
                float gasDepth = min(exit - entry, maxGasDepth);
                float gasDepth01 = gasDepth / maxGasDepth;

                float localDensity = getLocalDensity(_Density, midTPos, sphereCenter, sphereRadius, _FalloffExponent);

                //alpha
                float alpha = gasDepth01 * localDensity;
                alpha = saturate(alpha);

                // noise sampling
                float3 noiseSamplePos = (rayOrigin + rayDirection * entry);
                noiseSamplePos = (noiseSamplePos - sphereCenter) / _SphereRadius;
                
                // Noise 1
                float3 n1_colorNoiseSamplePos = noiseSamplePos / _N1_ColorNoiseStretching;
                float n1_rawNoise = getLayeredNoise(n1_colorNoiseSamplePos * _N1_ColorNoiseFreq, _N1_Octaves, _N1_Persistence, _N1_Lacunarity);
                float n1_layeredNoise = smoothstep(0.5 - _N1_ColorNoiseSharpness * 0.1, 0.5 + _N1_ColorNoiseSharpness * 0.1, n1_rawNoise + 0.5);
                
                // Noise 1
                float3 n2_colorNoiseSamplePos = noiseSamplePos / _N2_ColorNoiseStretching;
                float n2_rawNoise = getLayeredNoise(n2_colorNoiseSamplePos * _N2_ColorNoiseFreq, _N2_Octaves, _N2_Persistence, _N2_Lacunarity);
                float n2_layeredNoise = smoothstep(0.5 - _N2_ColorNoiseSharpness * 0.1, 0.5 + _N2_ColorNoiseSharpness * 0.1, n2_rawNoise + 0.5);

                // Noise colors
                float3 col = lerp(_BaseColor.rgb, _N1_NoiseColor.rgb, saturate(n1_layeredNoise));
                col = lerp(col, _N2_NoiseColor, saturate(n2_layeredNoise));
                col = saturate(col);

                // Lighting
                Light mainLight = GetMainLight();
                float3 directionToLight = normalize(_OmniLightPos - entryPos);
                float3 lightColor = mainLight.color;

                float lightEntry, lightTravelDistance;
                raySphere(entryPos, directionToLight, sphereCenter, sphereRadius, lightEntry, lightTravelDistance);
                float lightMidT = lightTravelDistance * 0.5;
                float3 lightMidTPos = entryPos + directionToLight * lightMidT;
                float lightAvgPassthroughDensity = getLocalDensity(_Density, lightMidTPos, sphereCenter, sphereRadius, _FalloffExponent);
                float absorption = saturate(exp(-_LightAbsorption * lightAvgPassthroughDensity * lightTravelDistance));
                
                // Lambertian reflectance
                float3 normal = normalize(entryPos - sphereCenter);
                float diffuse = saturate(dot(normal, directionToLight));
                
                // Rim (Highlights the edges of the atmosphere)
                float rim = 1.0 - saturate(dot(normal, -rayDirection));
                float proximityFade = saturate(entry / (sphereRadius / 2));
                rim = pow(rim * diffuse * _RimStrength * proximityFade, _RimSharpness);
                
                float finalLight = diffuse * absorption + rim;

                // Final pixel color
                float3 litColor = col * finalLight * lightColor;

                return float4(saturate(litColor), alpha);
            }
            ENDHLSL
        }
    }
}
