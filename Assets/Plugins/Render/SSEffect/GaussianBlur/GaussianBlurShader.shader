Shader "ZPlugin/GaussianBlurShader" {
    HLSLINCLUDE
    #pragma vertex Vert

    #pragma target 4.5
    #pragma only_renderers d3d11 playstation xboxone vulkan metal switch

    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/ShaderVariablesFunctions.hlsl"
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"

        #include "Packages/com.unity.render-pipelines.core/Runtime/Utilities/Blit.hlsl"

// Function defines
#define SCREEN_PARAMS               GetScaledScreenParams()
#define SAMPLE_BASEMAP(uv)          half4(SAMPLE_TEXTURE2D_X(_BlitTexture, sampler_BlitTexture, UnityStereoTransformScreenSpaceTex(uv)));
    SAMPLER(sampler_BlitTexture);

float4 _SSAOParams;
float4 _SourceSize;
    
#define INTENSITY _SSAOParams.x
#define RADIUS _SSAOParams.y
#define DOWNSAMPLE _SSAOParams.z

    static const half  HALF_ZERO        = half(0.0);
static const half  HALF_HALF        = half(0.5);
static const half  HALF_ONE         = half(1.0);
    
    // struct Attributes
    // {
    //     uint vertexID : SV_VertexID;
    //     UNITY_VERTEX_INPUT_INSTANCE_ID
    // };
    //
    // struct Varyings
    // {
    //     float4 positionCS : SV_POSITION;
    //     UNITY_VERTEX_OUTPUT_STEREO
    // };

// ------------------------------------------------------------------
// Gaussian Blur
// ------------------------------------------------------------------

// https://software.intel.com/content/www/us/en/develop/blogs/an-investigation-of-fast-real-time-gpu-based-image-blur-algorithms.html
half3 GaussianBlur(half2 uv, half2 pixelOffset)
{
    half3 colOut = 0;

    // Kernel width 7 x 7
    const int stepCount = 2;

    const half gWeights[stepCount] ={
       0.44908,
       0.05092
    };
    const half gOffsets[stepCount] ={
       0.53805,
       2.06278
    };

    UNITY_UNROLL
    for( int i = 0; i < stepCount; i++ )
    {
        half2 texCoordOffset = gOffsets[i] * pixelOffset;
        half4 p1 = SAMPLE_BASEMAP(uv + texCoordOffset);
        half4 p2 = SAMPLE_BASEMAP(uv - texCoordOffset);
        half3 col = p1.rgb + p2.rgb;
        colOut += gWeights[i] * col;
    }

    return colOut;
}

half4 HorizontalGaussianBlur(Varyings input) : SV_Target
{
    UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

    half2 uv = input.texcoord;
    // half2 delta = half2(_SourceSize.z * rcp(DOWNSAMPLE), HALF_ZERO);
    // half2 delta = half2(_ScreenParams.x * rcp(DOWNSAMPLE), HALF_ZERO);
    half2 delta = half2( (1 / _ScreenParams.x) * rcp(DOWNSAMPLE), HALF_ZERO);

    return half4( GaussianBlur(uv, delta), 1);
}

half4 VerticalGaussianBlur(Varyings input) : SV_Target
{
    UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

    half2 uv = input.texcoord;
    // half2 delta = half2(HALF_ZERO, _SourceSize.w * rcp(DOWNSAMPLE));
    half2 delta = half2(HALF_ZERO, (1 /_ScreenParams.y) * rcp(DOWNSAMPLE));

    // return HALF_ONE - GaussianBlur(uv, delta);
    return half4(GaussianBlur(uv, delta), 1);
    // return half4(1,0,0,1);
}


    // Varyings Vert(Attributes input)
    // {
    //     Varyings output;
    //     UNITY_SETUP_INSTANCE_ID(input);
    //     UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);
    //     output.positionCS = GetFullScreenTriangleVertexPosition(input.vertexID, UNITY_RAW_FAR_CLIP_VALUE);
    //     return output;
    // }

    // float4 FullScreenPass(Varyings varyings) : SV_Target
    // {
    //     UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(varyings);
    //     
    //
    // }
    ENDHLSL

    SubShader {
        Pass {
            Name "Custom Pass 0"

            ZWrite Off
            ZTest Always
            Blend SrcAlpha OneMinusSrcAlpha
            Cull Off

            HLSLPROGRAM
            #pragma fragment HorizontalGaussianBlur
            ENDHLSL
        }

        Pass {
            Name "Custom Pass 0"

            ZWrite Off
            ZTest Always
            Blend SrcAlpha OneMinusSrcAlpha
            Cull Off

            HLSLPROGRAM
            #pragma fragment VerticalGaussianBlur
            ENDHLSL
        }
    }
    Fallback Off
}