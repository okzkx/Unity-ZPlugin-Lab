﻿using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public abstract class SSPass<VolumeComp> : ScriptableRenderPass
    where VolumeComp : VolumeComponent, IPostProcessComponent {
    protected RTHandle buffer;
    private Material m_Material;
    protected ProfilingSampler m_ProfilingSampler;
    protected ScriptableRenderer renderer;
    public string shaderName;
    public string name;
    private MaterialPropertyBlock propertyBlock = new MaterialPropertyBlock();

    public Material Material {
        get {
            if (m_Material == null) {
                var m_Shader = Shader.Find(shaderName);
                m_Material = CoreUtils.CreateEngineMaterial(m_Shader);
            }

            return m_Material;
        }
    }

    protected SSPass(string name, string shaderName, RenderPassEvent renderPassEvent) {
        this.name = shaderName;
        this.shaderName = shaderName;
        m_ProfilingSampler = new ProfilingSampler(name);
        this.renderPassEvent = renderPassEvent;
    }

    public void Setup(ScriptableRenderer renderer) {
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
        VolumeComp volumeComp = stack.GetComponent<VolumeComp>();
        if (!volumeComp.IsActive()) {
            return;
        }

        CommandBuffer cmd = CommandBufferPool.Get();

        CustomPassContext ctx = new CustomPassContext() {
            cmd = cmd,
            context = context,
            propertyBlock = propertyBlock,
            cameraColorBuffer = renderer.cameraColorTargetHandle,
        };

        using (new ProfilingScope(cmd, m_ProfilingSampler)) {
            SSExecute(ref ctx, volumeComp, ref renderingData);
        }

        context.ExecuteCommandBuffer(cmd);
        CommandBufferPool.Release(cmd);
    }

    protected abstract void SSExecute(ref CustomPassContext ctx, VolumeComp gaussianBlur,
        ref RenderingData renderingData);

    public void Release() {
        buffer?.Release();
    }
}