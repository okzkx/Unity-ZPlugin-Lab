Shader "Hidden/Outline" {
    HLSLINCLUDE
    #pragma vertex Vert

    #pragma target 4.5
    #pragma only_renderers d3d11 playstation xboxone vulkan metal switch

    // #include "Packages/com.unity.render-pipelines.high-definition/Runtime/RenderPipeline/RenderPass/CustomPass/CustomPassCommon.hlsl"
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/ShaderVariablesFunctions.hlsl"
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"
    // #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/ShaderVariablesGlobal.hlsl"
    // #include "Packages/com.unity.render-pipelines.universal/Shaders/LitForwardPass.hlsl"

    TEXTURE2D_X(_OutlineBuffer);
    SAMPLER(s_linear_clamp_sampler);

    float4 _OutlineColor;
    float _Threshold;

    #define v2 1.41421
    #define c45 0.707107
    #define c225 0.9238795
    #define s225 0.3826834

    #define MAXSAMPLES 8
    // Neighbour pixel positions
    static float2 samplingPositions[MAXSAMPLES] =
    {
        float2(1, 1),
        float2(0, 1),
        float2(-1, 1),
        float2(-1, 0),
        float2(-1, -1),
        float2(0, -1),
        float2(1, -1),
        float2(1, 0),
    };

    // struct AttributesMesh
    // {
    //     float3 positionOS : POSITION;
    //     float2 uv0 : TEXCOORD0;
    // };
    //
    // struct Varyings
    // {
    //     float4 positionCS : SV_POSITION;
    //     float2 uv : TEXCOORD0;
    // };
    //
    // Varyings Vert(AttributesMesh inputMesh)
    // {
    //     Varyings output;
    //     output.positionCS = TransformObjectToHClip(inputMesh.positionOS);
    //     output.uv = inputMesh.uv0;
    //     return output;
    // }

    struct Attributes
    {
        uint vertexID : SV_VertexID;
        UNITY_VERTEX_INPUT_INSTANCE_ID
    };

    struct Varyings
    {
        float4 positionCS : SV_POSITION;
        UNITY_VERTEX_OUTPUT_STEREO
    };

    Varyings Vert(Attributes input)
    {
        Varyings output;
        UNITY_SETUP_INSTANCE_ID(input);
        UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);
        output.positionCS = GetFullScreenTriangleVertexPosition(input.vertexID, UNITY_RAW_FAR_CLIP_VALUE);
        return output;
    }

    float4 FullScreenPass(Varyings varyings) : SV_Target
    {
        UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(varyings);


        float4 _RTHandleScale = GetScaledScreenParams() / _ScreenParams;
        // float4 _RTHandleScale = float4(1, 1, 0, 0);

        // float depth = LoadCameraDepth(varyings.positionCS.xy);
        float depth = SampleSceneDepth(varyings.positionCS.xy);
        PositionInputs posInput = GetPositionInput(varyings.positionCS.xy, _ScreenSize.zw, depth, UNITY_MATRIX_I_VP, UNITY_MATRIX_V);

        // return float4( posInput.positionNDC,0,1);
        // return float4( posInput.deviceDepth, 0,0,1);

        float4 color = float4(0.0, 0.0, 0.0, 0.0);
        float luminanceThreshold = max(0.000001, _Threshold * 0.01);

        // Load the camera color buffer at the mip 0 if we're not at the before rendering injection point
        // if (_CustomPassInjectionPoint != CUSTOMPASSINJECTIONPOINT_BEFORE_RENDERING)
        //     color = float4(CustomPassSampleCameraColor(posInput.positionNDC.xy, 0), 1);

        // When sampling RTHandle texture, always use _RTHandleScale.xy to scale your UVs first.
        float2 uv = posInput.positionNDC.xy * _RTHandleScale.xy;
        // return float4(uv, 0, 1);
        float4 outline = SAMPLE_TEXTURE2D_X_LOD(_OutlineBuffer, s_linear_clamp_sampler, uv, 0);
        outline.a = 0;

        if (Luminance(outline.rgb) < 0.000001)
        {
            for (int i = 0; i < MAXSAMPLES; i++)
            {
                float2 uvN = uv + _ScreenSize.zw * _RTHandleScale.xy * samplingPositions[i] * _Threshold;
                float4 neighbour = SAMPLE_TEXTURE2D_X_LOD(_OutlineBuffer, s_linear_clamp_sampler, uvN, 0);
            
            if (Luminance(neighbour) > 0.000001)
            {
                    outline.rgb = _OutlineColor.rgb;
                    outline.a = 1;
                    break;
                }
            }
        }

        return outline;
    }
    ENDHLSL

    SubShader {
        Pass {
            Name "Custom Pass 0"

            ZWrite Off
            ZTest Always
            Blend SrcAlpha OneMinusSrcAlpha
            Cull Off

            HLSLPROGRAM
            #pragma fragment FullScreenPass
            ENDHLSL
        }
    }
    Fallback Off
}