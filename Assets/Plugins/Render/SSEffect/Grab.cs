using System;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;


[Serializable, VolumeComponentMenuForRenderPipeline("ZPlugin/Grab", typeof(UniversalRenderPipeline))]
public sealed class Grab : VolumeComponent, IPostProcessComponent {
    public BoolParameter open = new BoolParameter(false);

    public bool IsActive() => open.value;

    public bool IsTileCompatible() => false;
}

public class LazyResourceID {
    public string name;
    public int id;

    private Func<string> GetName;

    public LazyResourceID(Func<string> getName) {
        GetName = getName;
        CheckForUpdate();
    }

    public void CheckForUpdate() {
        var newName = GetName();

        if (newName != name) {
            name = newName;
            id = Shader.PropertyToID(newName);
        }
    }

    public static implicit operator int(LazyResourceID self) {
        return self.id;
    }

    public static implicit operator RenderTargetIdentifier(LazyResourceID self) {
        return self.id;
    }
}

public class GrabPass : SSPass<Grab> {
    private LazyResourceID _GrabPassTexture = new LazyResourceID(() => "_GrabPassTexture");


    // int _GrabPassTexture = Shader.PropertyToID("_GrabPassTexture");

    public GrabPass() : base("Grab", null, RenderPassEvent.AfterRenderingTransparents) {
    }

    protected override void SSExecute(ref CustomPassContext ctx, Grab gaussianBlur, ref RenderingData renderingData) {
        var descriptor = CreateRenderTextureDescriptor(ref renderingData);
        _GrabPassTexture.CheckForUpdate();
        ctx.cmd.GetTemporaryRT(_GrabPassTexture, descriptor);
        ctx.cmd.Blit(renderer.cameraColorTargetHandle.nameID, _GrabPassTexture);
    }
}