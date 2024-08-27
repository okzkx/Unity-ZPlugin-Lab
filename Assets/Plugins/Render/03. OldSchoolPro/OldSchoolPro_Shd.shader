Shader "Custom/OldSchoolPro" {
    Properties {
        [MainTexture] _MainTex ("RGB:基础颜色 A:环境遮罩", 2D) = "white" {}
        [NoScaleOffset][Normal] _NormTex ("RGB:法线贴图", 2D) = "bump" {}
        [NoScaleOffset] _SpecTex ("RGB:高光颜色 A:高光次幂", 2D) = "gray" {}
        [NoScaleOffset] _EmitTex ("RGB:环境贴图", 2D) = "black" {}
        [NoScaleOffset] _Cubemap ("RGB:环境贴图", cube) = "_Skybox" {}

        [Header(Diffuse)][Space(50)]
        _MainCol ("基本色", Color) = (0.5, 0.5, 0.5, 1.0)
        _EnvDiffInt ("环境漫反射强度", Range(0, 1)) = 0.2
        _NormalScale("NormalScale",Range(0,1))=1
        [HDR] _EnvUpCol ("环境天顶颜色", Color) = (1.0, 1.0, 1.0, 1.0)
        [HDR] _EnvSideCol ("环境水平颜色", Color) = (0.5, 0.5, 0.5, 1.0)
        [HDR] _EnvDownCol ("环境地表颜色", Color) = (0.0, 0.0, 0.0, 0.0)

        [Header(Specular)][Space(50)]
        [PowerSlider(2)] _SpecPow ("高光次幂", Range(1, 90)) = 30
        _EnvSpecInt ("环境镜面反射强度", Range(0, 5)) = 0.2
        _FresnelPow ("菲涅尔次幂", Range(0, 5)) = 1
        _CubemapMip ("环境球Mip", Range(0, 7)) = 0

        [Header(Emission)][Space(50)]
        _EmitInt ("自发光强度", range(1, 10)) = 1

        [Header(Outline)][Space(50)]
        _OutlineColor ("outline color", Color) = (0,0,0,1)
        _OutlineWidth ("outline width", Range(0, 1)) = 0.01
    }

    SubShader {

        Tags {
            "RenderType"="Opaque"
        }

        Pass {
            Name "Outline"
            Tags {
                "LightMode" = "ForwardOnly"
            }

            Cull Front

            HLSLPROGRAM
            #pragma vertex Vert
            #pragma fragment Frag

            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"
            #include "Packages/com.unity.render-pipelines.high-definition/Runtime/ShaderLibrary/ShaderVariables.hlsl"

            CBUFFER_START(UnityPerMaterial)

            uniform float4 _OutlineColor;
            uniform float _OutlineWidth;

            CBUFFER_END

            struct AttributesMesh
            {
                float3 positionOS : POSITION;
                float3 normalOS : NORMAL;
            };

            struct VaringsMeshToPs
            {
                float4 positionCS : SV_POSITION;
            };

            VaringsMeshToPs Vert(AttributesMesh inputMesh)
            {
                VaringsMeshToPs varings;
                float3 processedPositionOS = inputMesh.positionOS + inputMesh.normalOS * _OutlineWidth;
                varings.positionCS = TransformObjectToHClip(processedPositionOS);
                return varings;
            }

            float4 Frag(VaringsMeshToPs input) : COLOR
            {
                return float4(_OutlineColor.rgb, 1);
            }
            ENDHLSL
        }

        Pass {
            Name "Character"
            Tags {
                "LightMode" = "Forward"
            }
            HLSLPROGRAM
            #pragma vertex Vert
            #pragma fragment Frag

            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
            #pragma multi_compile _ _SHADOWS_SOFT//柔化阴影，得到软阴影


            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"
            #include "Packages/com.unity.render-pipelines.high-definition/Runtime/ShaderLibrary/ShaderVariables.hlsl"
            #include "../ShaderLibrary/CustomLight.hlsl"

            CBUFFER_START(UnityPerMaterial)

            // Texture
            uniform float4 _MainTex_ST;
            // Diffuse
            uniform float3 _MainCol;
            real _NormalScale;
            uniform float _EnvDiffInt;
            uniform float3 _EnvUpCol;
            uniform float3 _EnvSideCol;
            uniform float3 _EnvDownCol;
            // Specular
            uniform float _SpecPow;
            uniform float _FresnelPow;
            uniform float _EnvSpecInt;
            uniform float _CubemapMip;
            // Emission
            uniform float _EmitInt;

            CBUFFER_END

            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);

            TEXTURE2D(_NormTex);
            SAMPLER(sampler_NormTex);

            TEXTURE2D(_SpecTex);
            SAMPLER(sampler_SpecTex);

            TEXTURE2D(_EmitTex);
            SAMPLER(sampler_EmitTex);

            // TODO : Up grade CubeMap 
            samplerCUBE _Cubemap;


            struct AttributesMesh
            {
                float3 positionOS : POSITION;
                float2 uv0 : TEXCOORD0;
                float3 normalOS : NORMAL;
                float4 tangentOS : TANGENT;
            };

            struct VaringsMeshToPs
            {
                float4 positionCS : SV_POSITION;
                float2 texCoord0 : TEXCOORD0;
                float3 positionWS : TEXCOORD1;
                float3 normalWS : TEXCOORD2;
                float3 tangentWS : TEXCOORD3;
                float3 biTangentWS : TEXCOORD4;
            };

            VaringsMeshToPs Vert(AttributesMesh inputMesh)
            {
                VaringsMeshToPs varyings;
                varyings.positionCS = TransformObjectToHClip(inputMesh.positionOS);
                varyings.texCoord0 = TRANSFORM_TEX(inputMesh.uv0, _MainTex);
                varyings.positionWS = TransformObjectToWorld(inputMesh.positionOS);
                varyings.normalWS = TransformObjectToWorldNormal(inputMesh.normalOS, true);
                varyings.tangentWS = TransformObjectToWorldDir(inputMesh.tangentOS.xyz, true); // 切线方向 OS>WS
                varyings.biTangentWS = cross(varyings.normalWS, varyings.tangentWS) * sign(inputMesh.tangentOS.w); // 副切线方向
                return varyings;
            }


            // 三颜色（顶，侧，底）插值环境光方法
            float3 TriColAmbient(float3 n, float3 uCol, float3 sCol, float3 dCol)
            {
                float uMask = max(0.0, n.g); // 获取朝上部分遮罩
                float dMask = max(0.0, -n.g); // 获取朝下部分遮罩
                float sMask = 1.0 - uMask - dMask; // 获取侧面部分遮罩
                float3 envCol = uCol * uMask +
                    sCol * sMask +
                    dCol * dMask; // 混合环境色
                return envCol;
            }

            float4 Frag(VaringsMeshToPs input) : COLOR //像素shader
            {
                // 准备向量
                float3 normalTS = UnpackNormalScale(SAMPLE_TEXTURE2D(_NormTex, sampler_NormTex, input.texCoord0), _NormalScale);

                // 采样法线纹理并解码 切线空间nDir
                float3x3 tangentToWorldMatrix = float3x3(input.tangentWS, input.biTangentWS, input.normalWS);
                float3 normalWS = normalize(mul(normalTS, tangentToWorldMatrix));
                float3 viewWS = normalize(_WorldSpaceCameraPos.xyz - input.positionWS.xyz);
                float3 viewReflectWS = reflect(-viewWS, normalWS);
                SimpleLight mylight = GetSimpleLight();
                float3 lightWS = mylight.directionWS;
                float3 lightReflectWS = reflect(-lightWS, normalWS);

                // 准备点积结果
                float ndotl = dot(normalWS, lightWS);
                float vdotr = dot(viewWS, lightReflectWS);
                float vdotn = dot(viewWS, normalWS);

                // 采样纹理
                float4 var_MainTex = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, input.texCoord0);
                float4 var_SpecTex = SAMPLE_TEXTURE2D(_SpecTex, sampler_SpecTex, input.texCoord0);
                float3 var_EmitTex = SAMPLE_TEXTURE2D(_EmitTex, sampler_EmitTex, input.texCoord0).rgb;

                // 采样Cubemap
                float3 var_Cubemap = texCUBElod(_Cubemap, float4(viewReflectWS, lerp(_CubemapMip, 0.0, var_SpecTex.a))).rgb;

                // 光照模型(直接光照部分)
                float3 baseCol = var_MainTex.rgb;
                float lambert = max(0.0, ndotl);
                float3 specCol = var_SpecTex.rgb;
                float specPow = lerp(1, _SpecPow, var_SpecTex.a);
                float phong = pow(max(0.0, vdotr), specPow);
                float3 dirLighting = baseCol * lambert * mylight.color + specCol * phong;

                // 光照模型(环境光照部分)
                float3 envCol = TriColAmbient(normalWS, _EnvUpCol, _EnvSideCol, _EnvDownCol);
                float fresnel = pow(max(0.0, 1.0 - vdotn), _FresnelPow); // 菲涅尔
                float occlusion = var_MainTex.a;
                float3 envLighting = (baseCol * envCol * _EnvDiffInt + var_Cubemap * fresnel * _EnvSpecInt * var_SpecTex.a) * occlusion;

                // 光照模型(自发光部分)
                float3 emission = var_EmitTex * _EmitInt * (sin(_Time.z) * 0.5 + 0.5);

                return float4(dirLighting + envLighting + emission, 1.0);
            }
            ENDHLSL
        }
    }
}