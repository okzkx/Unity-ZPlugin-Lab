using UnityEngine;
using UnityEngine.Rendering.HighDefinition;
using UnityEngine.Rendering;
using UnityEngine.Experimental.Rendering;

class TIPS : CustomPass {
    public Material tipsMeshMaterial;
    public Material fullscreenMaterial;
    
    public Mesh mesh = null;
    public float size = 5;
    public float rotationSpeed = 5;
    public float edgeDetectThreshold = 1;
    public int edgeRadius = 2;
    public Color glowColor = Color.white;

    public const float kMaxDistance = 1000;


    RTHandle tipsBuffer; // additional render target for compositing the custom and camera color buffers

    int compositingPass;
    int blurPass;

    protected override void Setup(ScriptableRenderContext renderContext, CommandBuffer cmd) {
        if (fullscreenMaterial == null)
            return;
        // tipsMeshMaterial = Resources.Load<Material>("Shader Graphs_TIPS_Effect");
        // fullscreenMaterial = CoreUtils.CreateEngineMaterial("FullScreen/TIPS");
        tipsBuffer = RTHandles.Alloc(Vector2.one, TextureXR.slices, dimension: TextureXR.dimension, colorFormat: GraphicsFormat.R16G16B16A16_SFloat, useDynamicScale: true, name: "TIPS Buffer");

        compositingPass = fullscreenMaterial.FindPass("Compositing");
        blurPass = fullscreenMaterial.FindPass("Blur");
        targetColorBuffer = TargetBuffer.Custom;
        targetDepthBuffer = TargetBuffer.Custom;
        clearFlags = ClearFlag.All;
    }

    protected override void Execute(CustomPassContext ctx) {
        if (fullscreenMaterial == null)
            return;

        if (mesh != null && tipsMeshMaterial != null) {
            Transform cameraTransform = ctx.hdCamera.camera.transform;
            Matrix4x4 trs = Matrix4x4.TRS(cameraTransform.position, Quaternion.Euler(0f, Time.realtimeSinceStartup * rotationSpeed, Time.realtimeSinceStartup * rotationSpeed * 0.5f), Vector3.one * size);
            tipsMeshMaterial.SetFloat("_Intensity", (0.2f / size) * kMaxDistance);
            ctx.cmd.DrawMesh(mesh, trs, tipsMeshMaterial, 0, tipsMeshMaterial.FindPass("ForwardOnly"));
        }

        ctx.propertyBlock.SetFloat("_EdgeDetectThreshold", edgeDetectThreshold);
        ctx.propertyBlock.SetColor("_GlowColor", glowColor);
        ctx.propertyBlock.SetFloat("_EdgeRadius", (float) edgeRadius);
        ctx.propertyBlock.SetFloat("_BypassMeshDepth", (mesh != null) ? 0 : size);
        CoreUtils.SetRenderTarget(ctx.cmd, tipsBuffer, ClearFlag.Color);
        CoreUtils.DrawFullScreen(ctx.cmd, fullscreenMaterial, shaderPassId: compositingPass, properties: ctx.propertyBlock);

        ctx.propertyBlock.SetTexture("_TIPSBuffer", tipsBuffer);
        CoreUtils.SetRenderTarget(ctx.cmd, ctx.cameraColorBuffer);
        CoreUtils.DrawFullScreen(ctx.cmd, fullscreenMaterial, shaderPassId: blurPass, properties: ctx.propertyBlock);
    }

    protected override void Cleanup() {
        CoreUtils.Destroy(fullscreenMaterial);
        tipsBuffer.Release();
    }
}