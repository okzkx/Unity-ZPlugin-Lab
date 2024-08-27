#ifndef CUSTOM_LIGHT_HLSL
#define CUSTOM_LIGHT_HLSL

#include "Packages/com.unity.render-pipelines.high-definition/Runtime/ShaderLibrary/ShaderVariables.hlsl"
#include "Packages/com.unity.render-pipelines.high-definition/Runtime/Lighting/LightDefinition.cs.hlsl"


struct SimpleLight
{
    float3 color;
    float3 directionWS;
};

SimpleLight GetSimpleLight()
{
    DirectionalLightData directionalLightData = _DirectionalLightDatas[0];
    SimpleLight light;
    light.color = saturate(directionalLightData.color);
    light.directionWS = -directionalLightData.forward;
    return light;
}

#endif