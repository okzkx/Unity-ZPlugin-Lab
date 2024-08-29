Shader "C1/Distortion1"
{
    Properties
    {
        _NoiseTex ("Noise Texture (RG)", 2D) = "white" {}
        _MainTex ("Alpha (A)", 2D) = "white" {}
        _HeatTime ("Heat Time", range (0,1.5)) = 1
        _HeatForce ("Heat Force", range (0,0.1)) = 0.1
    }

    SubShader
    {
        Tags
        {
            "Queue"="Transparent+1"
            "RenderType"="Transparent"
            "RenderPipeline" = "UniversalPipeline"
            "LightMode" = "PostEffect"
        }
        Blend SrcAlpha OneMinusSrcAlpha
        AlphaTest Greater .01
        Cull Off
        Lighting Off
        ZWrite Off

        Pass
        {
            HLSLPROGRAM
            #pragma vertex Vertex
            #pragma fragment Fragment
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

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
				half4 color : TEXCOORD2l;
            };

            float _HeatForce;
            float _HeatTime;
            float4 _MainTex_ST;
            float4 _NoiseTex_ST;
            sampler2D _NoiseTex;
            sampler2D _MainTex;

            TEXTURE2D(_GrabPassTexture);
            SAMPLER(sampler_GrabPassTexture_linear_clamp);

            Varyings Vertex(Attribute v)
            {
                Varyings output = (Varyings)0;
                output.positionCS = TransformObjectToHClip(v.positionOS.xyz);
                output.uv = v.texcoord;
                output.positionSS = ComputeScreenPos(output.positionCS);
				output.color = v.color;
                return output;
            }

            half4 Fragment(Varyings input): SV_Target
            {
                half4 offsetColor1 = tex2D(_NoiseTex, input.uv + _Time.xz * _HeatTime);
                half4 offsetColor2 = tex2D(_NoiseTex, input.uv - _Time.yx * _HeatTime);
                half2 uvOffset = half2(((offsetColor1.r + offsetColor2.r) - 1),
                                       (offsetColor1.g + offsetColor2.g) - 1) * _HeatForce * input.color.a;
                half2 screenUV = input.positionSS.xy / input.positionSS.w;
                half2 samplerUV = screenUV + uvOffset;
                half4 color = SAMPLE_TEXTURE2D(_GrabPassTexture, sampler_GrabPassTexture_linear_clamp, samplerUV);
                color.a = tex2D(_MainTex, input.uv).a;
                return color;
            }

            ENDHLSL
        }
    }
}
