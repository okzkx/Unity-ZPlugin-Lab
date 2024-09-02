using System;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;


[Serializable, VolumeComponentMenuForRenderPipeline("ZPlugin/Grab", typeof(UniversalRenderPipeline))]
public sealed class Grab : VolumeComponent, IPostProcessComponent {

    public BoolParameter open = new BoolParameter(false);

    public bool IsActive() => open.value;

    public bool IsTileCompatible() => false;
}

public class GrabPass : SSPass<Grab> {
    int _GrabPassTexture = Shader.PropertyToID("_GrabPassTexture");
    public GrabPass() : base("Grab", null, RenderPassEvent.AfterRenderingTransparents) {
    }

    protected override void SSExecute(ref CustomPassContext ctx, Grab gaussianBlur, ref RenderingData renderingData) {
        Shader.SetGlobalTexture(_GrabPassTexture, buffer);
        Blitter.BlitCameraTexture(ctx. cmd, renderer.cameraColorTargetHandle, buffer);
    }

    public new void SetUp(ScriptableRenderer scriptableRenderer) {
        base.Setup(scriptableRenderer);
    }

    public new void Release() {
        base.Release();
    }
}

public class PostEffectPass : ScriptableRenderPass {
    ShaderTagId PostEffect = new ShaderTagId("PostEffect");

    public PostEffectPass() {
        renderPassEvent = RenderPassEvent.BeforeRenderingPostProcessing;
    }

    public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData) {
        SortingCriteria sortingCriteria = SortingCriteria.CommonTransparent;
        DrawingSettings drawingSettings = CreateDrawingSettings(PostEffect, ref renderingData, sortingCriteria);

        // RenderQueueRange renderQueueRange = (renderQueueType == RenderQueueType.Transparent)
        //     ? RenderQueueRange.transparent
        //     : RenderQueueRange.opaque;
        // m_FilteringSettings = new FilteringSettings(renderQueueRange, outlineLayer);
        var m_FilteringSettings = new FilteringSettings(RenderQueueRange.all);

        context.DrawRenderers(renderingData.cullResults, ref drawingSettings, ref m_FilteringSettings);
    }
}