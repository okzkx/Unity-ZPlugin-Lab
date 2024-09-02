using System;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Experimental.Rendering.Universal;
using UnityEngine.Rendering.Universal;

[Serializable, VolumeComponentMenuForRenderPipeline("ZPlugin/Outline", typeof(UniversalRenderPipeline))]
public sealed class Outline : VolumeComponent, IPostProcessComponent {
    public ClampedFloatParameter threshold = new ClampedFloatParameter(0.0f, 0f, 5f);
    public ColorParameter outLineColor = new ColorParameter(Color.green);

    public bool IsActive() => threshold.value > 0f;

    public bool IsTileCompatible() => false;
}

public struct CustomPassContext {
    public MaterialPropertyBlock propertyBlock;
    public CommandBuffer cmd;
    public RTHandle cameraColorBuffer;
    public ScriptableRenderContext context;
}

public class OutlinePass : SSPass<Outline> {

    private static readonly int OutlineColor = Shader.PropertyToID("_OutlineColor");
    private static readonly int OutlineBuffer = Shader.PropertyToID("_OutlineBuffer");
    private static readonly int Threshold = Shader.PropertyToID("_Threshold");
    
    RenderersRender rr = new RenderersRender();
    
    public OutlinePass() : base("Outline", "Hidden/Outline", RenderPassEvent.AfterRenderingSkybox) {
    }

    protected override void SSExecute(ref CustomPassContext ctx, Outline volumeComp, 
        ref RenderingData renderingData) {

        CoreUtils.SetRenderTarget(ctx.cmd, buffer, ClearFlag.Color);
        ctx.context.ExecuteCommandBuffer(ctx.cmd);
        ctx.cmd.Clear();

        rr.Draw(ref ctx, ref renderingData);

        // Setup outline effect properties
        ctx.propertyBlock.SetColor(OutlineColor, volumeComp.outLineColor.value);
        ctx.propertyBlock.SetTexture(OutlineBuffer, buffer);
        ctx.propertyBlock.SetFloat(Threshold, volumeComp.threshold.value);

        // Render the outline as a fullscreen alpha-blended pass on top of the camera color
        CoreUtils.SetRenderTarget(ctx.cmd, ctx.cameraColorBuffer, ClearFlag.None);
        CoreUtils.DrawFullScreen(ctx.cmd, Material, ctx.propertyBlock, shaderPassId: 0);

    }
}

internal class RenderersRender {

    public RenderQueueType renderQueueType = RenderQueueType.Opaque;
    private FilteringSettings m_FilteringSettings;

    private List<ShaderTagId> m_ShaderTagIdList = new List<ShaderTagId>() {
        new ShaderTagId("SRPDefaultUnlit"),
        new ShaderTagId("UniversalForward"),
        new ShaderTagId("UniversalForwardOnly")
    };

    public void Draw(ref CustomPassContext ctx, ref RenderingData renderingData) {
        
        SortingCriteria sortingCriteria = (renderQueueType == RenderQueueType.Transparent)
            ? SortingCriteria.CommonTransparent
            : renderingData.cameraData.defaultOpaqueSortFlags;
        DrawingSettings drawingSettings = RenderingUtils.CreateDrawingSettings(m_ShaderTagIdList, ref renderingData, sortingCriteria);

        // RenderQueueRange renderQueueRange = (renderQueueType == RenderQueueType.Transparent)
        //     ? RenderQueueRange.transparent
        //     : RenderQueueRange.opaque;
        // m_FilteringSettings = new FilteringSettings(renderQueueRange, outlineLayer);
        m_FilteringSettings = new FilteringSettings(RenderQueueRange.all);
        ctx.context.DrawRenderers(renderingData.cullResults, ref drawingSettings, ref m_FilteringSettings);
    }
}