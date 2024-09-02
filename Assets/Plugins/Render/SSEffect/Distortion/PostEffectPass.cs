using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

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