using System;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class ZRenderFeature : ScriptableRendererFeature {
    [SerializeField] 
    // [HideInInspector]
    // [Reload("Packages/com.unity.render-pipelines.universal/Shaders/Utils/ScreenSpaceAmbientOcclusion.shader")]
    [Reload("Hidden/Universal Render Pipeline/ScreenSpaceAmbientOcclusion")]
    private Shader m_Shader;

    private GaussianBlurPass GaussianBlurPass;

    public override void Create() {
        // m_Shader = Shader.Find();
        // Debug.Log(Shader.Find("Hidden/Universal Render Pipeline/ScreenSpaceAmbientOcclusion"));
        GaussianBlurPass = new GaussianBlurPass();
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
        if (m_Shader == null) {
            m_Shader = Shader.Find("Hidden/Universal Render Pipeline/ScreenSpaceAmbientOcclusion");
        }
        
        GaussianBlurPass.Setup(m_Shader,renderer);
        
        renderer.EnqueuePass(GaussianBlurPass);
    }

    private void OnDisable() {
        GaussianBlurPass?.Dispose();
    }
}