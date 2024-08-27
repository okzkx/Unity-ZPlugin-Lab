Shader "C1/River"
{
    Properties
    {
        [MainTexture] _BaseMap("Texture", 2D) = "white" {}
        [MainColor] _BaseColor("Color", Color) = (1, 1, 1, 1)

        _BumpMap("BumpMap", 2D) = "Bump"{}
        _SpecularSmoothness("SpecularSmoothness", Color) = (0, 0, 0, 1)
        [Toggle(_NORMALMAP)] _NORMALMAP("EnableNormal", int) = 1
        [Toggle(_SPECULAR_COLOR)] _SPECULAR_COLOR("EnableSpecular", int) = 1
    }
    SubShader
    {
        Tags
        {
            "RenderType" = "Opaque" "IgnoreProjector" = "True" "RenderPipeline" = "UniversalPipeline" "ShaderModel"="4.5"
        }
        LOD 100

        Pass
        {
            Name "River"

            HLSLPROGRAM
            #pragma target 4.5

            #pragma shader_feature_local _NORMALMAP
            #pragma shader_feature_local _SPECULAR_COLOR

            // -------------------------------------
            // Unity defined keywords
            #pragma multi_compile_fog
            #pragma multi_compile_instancing

            #pragma multi_compile _ DOTS_INSTANCING_ON
            #define BUMP_SCALE_NOT_SUPPORTED 1

            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/SurfaceInput.hlsl"

            // TEXTURE2D(_BaseMap);
            // float4 _BaseMap_ST;
            // SAMPLER(sampler_BaseMap);
            half4 _BaseColor;
            half4 _SpecularSmoothness;

            struct RiverAttributes
            {
                half4 positionOS : POSITION;
                float3 normalOS : NORMAL;
                float4 tangentOS : TANGENT;
                half2 texcoord : TEXCOORD0;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct RiverVaryings
            {
                float2 uv : TEXCOORD0;
                float3 posWS : TEXCOORD2; // xyz: posWS

                float4 normal : TEXCOORD3; // xyz: normal, w: viewDir.x
                float4 tangent : TEXCOORD4; // xyz: tangent, w: viewDir.y
                float4 bitangent : TEXCOORD5; // xyz: bitangent, w: viewDir.z

                half4 fogFactorAndVertexLight : TEXCOORD6; // x: fogFactor, yzw: vertex light

                float4 positionCS : SV_POSITION;

                UNITY_VERTEX_INPUT_INSTANCE_ID
                UNITY_VERTEX_OUTPUT_STEREO
            };


            void InitializeInputData(RiverVaryings input, half3 normalTS, out InputData inputData)
            {
                inputData = (InputData)0;
                inputData.positionWS = input.posWS;

                half3 viewDirWS = half3(input.normal.w, input.tangent.w, input.bitangent.w);
                inputData.normalWS = TransformTangentToWorld(
                    normalTS, half3x3(input.tangent.xyz, input.bitangent.xyz, input.normal.xyz));
                inputData.normalWS = NormalizeNormalPerPixel(inputData.normalWS);
                viewDirWS = SafeNormalize(viewDirWS);

                inputData.viewDirectionWS = viewDirWS;
                inputData.fogCoord = input.fogFactorAndVertexLight.x;
                inputData.vertexLighting = input.fogFactorAndVertexLight.yzw;
                inputData.normalizedScreenSpaceUV = GetNormalizedScreenSpaceUV(input.positionCS);
                inputData.shadowMask = SAMPLE_SHADOWMASK(input.lightmapUV);
            }

            RiverVaryings vert(RiverAttributes input)
            {
                RiverVaryings output = (RiverVaryings)0;

                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_TRANSFER_INSTANCE_ID(input, output);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

                VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS.xyz);
                VertexNormalInputs normalInput = GetVertexNormalInputs(input.normalOS, input.tangentOS);
                half3 viewDirWS = GetWorldSpaceViewDir(vertexInput.positionWS);
                half3 vertexLight = VertexLighting(vertexInput.positionWS, normalInput.normalWS);
                half fogFactor = ComputeFogFactor(vertexInput.positionCS.z);

                output.uv = input.texcoord + half2(- _Time.y * 0.5, 0);
                output.posWS.xyz = vertexInput.positionWS;
                output.positionCS = vertexInput.positionCS;

                output.normal = half4(normalInput.normalWS, viewDirWS.x);
                output.tangent = half4(normalInput.tangentWS, viewDirWS.y);
                output.bitangent = half4(normalInput.bitangentWS, viewDirWS.z);

                output.fogFactorAndVertexLight = half4(fogFactor, vertexLight);

                return output;
            }

            half4 frag(RiverVaryings input) : SV_Target
            {
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

                float2 uv = input.uv;
                half4 diffuseAlpha = SampleAlbedoAlpha(uv, TEXTURE2D_ARGS(_BaseMap, sampler_BaseMap));
                half3 diffuse = diffuseAlpha.rgb * _BaseColor.rgb;

                half alpha = diffuseAlpha.a * _BaseColor.a;
                AlphaDiscard(alpha, 0);

                half3 normalTS = SampleNormal(uv, TEXTURE2D_ARGS(_BumpMap, sampler_BumpMap));
                InputData inputData;
                InitializeInputData(input, normalTS, inputData);

                half4 color = UniversalFragmentBlinnPhong(inputData, diffuse, _SpecularSmoothness,
                                                          _SpecularSmoothness.a, 0, alpha);
                return color;
            }
            ENDHLSL
        }
    }
    FallBack "Hidden/InternalErrorShader"
}
