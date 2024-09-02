using System;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

[Serializable, VolumeComponentMenuForRenderPipeline("ZPlugin/GaussianBlur", typeof(UniversalRenderPipeline))]
public sealed class GaussianBlur : VolumeComponent, IPostProcessComponent {
    public ClampedFloatParameter intensity = new ClampedFloatParameter(0.0f, 0f, 1f);

    public ClampedIntParameter blitCount = new ClampedIntParameter(3, 0, 8);

    public bool IsActive() => intensity.value > 0f;

    public bool IsTileCompatible() => false;
}
public class GaussianBlurPass : SSPass<GaussianBlur> {
    public static readonly int s_SSAOParamsID = Shader.PropertyToID("_SSAOParams");

    public GaussianBlurPass() : base("GaussianBlur", "ZPlugin/GaussianBlurShader",
        RenderPassEvent.AfterRenderingSkybox) {
    }

    protected override void SSExecute(ref CustomPassContext ctx, GaussianBlur gaussianBlur, 
        ref RenderingData renderingData) {
        var intensity = Mathf.Lerp(0.6f, 0.15f, gaussianBlur.intensity.value);
        Material.SetVector(s_SSAOParamsID, new Vector4(0, 0, intensity, 0));
        var baseMap = renderer.cameraColorTargetHandle;
        for (int i = 0; i < gaussianBlur.blitCount.value; i++) {
            Blitter.BlitCameraTexture(ctx.cmd, baseMap, buffer, Material, 0);
            Blitter.BlitCameraTexture(ctx.cmd, buffer, baseMap, Material, 1);
        }
    }
}