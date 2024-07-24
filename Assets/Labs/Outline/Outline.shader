Shader "ZPlugin/Outline"
{
    Properties
    {
        [MainColor] _BaseColor("Base Color", Color) = (1, 1, 1, 1)
        _OutlineWidth ("Outline Width", Range(0.0, 5.0)) = 0.008
    }
    SubShader
    {

        Name "Outline"
        Tags
        {
            "RenderType"="Opaque"
            "LightMode" = "SRPDefaultUnlit"
        }

        Cull Front
        ZTest On

        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            // make fog work
            #pragma multi_compile_fog

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            CBUFFER_START(UnityPerMaterial)
                half4 _BaseColor;
                half _OutlineWidth;
            CBUFFER_END

            struct attributes
            {
                float3 positionOS : POSITION;
                half3 normalOS : NORMAL;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };


            struct varyings
            {
                float4 positionCS : SV_POSITION;
                UNITY_VERTEX_INPUT_INSTANCE_ID
                UNITY_VERTEX_OUTPUT_STEREO
            };

            varyings vert(attributes input)
            {
                varyings o = (varyings)0;
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_TRANSFER_INSTANCE_ID(input, o);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);
                input.positionOS += input.normalOS * _OutlineWidth / 100;
                VertexPositionInputs vpi = GetVertexPositionInputs(input.positionOS);
                o.positionCS = vpi.positionCS;
                return o;
            }

            half4 frag(varyings i) : SV_Target
            {
                UNITY_SETUP_INSTANCE_ID(i);
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(i);

                float tint = (sin(_Time.z) + 1) * 0.5;

                return tint * _BaseColor;
            }
            ENDHLSL
        }
    }
}