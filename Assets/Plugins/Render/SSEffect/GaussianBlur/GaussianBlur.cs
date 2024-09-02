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

public abstract class SSPass<VolumeComp> : ScriptableRenderPass
    where VolumeComp : VolumeComponent, IPostProcessComponent {
    protected RTHandle buffer;
    protected Material m_Material;
    protected ProfilingSampler m_ProfilingSampler;
    protected ScriptableRenderer renderer;
    public string shaderName;
    public string name;

    protected SSPass(string name, string shaderName, RenderPassEvent renderPassEvent) {
        this.name = shaderName;
        this.shaderName = shaderName;
        m_ProfilingSampler = new ProfilingSampler(name);
        this.renderPassEvent = renderPassEvent;
    }

    public void Setup(ScriptableRenderer renderer) {
        if (m_Material == null) {
            var m_Shader = Shader.Find(shaderName);
            m_Material = CoreUtils.CreateEngineMaterial(m_Shader);
        }

        this.renderer = renderer;
    }

    public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData) {
        RenderTextureDescriptor cameraTargetDescriptor = renderingData.cameraData.cameraTargetDescriptor;
        RenderTextureDescriptor descriptor = cameraTargetDescriptor;
        descriptor.msaaSamples = 1;
        descriptor.depthBufferBits = 0;

        var m_AOPassDescriptor = descriptor;

        RenderingUtils.ReAllocateIfNeeded(ref buffer, m_AOPassDescriptor, FilterMode.Bilinear, TextureWrapMode.Clamp,
            name: $"{name}_Texture");
    }

    public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData) {
        var stack = VolumeManager.instance.stack;
        VolumeComp GaussianBlur = stack.GetComponent<VolumeComp>();
        if (!GaussianBlur.IsActive()) {
            return;
        }

        CommandBuffer cmd = CommandBufferPool.Get();

        using (new ProfilingScope(cmd, m_ProfilingSampler)) {
            SSExecute(cmd, GaussianBlur);
        }

        context.ExecuteCommandBuffer(cmd);
        CommandBufferPool.Release(cmd);
    }

    protected abstract void SSExecute(CommandBuffer cmd, VolumeComp gaussianBlur);

    public void Dispose() {
        buffer?.Release();
    }
}

public class GaussianBlurPass : SSPass<GaussianBlur> {
    public static readonly int s_SSAOParamsID = Shader.PropertyToID("_SSAOParams");

    public GaussianBlurPass() : base("GaussianBlur", "ZPlugin/GaussianBlurShader",
        RenderPassEvent.AfterRenderingSkybox) {
    }

    protected override void SSExecute(CommandBuffer cmd, GaussianBlur gaussianBlur) {
        var intensity = Mathf.Lerp(0.6f, 0.15f, gaussianBlur.intensity.value);
        m_Material.SetVector(s_SSAOParamsID, new Vector4(0, 0, intensity, 0));
        var baseMap = renderer.cameraColorTargetHandle;
        for (int i = 0; i < gaussianBlur.blitCount.value; i++) {
            Blitter.BlitCameraTexture(cmd, baseMap, buffer, m_Material, 0);
            Blitter.BlitCameraTexture(cmd, buffer, baseMap, m_Material, 1);
        }
    }
}