Shader "Custom/Unlit"
{
    Properties
    {
        [MainColor] _BaseColor("BaseColor",Color)=(1,1,1,1)
        [MainTexture] _MainTex("MainTex",2D)="white"{}
    }

    SubShader
    {
        Tags
        {
            "RenderPipeline" = "UniversalPipeline"
        }

        Pass
        {
            Name "ForwardLit"
            Tags
            {
                "LightMode" = "UniversalForward"
            }

            HLSLPROGRAM
            #pragma vertex Vert
            #pragma fragment Frag

            //-------------------------------------------------------------------------------------
            // library include
            //-------------------------------------------------------------------------------------

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            //-------------------------------------------------------------------------------------
            // variable declaration
            //-------------------------------------------------------------------------------------

            struct AttributesMesh
            {
                float3 positionOS : POSITION;
                float2 uv0 : TEXCOORD0;
            };

            struct VaryingsMeshToPS
            {
                float4 positionCS : SV_Position;
                float2 texCoord0 : TEXCOORD0;
            };

            //-------------------------------------------------------------------------------------
            // properties declaration
            //-------------------------------------------------------------------------------------

            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);

            CBUFFER_START(UnityPerMaterial)
                float4 _BaseColor;
                float4 _MainTex_ST;
            CBUFFER_END

            //-------------------------------------------------------------------------------------
            // functions
            //-------------------------------------------------------------------------------------

            VaryingsMeshToPS Vert(AttributesMesh inputMesh)
            {
                VaryingsMeshToPS output;
                output.positionCS = TransformObjectToHClip(inputMesh.positionOS);
                output.texCoord0 = inputMesh.uv0;
                return output;
            }

            void Frag(VaryingsMeshToPS input, out float4 outColor:SV_Target0)
            {
                float2 uv = TRANSFORM_TEX(input.texCoord0.xy, _MainTex);
                float3 albedo = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv).rgb * _BaseColor.rgb;

                outColor = float4(albedo, 1);
            }
            ENDHLSL
        }
    }
}