
Shader "C1/SeaTerrain"
{
    Properties
    {
        [MainTexture] _BaseMap("Texture", 2D) = "white" {}
        [MainColor] _BaseColor("Color", Color) = (1, 1, 1, 1)

        _DeepWaterColor("DeepWaterColor", Color) = (1, 1,1, 1)
        _ShallowWaterColor("ShallowWaterColor", Color) = (1, 1,1, 1)
        _PlainColor("PlainColor", Color) = (1,1,1,1)
        _HighlandColor("HighlandColor", Color)= (1,1,1,1)
        _LoessColor("LoessColor", Color)= (1,1,1,1)
        _GrassColor("GrassColor", Color)= (0,1,0,1)
    }
    SubShader
    {
        Tags
        {
            "RenderType" = "Opaque" "IgnoreProjector" = "True" "RenderPipeline" = "UniversalPipeline" "ShaderModel"="4.01"
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
            #include "Noise.hlsl"

            half4 _BaseColor;
            half4 _DeepWaterColor;
            half4 _ShallowWaterColor;
            half4 _PlainColor;
            half4 _HighlandColor;
            half4 _LoessColor;
            half4 _GrassColor;

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

                output.uv = input.texcoord + half2(- _Time.y * 0.01, 0);
                output.posWS.xyz = vertexInput.positionWS;
                output.positionCS = vertexInput.positionCS;

                output.normal = half4(normalInput.normalWS, viewDirWS.x);
                output.tangent = half4(normalInput.tangentWS, viewDirWS.y);
                output.bitangent = half4(normalInput.bitangentWS, viewDirWS.z);

                output.fogFactorAndVertexLight = half4(fogFactor, vertexLight);

                return output;
            }

            void InitializeInputData(RiverVaryings input, out InputData inputData)
            {
                inputData = (InputData)0;
                inputData.positionWS = input.posWS;

                half3 viewDirWS = half3(input.normal.w, input.tangent.w, input.bitangent.w);
                half3 groundNormal = SampleNormalWSFromNoise(input.posWS.xz);
                half3 seaNormal = SampleNormalWSFromNoise(
                    input.posWS.xz + (1 - step(5.01, input.posWS.y)) * _Time.y * 10);

                inputData.normalWS = normalize(groundNormal + seaNormal);

                viewDirWS = SafeNormalize(viewDirWS);

                inputData.viewDirectionWS = viewDirWS;
                inputData.fogCoord = input.fogFactorAndVertexLight.x;
                inputData.vertexLighting = input.fogFactorAndVertexLight.yzw;
                inputData.normalizedScreenSpaceUV = GetNormalizedScreenSpaceUV(input.positionCS);
                inputData.shadowMask = SAMPLE_SHADOWMASK(input.lightmapUV);
            }

            half4 GetBaseColor(half3 position, half3 normal)
            {
                half4 baseColor = 0;

                half groundHeight = position.y;

                half w1 = 0;
                half w2 = 0;
                half w3 = 0;
                half w4 = 0;

                // 深海
                if (groundHeight < 1.01)
                {
                    w1 = 1;
                }
                    // 浅海
                else if (groundHeight < 2.01)
                {
                    w1 = 1 - abs(groundHeight - 1.01) / 1;
                    w2 = 1 - abs(groundHeight - 2.01) / 1;
                }
                    // 海内陆地
                else if (groundHeight < 5.01)
                {
                    w2 = 1 - abs(groundHeight - 2.01) / 3 / 4;
                    w3 = 1 - abs(groundHeight - 5.01) / 3;
                }
                    // 平原
                else if (groundHeight < 7.01)
                {
                    // w2 = 1 - abs(groundHeight - 2.01) / 5;
                    w3 = 1 - abs(groundHeight - 7.01) / 5;
                }
                    // 高原
                else if (groundHeight < 10.01)
                {
                    w3 = 1 - abs(groundHeight - 7.01) / 3;
                    w4 = 1 - abs(groundHeight - 10.01) / 3;
                }
                    // 高原以上
                else
                {
                    w4 = 1;
                }

                half tw = w1 + w2 + w3 + w4;

                half grassScale = noise_sum_abs_simplex(position.xz * 0.01) * dot(normal, half3(0, 1, 0));
                half loessScale = pow(abs(dot(normal, half3(0, 1, 0))), 16);
                half4 loessColor = lerp(_LoessColor, _GrassColor, grassScale);

                baseColor = w1 / tw * _DeepWaterColor +
                    w2 / tw * _ShallowWaterColor +
                    w3 / tw * lerp(_PlainColor, loessColor, loessScale) +
                    // w4 / tw * _HighlandColor;
                    w4 / tw * lerp(_HighlandColor, loessColor, loessScale);

                return baseColor;
            }

            half4 frag(RiverVaryings input) : SV_Target
            {
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

                half3 normalWS = input.normal.xyz;
                half4 baseColor = GetBaseColor(input.posWS, normalWS);

                float2 uv = input.uv;
                half4 diffuseAlpha = SampleAlbedoAlpha(uv, TEXTURE2D_ARGS(_BaseMap, sampler_BaseMap));
                half3 diffuse = diffuseAlpha.rgb * baseColor.rgb;

                InputData inputData;
                InitializeInputData(input, inputData);

                half4 color = UniversalFragmentBlinnPhong(inputData, diffuse, 0, 0, 0, 1);
                return color;
            }
            ENDHLSL
        }
    }
    FallBack "Hidden/InternalErrorShader"
}
