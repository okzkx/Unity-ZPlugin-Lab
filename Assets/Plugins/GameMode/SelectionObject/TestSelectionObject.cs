using System;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;

public class TestSelectionObject : MonoBehaviour {
    public Material selectedMaterial;
    
    RenderPipelineAsset defaultRenderPipelineAsset;
    public RenderPipelineAsset selectionRenderPipelineAsset;

    private List<Material> sharedMaterials = new List<Material>();

    private void Awake() {
        defaultRenderPipelineAsset = GraphicsSettings.renderPipelineAsset; 
        QualitySettings.renderPipeline = selectionRenderPipelineAsset;
    }

    void Update() {
        var renderers = GameObject.FindObjectsOfType<Renderer>();
        foreach (var renderer in renderers) {
            if ((renderer.gameObject.layer & LayerMask.NameToLayer("Selection")) > 0) {
                renderer.GetSharedMaterials(sharedMaterials);
                if (renderer.gameObject.GetInstanceID() == SelectionObject.InstanceID) {
                    if (!sharedMaterials.Contains(selectedMaterial)) {
                        sharedMaterials.Add(selectedMaterial);
                        renderer.sharedMaterials = sharedMaterials.ToArray();
                    }
                }
                else {
                    if (sharedMaterials.Contains(selectedMaterial)) {
                        sharedMaterials.Remove(selectedMaterial);
                        renderer.sharedMaterials = sharedMaterials.ToArray();
                    }
                }
            }
        }
    }

    private void OnDestroy() {
        QualitySettings.renderPipeline = defaultRenderPipelineAsset;
    }
}