using UnityEngine;
using UnityEngine.Rendering.HighDefinition;
using UnityEngine.Rendering;

class CameraCapture : CustomPass {
    public Camera bakingCamera;

    public RenderTexture depthTexture = null;
    public RenderTexture normalTexture = null;
    public RenderTexture tangentTexture = null;

    protected override bool executeInSceneView => false;

    protected override void Setup(ScriptableRenderContext renderContext, CommandBuffer cmd) {
        if (bakingCamera == null) {
            bakingCamera = Camera.main;
        }
    }

    protected override void Execute(CustomPassContext ctx) {
        // We need to be careful about the aspect ratio of render textures when doing the culling, otherwise it could result in objects poping:
        {
            float aspect = bakingCamera.aspect;
            if (depthTexture != null) {
                aspect = Mathf.Max(aspect, depthTexture.width / (float) depthTexture.height);
            }

            if (normalTexture != null) {
                aspect = Mathf.Max(aspect, normalTexture.width / (float) normalTexture.height);
            }

            if (tangentTexture != null) {
                aspect = Mathf.Max(aspect, tangentTexture.width / (float) tangentTexture.height);
            }

            bakingCamera.aspect = aspect;
        }

        bakingCamera.TryGetCullingParameters(out var cullingParams);
        cullingParams.cullingOptions = CullingOptions.None;

        // Assign the custom culling result to the context
        // so it'll be used for the following operations
        ctx.cullingResults = ctx.renderContext.Cull(ref cullingParams);
        var overrideDepthTest = new RenderStateBlock(RenderStateMask.Depth) {depthState = new DepthState(true, CompareFunction.LessEqual)};

        // Depth
        if (depthTexture != null) {
            CustomPassUtils.RenderDepthFromCamera(ctx, bakingCamera, depthTexture, ClearFlag.Depth, bakingCamera.cullingMask, overrideRenderState: overrideDepthTest);
        }

        // Normal
        if (normalTexture != null) {
            CustomPassUtils.RenderNormalFromCamera(ctx, bakingCamera, normalTexture, ClearFlag.All, bakingCamera.cullingMask, overrideRenderState: overrideDepthTest);
        }

        // Tangent
        if (tangentTexture != null) {
            CustomPassUtils.RenderTangentFromCamera(ctx, bakingCamera, tangentTexture, ClearFlag.All, bakingCamera.cullingMask, overrideRenderState: overrideDepthTest);
        }
    }
}