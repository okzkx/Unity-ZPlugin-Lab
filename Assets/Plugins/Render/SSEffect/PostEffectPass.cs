using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class PostEffectPass : ScriptableRenderPass {
    const string name = "PostEffect";
    ShaderTagId PostEffect = new ShaderTagId(name);
    private ProfilingSampler Sampler = new ProfilingSampler(name);

    public PostEffectPass() {
        renderPassEvent = RenderPassEvent.BeforeRenderingPostProcessing;
    }

    public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData) {
        var cmd = CommandBufferPool.Get();
        Sampler.Begin(cmd);
        context.ExecuteCommandBuffer(cmd);
        cmd.Clear();

        SortingCriteria sortingCriteria = SortingCriteria.CommonTransparent;
        DrawingSettings drawingSettings = CreateDrawingSettings(
            PostEffect, ref renderingData, sortingCriteria);
        var filteringSettings = new FilteringSettings(RenderQueueRange.all);
        context.DrawRenderers(renderingData.cullResults, ref drawingSettings, ref filteringSettings);

        Sampler.End(cmd);
        context.ExecuteCommandBuffer(cmd);
        CommandBufferPool.Release(cmd);
    }
}