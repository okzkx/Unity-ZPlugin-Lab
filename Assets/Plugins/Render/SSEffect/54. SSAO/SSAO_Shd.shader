Shader "Custom/SSAO" {
    Properties {
        _LightIntencity("光照强度", Float) = 4
        [MainColor]_BaseColor("漫反射颜色",Color)=(1,1,1,1)
        [MainTexture]_MainTex("表面纹理",2D)="white"{}
        _SpecularPow ("高光锐利度", Range(1,90)) =30
        _SpecularColor ("高光颜色", color) =(1.0,1.0,1.0,1.0)
    }

    HLSLINCLUDE
    //-------------------------------------------------------------------------------------
    // library include
    //-------------------------------------------------------------------------------------

    // HDRP Library

    #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"
    #include "Packages/com.unity.render-pipelines.high-definition/Runtime/ShaderLibrary/ShaderVariables.hlsl"

    // Local library

    #include "../ShaderLibrary/CustomLight.hlsl"

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
    ENDHLSL

    SubShader {
        Tags {
            "RenderPipeline"="HDRenderPipeline"
        }

        // Prepare NormalBuffer for SSAO state to generate _AmbientOcclusionTexture
        Pass {
            Name "DepthOnly"
            Tags {
                "LightMode" = "DepthOnly"
            }

            HLSLPROGRAM
            #pragma vertex Vert
            #pragma fragment Frag

            VaryingsMeshToPS Vert(AttributesMesh inputMesh)
            {
                VaryingsMeshToPS varyings = (VaryingsMeshToPS)0;
                varyings.positionCS = TransformObjectToHClip(inputMesh.positionOS);
                varyings.normalWS = TransformObjectToWorldNormal(inputMesh.normalOS, true);
                return varyings;
            }

            void Frag(VaryingsMeshToPS input, out float4 outNormalBuffer : SV_Target0)
            {
                // Adapt from
                // ShaderPassDepthOnly.hlsl : Frag()
                // NormalBuffer.hlsl : EncodeIntoNormalBuffer()
                const float seamThreshold = 1.0 / 1024.0;
                input.normalWS.z = CopySign(max(seamThreshold, abs(input.normalWS.z)), input.normalWS.z);
                float2 octNormalWS = PackNormalOctQuadEncode(input.normalWS);
                float3 packNormalWS = PackFloat2To888(saturate(octNormalWS * 0.5 + 0.5));
                outNormalBuffer = float4(packNormalWS, 0.5);
            }
            ENDHLSL
        }

        Pass {
            Name "FORWARD"
            Tags {
                "LightMode"="ForwardOnly"
            }

            HLSLPROGRAM
            #pragma vertex Vert
            #pragma fragment Frag

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
                SimpleLight simpleLight = GetSimpleLight();
                float4 positionSS = input.positionCS;
                float3 lightWS = simpleLight.directionWS;

                // L(Luminance) : Radiance input
                float3 Li = simpleLight.color;

                // E(Illuminance) : To simulate the Irradiance in BRDF
                float3 E = Li * saturate(dot(input.normalWS, lightWS)) * _LightIntencity;

                // Half Lambert
                E = E * 0.5 + 0.5;

                // SSAO
                // Adapt form MaterialEvaluation.hlsl : GetScreenSpaceAmbientOcclusion()
                // if there isn't SSAO Stage,
                // _AmbientOcclusionTexture will be 0 every where, and indirectAmbientOcclusion will be 1
                float indirectAmbientOcclusion = 1.0 - LOAD_TEXTURE2D_X(_AmbientOcclusionTexture, positionSS.xy).x;
                E *= indirectAmbientOcclusion;

                // Specular : Bling-Phone
                float3 viewWS = normalize(_WorldSpaceCameraPos.xyz - input.positionWS);
                float3 halfWS = normalize(viewWS + lightWS);
                float specularFactor = pow(max(0.0, dot(input.normalWS, halfWS)), _SpecularPow);
                float3 specular = specularFactor * _SpecularColor.rgb;

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