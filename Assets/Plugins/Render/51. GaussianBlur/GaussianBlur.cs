// using UnityEngine;
// using UnityEngine.Rendering.HighDefinition;
// using UnityEngine.Rendering;
// using UnityEngine.Experimental.Rendering;
// using UnityEngine.Rendering.Universal;
//
// public class GaussianBlur : ScriptableRenderPass {
//     
//     // Specifies the radius for the blur in pixels. This example uses an 8 pixel radius.
//     public float blurFactor = 8.0f;
//
//     // Specifies the precision of the blur. This also affects the resource intensity of the blue. A value of 9 is good for real-time applications.
//     const int sampleCount = 9;
//
//     RTHandle halfResTarget;
//
//     public override void Setup(ScriptableRenderContext context, ref RenderingData renderingData) {
//         halfResTarget = RTHandles.Alloc(
//             // Note the * 0.5f here. This allocates a half-resolution target, which saves a lot of memory.
//             Vector2.one * 0.5f, TextureXR.slices, dimension: TextureXR.dimension,
//             // Since alpha is unnecessary for Gaussian blur, this effect uses an HDR texture format with no alpha channel.
//             colorFormat: GraphicsFormat.B10G11R11_UFloatPack32,
//             // When creating textures, be sure to name them as it is useful for debugging.
//             useDynamicScale: true, name: "Half Res Custom Pass"
//         );
//         
//     }
//     
//     
//     
//     public override void Execute(ScriptableRenderContext ctx, ref RenderingData renderingData) {
//         float radius = blurFactor;
//     
//         // In cases where you have multiple cameras with different resolutions, this makes the blur coherent across these cameras.
//         radius *= ctx.cameraColorBuffer.rtHandleProperties.rtHandleScale.x;
//     
//         // The actual Gaussian blur call. It specifies the current camera's color buffer as the source and destination.
//         // This uses the half-resolution target as a temporary render target between the blur passes.
//         // Note that the Gaussian blur function clears the content of the half-resolution buffer when it finishes.
//         CustomPassUtils.GaussianBlur(
//             ctx, ctx.cameraColorBuffer, ctx.cameraColorBuffer, halfResTarget,
//             sampleCount, radius, downSample: true
//         );
//     // }
//
//     // Releases the GPU memory allocated for the half-resolution target. This is important otherwise the memory will leak.
//     protected override void Cleanup() => halfResTarget.Release();
//
//     public GaussianBlur(ScriptableRendererData data) : base(data) {
//     }
// }

using System;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

[Serializable, VolumeComponentMenuForRenderPipeline("Post-processing/GaussianBlur", typeof(UniversalRenderPipeline))]
public sealed partial class GaussianBlur : VolumeComponent, IPostProcessComponent {
    /// <summary>
    /// Controls the strength of the bloom filter.
    /// </summary>
    [Tooltip("Strength of the bloom filter.")]
    public MinFloatParameter intensity = new MinFloatParameter(0f, 0f);
    
    public bool IsActive() => intensity.value > 0f;

    /// <inheritdoc/>
    public bool IsTileCompatible() => false;
}

public class GaussianBlurPass : ScriptableRenderPass {
    private GaussianBlur GaussianBlur;

    public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData) {
        var stack = VolumeManager.instance.stack;
        GaussianBlur = stack.GetComponent<GaussianBlur>();
        
    }
}

public class ZRenderFeature : ScriptableRendererFeature {
    private GaussianBlurPass GaussianBlurPass;
    
    public override void Create() {
        GaussianBlurPass = new GaussianBlurPass();
    }

    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData) {
        renderer.EnqueuePass(GaussianBlurPass);
    }
}
