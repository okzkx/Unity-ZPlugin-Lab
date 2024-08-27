Shader "C1/Distortion2" {
    Properties {
        [NoScaleOffset]_BaseMap("BaseMap", 2D) = "white" {}
        _DistortionScale("DistortionScale", Float) = 0.07
    }

    SubShader {
        Tags {
            "RenderType" = "Transparent"
            "Queue" = "Transparent+0"
            "IgnoreProjector" = "True"
            "RenderPipeline" = "UniversalPipeline"
            "LightMode" = "PostEffect"
        }
        Cull Back
        ZWrite Off
        Blend SrcAlpha OneMinusSrcAlpha

        Pass {
            HLSLPROGRAM
            #pragma vertex Vertex
            #pragma fragment Fragment

            // HDRP Library

            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"
            #include "Packages/com.unity.render-pipelines.high-definition/Runtime/ShaderLibrary/ShaderVariables.hlsl"

            TEXTURE2D(_BaseMap);
            SAMPLER(sampler_BaseMap);
            TEXTURE2D(_GrabPassTexture);
            SAMPLER(sampler_GrabPassTexture_linear_clamp);

            half _DistortionScale;

            struct Attribute
            {
                half4 positionOS : POSITION;
                half4 color : COLOR;
                half2 texcoord: TEXCOORD0;
            };

            struct Varyings
            {
                half4 positionCS : SV_POSITION;
                half2 uv : TEXCOORD0;
                half4 positionSS : TEXCOORD1;
                half4 color : TEXCOORD2;
            };


            Varyings Vertex(Attribute v)
            {
                Varyings output = (Varyings)0;
                output.positionCS = TransformObjectToHClip(v.positionOS.xyz);
                output.uv = v.texcoord;
                output.color = v.color;
                return output;
            }

            half4 Fragment(Varyings input): SV_Target
            {
                half2 screenUV = input.positionCS.xy / _ScreenParams.xy;
                half2 samplerUV = screenUV + SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, input.uv).rg * _DistortionScale * input.color.a;
                half4 color = SAMPLE_TEXTURE2D(_GrabPassTexture, sampler_GrabPassTexture_linear_clamp, samplerUV);
                return color;
            }
            ENDHLSL
        }
    }
    FallBack "Hidden/InternalErrorShader"
}