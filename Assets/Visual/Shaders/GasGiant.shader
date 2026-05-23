Shader "Custom/GasGiant"
{
    Properties
    {
        _SphereRadius ("Sphere Radius", Float) = 300
        _Density ("Density", Float) = 10
        _FalloffExponent ("FalloffExponent", Float) = 0.1
        _LightAbsorption ("Light Absorption", Float) = 0.5
        _ColorNoiseFreq ("Color Noise Freq", Float) = 1
        _ColorNoiseSharpness ("Color Noise Sharpness", Float) = 2
        _ColorNoiseStretching ("Color Noise Stretching", Vector) = (50, 1, 50)
        _Color ("Color", Color) = (0, 0.5, 1)
        _SecondaryColor ("Secondary Color", Color) = (0, 1, 1)
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

            float4 _Color;
            float4 _SecondaryColor;
            
            float _ColorNoiseFreq;
            float _ColorNoiseSharpness;
            float3 _ColorNoiseStretching;

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
                float3 colorNoiseSamplePos = noiseSamplePos / _ColorNoiseStretching;
                
                // Octaves
                float n  = snoise(colorNoiseSamplePos * _ColorNoiseFreq);
                n += snoise(colorNoiseSamplePos * _ColorNoiseFreq * 2.5) * 0.5;
                float octavedNoise = saturate((n - 0.5) * _ColorNoiseSharpness + 0.5);
                
                // Noise colors
                float3 col = _Color.rgb * (1 - octavedNoise) + _SecondaryColor.rgb * octavedNoise;
                col = saturate(col);

                //lighting
                Light mainLight = GetMainLight();
                float3 directionToLight = normalize(_OmniLightPos - entryPos);
                float3 lightColor = mainLight.color;

                float lightEntry, lightTravelDistance;
                raySphere(entryPos, directionToLight, sphereCenter, sphereRadius, lightEntry, lightTravelDistance);
                float lightMidT = lightTravelDistance * 0.5;
                float3 lightMidTPos = entryPos + directionToLight * lightMidT;
                float lightAvgPassthroughDensity = getLocalDensity(_Density, lightMidTPos, sphereCenter, sphereRadius, _FalloffExponent);
                float trueLightFactor = exp(-_LightAbsorption * lightAvgPassthroughDensity * lightTravelDistance);
                
                float3 litColor = col * saturate(trueLightFactor) * lightColor;

                return float4(saturate(litColor), alpha);
            }
            ENDHLSL
        }
    }
}
