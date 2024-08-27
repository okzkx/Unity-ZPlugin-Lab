using UnityEngine;
using UnityEngine.Rendering.HighDefinition;
using UnityEngine.Rendering;

public class OverrideCamera : CustomPass {
    public float fov = 45;
    public LayerMask overrideMask;
    Camera overrideCamera;
    const string kCameraTag = "OverrideCamera";
    Material depthClearMaterial;
    RTHandle depthBuffer;
    public Vector3 position;
    public Quaternion rotation;

    protected override bool executeInSceneView => false;

    protected override void AggregateCullingParameters(ref ScriptableCullingParameters cullingParameters, HDCamera hdCamera) {
        cullingParameters.cullingMask |= (uint) overrideMask.value;
    }

    protected override void Setup(ScriptableRenderContext renderContext, CommandBuffer cmd) {
        depthClearMaterial = new Material(Shader.Find("Hidden/Renderers/OverrideDepthClear"));
        var dethBuffer = new RenderTargetIdentifier(BuiltinRenderTextureType.Depth);
        depthBuffer = RTHandles.Alloc(dethBuffer);
    }

    protected override void Execute(CustomPassContext ctx) {
        if (overrideCamera == null) {
            CreateOverrideCamera();
        }

        overrideCamera.transform.SetPositionAndRotation(position, rotation);
        overrideCamera.fieldOfView = fov;

        // Use overrideCamera's cullingParameter to override CurrentCam's Culling result
        if (overrideCamera.TryGetCullingParameters(out var cullingParameters)) {
            cullingParameters.cullingOptions = CullingOptions.None;
            ctx.cullingResults = ctx.renderContext.Cull(ref cullingParameters);
        }

        // Override depth to 0 (avoid artifacts with screen-space effects)
        ctx.cmd.SetRenderTarget(depthBuffer);
        CustomPassUtils.RenderFromCamera(ctx, overrideCamera, null, null,
            ClearFlag.None, overrideMask, overrideMaterial: depthClearMaterial, overrideMaterialIndex: 0);
        // Render the object color
        CustomPassUtils.RenderFromCamera(ctx, overrideCamera, ctx.cameraColorBuffer, ctx.cameraDepthBuffer,
            ClearFlag.None, overrideMask);
    }

    private void CreateOverrideCamera() {
        // Hidden override camera:
        var cam = GameObject.Find(kCameraTag);
        if (cam == null) {
            // cam = new GameObject(kCameraTag); // For Debugs
            cam = new GameObject(kCameraTag) {hideFlags = HideFlags.HideAndDontSave};
        }

        if (!cam.TryGetComponent<Camera>(out var camera) || camera == null) {
            camera = cam.AddComponent<Camera>();
            camera.enabled = false;
            camera.cullingMask = overrideMask;
        }

        overrideCamera = camera;
    }

    protected override void Cleanup() {
        depthBuffer.Release();
        CoreUtils.Destroy(depthClearMaterial);
        CoreUtils.Destroy(overrideCamera.gameObject);
    }
}