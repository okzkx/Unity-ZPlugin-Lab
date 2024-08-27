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

        Pass {
            Name "ShadowCaster"
            Tags {
                "LightMode" = "ShadowCaster"
            }

            HLSLPROGRAM
            #pragma vertex Vert
            #pragma fragment Frag

            VaryingsMeshToPS Vert(AttributesMesh inputMesh)
            {
                VaryingsMeshToPS varyings = (VaryingsMeshToPS)0;
                varyings.positionCS = TransformObjectToHClip(inputMesh.positionOS);
                return varyings;
            }

            float4 Frag(VaryingsMeshToPS input): SV_Target0
            {
                // Ignore Bias Otimize 
                // // If we are using the depth offset and manually outputting depth, the slope-scale depth bias is not properly applied
                // // we need to manually apply.
                // float bias = max(abs(ddx(posInput.deviceDepth)), abs(ddy(posInput.deviceDepth))) * _SlopeScaleDepthBias;
                // outputDepth += bias;

                return 0;
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