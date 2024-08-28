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
}

/// <summary>
/// Outline base on color gradiant
/// </summary>
class OutlinePass : ScriptableRenderPass {
    public LayerMask outlineLayer = ~0;
    [ColorUsage(false, true)] public Color outlineColor = Color.black;
    public float threshold = 1;

    // To make sure the shader will ends up in the build, we keep it's reference in the custom pass
    [SerializeField, HideInInspector] Shader outlineShader;

    Material fullscreenOutline;
    RTHandle outlineBuffer;

    private static readonly int OutlineColor = Shader.PropertyToID("_OutlineColor");
    private static readonly int OutlineBuffer = Shader.PropertyToID("_OutlineBuffer");
    private static readonly int Threshold = Shader.PropertyToID("_Threshold");

    private MaterialPropertyBlock propertyBlock;
    public ScriptableRenderer Renderer;

    public OutlinePass() {
        outlineShader = Shader.Find("Hidden/Outline");
        fullscreenOutline = CoreUtils.CreateEngineMaterial(outlineShader);

        // outlineBuffer = RTHandles.Alloc(
        //     Vector2.one, TextureXR.slices, dimension: TextureXR.dimension,
        //     colorFormat: GraphicsFormat.B10G11R11_UFloatPack32, // We don't need alpha for this effect
        //     useDynamicScale: true, name: "Outline Buffer"
        // );

        propertyBlock = new MaterialPropertyBlock();
        renderPassEvent = RenderPassEvent.AfterRenderingSkybox;
    }

    public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData) {
        RenderTextureDescriptor cameraTargetDescriptor = renderingData.cameraData.cameraTargetDescriptor;
        RenderTextureDescriptor descriptor = cameraTargetDescriptor;
        descriptor.msaaSamples = 1;
        descriptor.depthBufferBits = 0;

        var m_AOPassDescriptor = descriptor;

        RenderingUtils.ReAllocateIfNeeded(ref outlineBuffer, m_AOPassDescriptor, FilterMode.Bilinear, TextureWrapMode.Clamp, name: "_SSAO_OcclusionTexture0");
    }

    private List<ShaderTagId> m_ShaderTagIdList = new List<ShaderTagId>() {
        new ShaderTagId("SRPDefaultUnlit"),
        new ShaderTagId("UniversalForward"),
        new ShaderTagId("UniversalForwardOnly")
    };

    public RenderQueueType renderQueueType = RenderQueueType.Opaque;
    private FilteringSettings m_FilteringSettings;

    public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData) {
        var stack = VolumeManager.instance.stack;
        var outline = stack.GetComponent<Outline>();
        if (!outline.IsActive()) {
            return;
        }

        CommandBuffer cmd = CommandBufferPool.Get();
        CustomPassContext ctx = new CustomPassContext() {
            cmd = cmd,
            propertyBlock = propertyBlock,
            cameraColorBuffer = Renderer.cameraColorTargetHandle,
        };


        // Render meshes we want to outline in the outline buffer
        CoreUtils.SetRenderTarget(cmd, outlineBuffer, ClearFlag.Color);

        SortingCriteria sortingCriteria = (renderQueueType == RenderQueueType.Transparent)
            ? SortingCriteria.CommonTransparent
            : renderingData.cameraData.defaultOpaqueSortFlags;
        DrawingSettings drawingSettings = CreateDrawingSettings(m_ShaderTagIdList, ref renderingData, sortingCriteria);

        // RenderQueueRange renderQueueRange = (renderQueueType == RenderQueueType.Transparent)
        //     ? RenderQueueRange.transparent
        //     : RenderQueueRange.opaque;
        // m_FilteringSettings = new FilteringSettings(renderQueueRange, outlineLayer);
        m_FilteringSettings = new FilteringSettings(RenderQueueRange.all);

        // var desc = new RendererListDesc(
        //     m_ShaderTagIdList.ToArray(),
        //     renderingData.cullResults,
        //     renderingData.cameraData.camera
        // );
        // var renderList = context.CreateRendererList(desc);
        // cmd.DrawRendererList(renderList);

        context.ExecuteCommandBuffer(cmd);
        cmd.Clear();
        context.DrawRenderers(renderingData.cullResults, ref drawingSettings, ref m_FilteringSettings);

        // Setup outline effect properties
        ctx.propertyBlock.SetColor(OutlineColor, outline.outLineColor.value);
        ctx.propertyBlock.SetTexture(OutlineBuffer, outlineBuffer);
        ctx.propertyBlock.SetFloat(Threshold, outline.threshold.value);

        // Render the outline as a fullscreen alpha-blended pass on top of the camera color
        CoreUtils.SetRenderTarget(cmd, ctx.cameraColorBuffer, ClearFlag.None);
        CoreUtils.DrawFullScreen(cmd, fullscreenOutline, ctx.propertyBlock, shaderPassId: 0);

        context.ExecuteCommandBuffer(cmd);
        CommandBufferPool.Release(cmd);
    }

    public void Cleanup() {
        CoreUtils.Destroy(fullscreenOutline);
        outlineBuffer.Release();
    }

    public void Setup(ScriptableRenderer renderer) {
        Renderer = renderer;
    }
}