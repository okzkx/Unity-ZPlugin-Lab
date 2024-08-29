Shader "C1/Sea"
{
    Properties
    {
        _MaxDepth("MaxDepth", Float) = 100
        _WaterColor("WaterColor", Color) = (1,1,1,1)
        _Moss("Moss", Color) = (1,1,1,1)
        _SmoothnessWater("Smoothness", Float) = 8
        _SpecularIntensity("SpecularIntensity", Range(0,1)) = 0.1
        _ReflactionIntensity("ReflactionIntensity", Range(0,1)) = 0.1
        [NoScaleOffset]_SurfaceMap ("SurfaceMap", 2D) = "bump" {}
        [NoScaleOffset]_FoamMap ("FoamMap", 2D) = "bump" {}
        _FoamPow("FoamPow", Float) = 8
        _FoamIntensity("FoamIntensity", Range(0,1)) = 0.4
        [Space(10)]
        _WaveScale("WaveScale", Float) = 5
        _WaveRate("WaveRate", Float) = 50
        _WaveRateOffset("WaveRateOffset", Float) = 24
    }
    SubShader
    {
        Tags
        {
            "RenderType"="Transparent"
            "Queue"="Transparent"
            "RenderPipeline" = "UniversalPipeline"
            "LightMode" = "UniversalForward"
        }
        ZWrite On
        Blend One OneMinusSrcAlpha

        Pass
        {
            Name "Sea"

            HLSLPROGRAM
            
            #pragma vertex WaterVertex
            #pragma fragment WaterFragment

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            half _MaxDepth;
            half4 _WaterColor;
            half4 _Moss;
            half _SmoothnessWater;
            half _SpecularIntensity;
            half _ReflactionIntensity;
            half _FoamPow;
            half _FoamIntensity;
            SAMPLER(sampler_ScreenTextures_linear_clamp);
            TEXTURE2D(_SurfaceMap);
            SAMPLER(sampler_SurfaceMap);
            TEXTURE2D(_CameraOpaqueTexture);
            SAMPLER(sampler_CameraOpaqueTexture_linear_clamp);
            TEXTURE2D(_FoamMap);
            SAMPLER(sampler_FoamMap);

            half _WaveScale;
            half _WaveRate;
            half _WaveRateOffset = 0.1;
            half _CustomTime = 0;

            struct RiverAttributes
            {
                half4 vertex : POSITION;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct RiverVaryings
            {
                half4 clipPos : SV_POSITION;
                half3 normal : NORMAL;
                half4 uv : TEXCOORD0;
                half3 posWS : TEXCOORD1;
                half3 viewVector : TEXCOORD2;
                half4 screenPos : TEXCOORD3;
                half4 uvWave : TEXCOORD4;
                half4 uv2 : TEXCOORD5;

                UNITY_VERTEX_INPUT_INSTANCE_ID
                UNITY_VERTEX_OUTPUT_STEREO
            };

            // 2D Random
            half2 random(half2 st)
            {
                st = half2(dot(st, half2(127.1, 311.7)), dot(st, half2(269.5, 183.3)));
                return -1.0 + 2.0 * frac(sin(st) * 43758.5453123);
            }

            // 2D Noise based on Morgan McGuire @morgan3d
            // https://www.shadertoy.com/view/4dS3Wd
            half noise(half2 st)
            {
                half2 i = floor(st);
                half2 f = frac(st);

                half2 u = f * f * (3.0 - 2.0 * f);

                return lerp(lerp(dot(random(i), f),
                                 dot(random(i + half2(1.0, 0.0)), f - half2(1.0, 0.0)), u.x),
                            lerp(dot(random(i + half2(0.0, 1.0)), f - half2(0.0, 1.0)),
                                 dot(random(i + half2(1.0, 1.0)), f - half2(1.0, 1.0)), u.x), u.y);
            }

            RiverVaryings WaterVertex(RiverAttributes input)
            {
                RiverVaryings output = (RiverVaryings)0;

                output.posWS = TransformObjectToWorld(input.vertex.xyz);
                half time = _Time.y;

                // disturbance normal
                output.normal = half3(0, 1, 0);
                half uvNoise = ((noise((output.posWS.xz * 0.5) + time) + noise((output.posWS.xz * 1) + time)) * 0.25 -
                    0.5) + 1;

                // Detail UVs
                output.uv.xy = (output.posWS.xz * 0.25h * 0.5 + time.xx + uvNoise) / 100;
                output.uv.zw = (output.posWS.xz * 0.5h * 0.5 + half2(time.x, 0) + (uvNoise * 0.5)) / 100;
                output.uv2.xy = (output.posWS.xz * 1 * 0.5 + half2(0, time.x) + (uvNoise * 0.25)) / 100;
                output.uv2.zw = (output.posWS.xz * 0.5h * 0.5 + uvNoise) / 100;

                // After waves
                output.clipPos = TransformWorldToHClip(output.posWS);
                output.screenPos = ComputeScreenPos(output.clipPos);
                output.viewVector = _WorldSpaceCameraPos - output.posWS;

                return output;
            }

            half2 SampleNormalOffset(half2 uv)
            {
                return SAMPLE_TEXTURE2D(_SurfaceMap, sampler_SurfaceMap, uv).rg * 2 - half2(1, 1);
            }

            // Fragment for water
            half4 WaterFragment(RiverVaryings IN) : SV_Target
            {
                UNITY_SETUP_INSTANCE_ID(output);
                half depthMulti = 1 / _MaxDepth;
                half2 screenUV = IN.screenPos.xy / IN.screenPos.w;
                half3 viewDir = SafeNormalize(IN.viewVector);

                // 地表和水面距离深度 depth
                // depth : 海底到摄像机的距离 - 海面到摄像机的距离
                // waterDepth : 海底到海面的垂直距离
                half s_depth = LinearEyeDepth(SampleSceneDepth(screenUV.xy), _ZBufferParams).r; //直接采样NDC下的xy坐标
                half t_depth = IN.screenPos.w; //半透明物体的线性深度
                half seafloorDepth = s_depth - t_depth;
                half depth = saturate(seafloorDepth * depthMulti); // 不透明地表物体与半透明水面的距离过大，需要一个合适的方式归一化
                // return half4(depth.xxx, 1);
                half waterDepth = saturate(seafloorDepth * dot(viewDir, half3(0, 1, 0)) * depthMulti);
                // return half4(waterDepth.xxx, 1);

                // 采样法线扰动贴图，贴图为法线 xz 偏移贴图，法线为世界空间下的法线
                // 对法线贴图进行 3 次采样，分别代表大中小三种海浪，越大的海浪移动速度越快，法线偏移效果越显著
                half2 bumpLarge = SampleNormalOffset(IN.uv.xy);
                half2 bumpMediam = SampleNormalOffset(IN.uv.zw);
                half2 bumpSmall = SampleNormalOffset(IN.uv2.xy);
                half2 waveBump = bumpLarge + bumpMediam * 0.75 + bumpSmall * 0.5;
                // return half4(waveBump.x, 0, waveBump.y, 1);
                IN.normal = normalize(half3(waveBump.x, 1, waveBump.y));
                // return half4(IN.normal, 1);

                // 海边波浪 wave 进行法线扰动
                // 越在深海海波浪宽度越大，速度越快，法线扰动效果越不明显
                // return half4(waterDepth.xxx, 1);
                half waveX = _Time.y + waterDepth * (_WaveRate * (1 - waterDepth) + _WaveRateOffset);
                // 叠加一个正弦波，一个 Gerstner 波
                half waveValue = (sin(waveX + 0.5 * PI) * 0.5 + 0.5) * (1 - waterDepth);
                waveValue += (-abs(sin(waveX * 0.5)) + 1) * (1 - depth);
                waveValue /= 2;

                // half3 waveNormal = (half3(-ddx(waveValue), 0, -ddy(waveValue)));
                half3 waveNormal = (half3(-ddy(waveValue), 0, -ddx(waveValue)));
                waveNormal = mul((half3x3)UNITY_MATRIX_I_V, waveNormal).xyz;
                waveNormal.y = 0;
                waveNormal *= _WaveScale;

                IN.normal = normalize(IN.normal + waveNormal);
                // half3 wave = waveValue.xxx;

                // 反射
                // 采样天空盒反射，后边可换成平面反射
                half3 reflectVector = reflect(-viewDir, IN.normal);
                half3 reflection = SAMPLE_TEXTURECUBE(unity_SpecCube0, samplerunity_SpecCube0, reflectVector).rgb *
                    _ReflactionIntensity;
                // return half4(reflection, 1);

                // 水底折射
                // 光线在水中的行进距离越长，越被散射开，越不容易获得水底颜色
                half3 refraction = lerp(_Moss.xyz, 0, depth);
                // return half4(refraction, 1);

                // 菲涅尔系数
                half fresnel = saturate(pow(1.0 - dot(IN.normal, viewDir), 5));
                // return half4(fresnel.xxx, 1);

                // 菲涅尔项
                half3 fresnelTerm = lerp(refraction, reflection, fresnel);
                // return half4(fresnelTerm, 1);

                // 次表面散射
                // 使用次表面散射来表现浑浊的水，次表面散射的颜色是由光线照到水内部颗粒呈现的
                // 光线在水内部行进距离越长，越多光线汇集到出射点，越容易呈现水内部的颜色
                half3 sss = lerp(0, _WaterColor.xyz, depth); // 用 depth 近似光线在水中的距离
                // return half4(sss, 1);

                Light mainLight = GetMainLight();

                // 高光项 : Bling-phone
                half3 halfDir = SafeNormalize(mainLight.direction + viewDir);
                half LoH = saturate(dot(IN.normal, halfDir));
                half spec = pow(LoH, _SmoothnessWater); // 反射光强度低
                half3 specColor = spec * mainLight.color * _SpecularIntensity;
                // return half4(spec.xxx,1);

                // 白沫 Foam
                // 越靠近岸边，越处于波峰处白沫越明显
                float foamArea = pow(1.01 - depth, 80);
                foamArea += pow(waveValue * 1.01, 20);
                foamArea = saturate(foamArea);
                half3 foamMap = SAMPLE_TEXTURE2D(_FoamMap, sampler_FoamMap, IN.uv2.zw * 3).rgb;
                half foamMask = length(foamMap + 0.15);
                foamMask = pow(foamMask, 20);
                foamMask *= foamArea;
                foamMask = saturate(foamMask);
                foamMask *= Smootherstep01(1 - waterDepth);
                half3 foam = foamMask * mainLight.color * _FoamIntensity;

                return half4(fresnelTerm + sss + specColor + foam, depth);
            }
            ENDHLSL
        }
    }
    FallBack "Hidden/InternalErrorShader"
}
