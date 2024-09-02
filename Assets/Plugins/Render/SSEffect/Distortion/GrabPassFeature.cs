using System;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;


[Serializable, VolumeComponentMenuForRenderPipeline("ZPlugin/Grab", typeof(UniversalRenderPipeline))]
public sealed class Grab : VolumeComponent, IPostProcessComponent {
    // public ClampedFloatParameter intensity = new ClampedFloatParameter(0.0f, 0f, 1f);
    //
    // public ClampedIntParameter blitCount = new ClampedIntParameter(3, 0, 8);
    
    public BoolParameter open = new BoolParameter(false);

    public bool IsActive() => open.value;

    public bool IsTileCompatible() => false;
}

public class GrabPass : ScriptableRenderPass {
    static readonly string k_RenderTag = "GrabPass"; //可在framedebug中看渲染
    ScriptableRenderer renderer;

    RTHandle tempColorTarget;

    // string m_GrabPassName = ""; //shader中的grabpass名字
    int _GrabPassTexture = Shader.PropertyToID("_GrabPassTexture");

    public GrabPass() {
        renderPassEvent = RenderPassEvent.AfterRenderingTransparents;
        // tempColorTarget = RTHandles.Alloc(_GrabPassTexture, "_GrabPassTexture");
        //
        // var descriptor = renderer.cameraColorTargetHandle.rt.descriptor;
        // RenderingUtils.ReAllocateIfNeeded(ref tempColorTarget, descriptor, 
        //     FilterMode.Bilinear, TextureWrapMode.Clamp, name: "_SSAO_OcclusionTexture0");

        // tempColorTarget.Init(m_GrabPassName);
    }


    public void SetUp(ScriptableRenderer renderer) {
        this.renderer = renderer;
    }

    public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData) {
        RenderTextureDescriptor cameraTargetDescriptor = renderingData.cameraData.cameraTargetDescriptor;
        RenderTextureDescriptor descriptor = cameraTargetDescriptor;
        descriptor.msaaSamples = 1;
        descriptor.depthBufferBits = 0;

        var m_AOPassDescriptor = descriptor;

        RenderingUtils.ReAllocateIfNeeded(ref tempColorTarget, m_AOPassDescriptor, FilterMode.Bilinear, TextureWrapMode.Clamp, name: "_SSAO_OcclusionTexture0");
        Shader.SetGlobalTexture(_GrabPassTexture, tempColorTarget);
    }

    public override void OnCameraCleanup(CommandBuffer cmd) {
        // cmd.ReleaseTemporaryRT(_GrabPassTexture);
    }

    public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData) {
        // return;
        var stack = VolumeManager.instance.stack;
        Grab Grab = stack.GetComponent<Grab>();
        if (!Grab.IsActive()) {
            return;
        }

        Debug.Log("VAR");
        
        var cmd = CommandBufferPool.Get(k_RenderTag);

        // cmd.GetTemporaryRT(tempColorTarget.nameID, Screen.width, Screen.height); //获取临时rt
        // cmd.SetGlobalTexture(m_GrabPassName, tempColorTarget.Identifier()); //设置给shader中
        
        
        
        // cmd.GetTemporaryRT(_GrabPassTexture, renderingData.cameraData.cameraTargetDescriptor);

        // Blit(cmd, renderer.cameraColorTargetHandle, tempColorTarget);
        Blitter.BlitCameraTexture(cmd, renderer.cameraColorTargetHandle, tempColorTarget);
        // Blitter.BlitCameraTexture(cmd, renderer.cameraColorTargetHandle, tempColorTarget);
        
        context.ExecuteCommandBuffer(cmd);
        CommandBufferPool.Release(cmd);
    }

    public void Cleanup() {
        tempColorTarget.Release();
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