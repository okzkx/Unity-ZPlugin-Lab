using System.Collections.Generic;
using UnityEngine.Rendering.Universal;

public class ZRenderFeature : ScriptableRendererFeature {
    private List<ScriptableRenderPass> passes;
    private List<SSPass> sspPassList;

    public override void Create() {
        passes = new List<ScriptableRenderPass>() {
            new PostEffectPass()
        };
        sspPassList = new List<SSPass>() {
            new GaussianBlurPass(),
            new OutlinePass(),
            new GrabPass(),
        };
    }

    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData) {
        sspPassList.ForEach(s=>s.Setup(renderer));
        passes.ForEach(renderer.EnqueuePass);
        sspPassList.ForEach(renderer.EnqueuePass);
    }

    private void OnDisable() {
        sspPassList.ForEach(s=>s.Release());
    }
}