using System;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

[Serializable, VolumeComponentMenuForRenderPipeline("Post-processing/GaussianBlur", typeof(UniversalRenderPipeline))]
public sealed class GaussianBlur : VolumeComponent, IPostProcessComponent {
    public ClampedFloatParameter intensity = new ClampedFloatParameter(0.5f, 0f, 1f);

    public ClampedIntParameter blitCount = new ClampedIntParameter(3, 0, 8);

    public bool IsActive() => intensity.value > 0f;

    public bool IsTileCompatible() => false;
}

enum ZPluginProfileId {
    GaussianBlur
}

public class GaussianBlurPass : ScriptableRenderPass {
    private GaussianBlur GaussianBlur;
    private RTHandle[] m_SSAOTextures = new RTHandle[4];
    private Material m_Material;
    private ProfilingSampler m_ProfilingSampler = ProfilingSampler.Get(ZPluginProfileId.GaussianBlur);
    private ScriptableRenderer renderer;

    public GaussianBlurPass() {
        renderPassEvent = RenderPassEvent.AfterRenderingSkybox;
    }

    public void Setup(Shader m_Shader, ScriptableRenderer renderer) {
        if (m_Material == null && m_Shader != null)
            m_Material = CoreUtils.CreateEngineMaterial(m_Shader);
        this.renderer = renderer;
    }

    private static readonly int s_SSAOParamsID = Shader.PropertyToID("_SSAOParams");

    public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData) {
        RenderTextureDescriptor cameraTargetDescriptor = renderingData.cameraData.cameraTargetDescriptor;
        RenderTextureDescriptor descriptor = cameraTargetDescriptor;
        descriptor.msaaSamples = 1;
        descriptor.depthBufferBits = 0;

        var m_AOPassDescriptor = descriptor;

        RenderingUtils.ReAllocateIfNeeded(ref m_SSAOTextures[0], m_AOPassDescriptor, FilterMode.Bilinear, TextureWrapMode.Clamp, name: "_SSAO_OcclusionTexture0");
        RenderingUtils.ReAllocateIfNeeded(ref m_SSAOTextures[1], m_AOPassDescriptor, FilterMode.Bilinear, TextureWrapMode.Clamp, name: "_SSAO_OcclusionTexture1");

        if (m_Material == null) {
            return;
        }

        var stack = VolumeManager.instance.stack;
        GaussianBlur = stack.GetComponent<GaussianBlur>();
    }

    public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData) {
        if (!GaussianBlur.IsActive()) {
            return;
        }

        var intensity = Mathf.Lerp(0.6f, 0.15f, GaussianBlur.intensity.value);
        // m_Material.SetVector(s_SSAOParamsID, new Vector4(
        //     1, // m_CurrentSettings.Intensity,    // Intensity
        //     0.035f, // m_CurrentSettings.Radius * 1.5f,// Radius
        //     intensity, // 1.0f / downsampleDivider,       // Downsampling
        //     0f // m_CurrentSettings.Falloff       // Falloff
        // ));
        m_Material.SetVector(s_SSAOParamsID, new Vector4(0,0, intensity, 0));

        CommandBuffer cmd = CommandBufferPool.Get();
        using (new ProfilingScope(cmd, m_ProfilingSampler)) {
            var baseMap = renderer.cameraColorTargetHandle;
            var target = m_SSAOTextures[0];
            for (int i = 0; i < GaussianBlur.blitCount.value; i++) {
                Blitter.BlitCameraTexture(cmd, baseMap, target, m_Material, 1);
                Blitter.BlitCameraTexture(cmd, target, baseMap, m_Material, 2);
            }
        }

        context.ExecuteCommandBuffer(cmd);
        CommandBufferPool.Release(cmd);
    }

    public void Dispose() {
        m_SSAOTextures[0]?.Release();
        m_SSAOTextures[1]?.Release();
    }
}