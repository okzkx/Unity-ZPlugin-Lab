Shader "ZPlugin/SimpleLit"
{
    Properties
    {
        _LightIntencity("光照强度", Float) = 4
        [KeywordEnum(Lambert, Half_Lambert)] _Diffuse("漫反射模型", Float) = 0
        [MainColor]_BaseColor("漫反射颜色",Color)=(1,1,1,1)
        [MainTexture]_MainTex("表面纹理",2D)="white"{}
        [KeywordEnum(None, Phone, Bling_Phone)] _Specular("漫反射模型", Float) = 0
        _SpecularPow ("高光锐利度", Range(1,90)) =30
        _SpecularColor ("高光颜色", color) =(1.0,1.0,1.0,1.0)
    }

    SubShader
    {
        Tags
        {
            "RenderPipeline" = "UniversalPipeline"
        }

        Pass
        {
            Name "ForwardSimpleLit"
            Tags
            {
                "LightMode" = "UniversalForward"
            }

            HLSLPROGRAM
            #pragma multi_compile _DIFFUSE_LAMBERT _DIFFUSE_HALF_LAMBERT
            #pragma multi_compile _SPECULAR_NONE _SPECULAR_PHONE _SPECULAR_BLING_PHONE

            #pragma vertex Vert
            #pragma fragment Frag


            //-------------------------------------------------------------------------------------
            // library include
            //-------------------------------------------------------------------------------------

            // HDRP Library

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            // Local library

            // #include "../ShaderLibrary/CustomLight.hlsl"

            //-------------------------------------------------------------------------------------
            // variable declaration
            //-------------------------------------------------------------------------------------

            struct AttributesMesh
            {
                float3 positionOS : POSITION;
                float3 normalOS : NORMAL;
                float2 uv0:TEXCOORD;
            };

            struct VaryingsMeshToPS
            {
                float4 positionCS : SV_POSITION;
                float2 texCoord0 : TEXCOORD0;
                float3 normalWS : TEXCOORD1;
                float3 positionWS : TEXCOORD2;
            };

            //-------------------------------------------------------------------------------------
            // properties declaration
            //-------------------------------------------------------------------------------------

            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);

            CBUFFER_START(UnityPerMaterial)
                float _LightIntencity;
                float4 _MainTex_ST;
                float4 _BaseColor;
                float _SpecularPow;
                float4 _SpecularColor;

            CBUFFER_END

            //-------------------------------------------------------------------------------------
            // functions
            //-------------------------------------------------------------------------------------

            VaryingsMeshToPS Vert(AttributesMesh inputMesh)
            {
                VaryingsMeshToPS varyings;
                varyings.positionCS = TransformObjectToHClip(inputMesh.positionOS);
                varyings.texCoord0 = TRANSFORM_TEX(inputMesh.uv0, _MainTex);
                varyings.normalWS = TransformObjectToWorldNormal(inputMesh.normalOS, true);
                varyings.positionWS = TransformObjectToWorld(inputMesh.positionOS);
                return varyings;
            }

            float4 Frag(VaryingsMeshToPS input): SV_Target0
            {
                Light light = GetMainLight();
                // SimpleLight simpleLight = GetSimpleLight();
                // simpleLight.color = light.color;
                // simpleLight.directionWS = light.direction;
                float3 lightWS = normalize(light.direction);

                // L(Luminance) : Radiance input
                float3 Li = light.color;
                // E(Illuminance) : To simulate the Irradiance in BRDF
                float3 E = Li * saturate(dot(input.normalWS, lightWS)) * _LightIntencity;

                #if defined(_DIFFUSE_HALF_LAMBERT)
                    E = E * 0.5 + 0.5;
                #endif

                float3 specular = 0;

                // Specular
                #if !defined(_SPECULAR_NONE)
                    float3 viewWS = normalize(_WorldSpaceCameraPos.xyz - input.positionWS);
                    float specularFactor = 0;
                #if defined(_SPECULAR_PHONE)
                    float3 reflectWS = reflect(-lightWS, input.normalWS);
                    specularFactor = pow(max(0.0, dot(reflectWS, viewWS)), _SpecularPow);
                #else // Defined _SPECULAR_BLING_PHONE
                    float3 halfWS = normalize(viewWS + lightWS);
                    specularFactor = pow(max(0.0, dot(input.normalWS, halfWS)), _SpecularPow);
                #endif
                    specular = specularFactor * _SpecularColor.rgb;
                #endif

                // albedo : material surface color
                float3 albedo = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, input.texCoord0).rgb * _BaseColor.rgb;
                // Resolve render equation in fake brdf
                float3 Lo = (albedo / PI + specular) * E;

                return float4(Lo, 1);
            }
            ENDHLSL
        }
    }
}