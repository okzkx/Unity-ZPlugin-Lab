using System;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class ZRenderFeature : ScriptableRendererFeature {
    [SerializeField]
    // [HideInInspector]
    // [Reload("Packages/com.unity.render-pipelines.universal/Shaders/Utils/ScreenSpaceAmbientOcclusion.shader")]
    [Reload("Assets/Plugins/Render/51. GaussianBlur/GaussianBlurShader.shader")]
    private Shader m_Shader;

    private GaussianBlurPass GaussianBlurPass;
    private OutlinePass OutlinePass;
    private GrabPass grabPass;
    private PostEffectPass PostEffectPass;

    private List<ScriptableRenderPass> passes;
    private List<SSPass> sspPassList;

    public override void Create() {
        // m_Shader = Shader.Find();
        // Debug.Log(Shader.Find("Hidden/Universal Render Pipeline/ScreenSpaceAmbientOcclusion"));
        // GaussianBlurPass = new GaussianBlurPass();
        // OutlinePass = new OutlinePass();
        // grabPass = new GrabPass();
        // PostEffectPass = new PostEffectPass();
        passes = new List<ScriptableRenderPass>() {
            new PostEffectPass()
        };
        sspPassList = new List<SSPass>() {
            new GaussianBlurPass(),
            new OutlinePass(),
            new GrabPass(),
        };
    }

    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData) {
        // if (!GetMaterials())
        // {
        //     Debug.LogErrorFormat("{0}.AddRenderPasses(): Missing material. {1} render pass will not be added.", GetType().Name, name);
        //     return;
        // }
        //
        // bool shouldAdd = m_SSAOPass.Setup(ref m_Settings, ref renderer, ref m_Material, ref m_BlueNoise256Textures);
        // if (shouldAdd)
        //     renderer.EnqueuePass(m_SSAOPass);

        // Debug.Log(m_Shader);
        // if (m_Shader == null) {
        //     m_Shader = Shader.Find("Hidden/Universal Render Pipeline/ScreenSpaceAmbientOcclusion");
        // }

        // GaussianBlurPass.Setup(renderer);
        // OutlinePass.Setup(renderer);
        // grabPass.SetUp(renderer);
        
        sspPassList.ForEach(s=>s.Setup(renderer));
        passes.ForEach(renderer.EnqueuePass);
        sspPassList.ForEach(renderer.EnqueuePass);

        // renderer.EnqueuePass(GaussianBlurPass);
        // renderer.EnqueuePass(OutlinePass);
        // renderer.EnqueuePass(grabPass);
        // renderer.EnqueuePass(PostEffectPass);
    }

    private void OnDisable() {
        sspPassList.ForEach(s=>s.Release());

        // GaussianBlurPass?.Release();
        // OutlinePass?.Release();
        // grabPass?.Release();
    }
}