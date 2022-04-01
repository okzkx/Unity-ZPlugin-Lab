using UnityEngine;
using ZPlugin;

public class TestAutoSet : MonoBehaviour {
    [AutoSet] public MeshFilter selfMeshFilter;
    [AutoSet] public MeshRenderer selfMeshRenderer;
    [AutoSet] public Rigidbody findFirstRigibodyInChild;
    [AutoSet("Sphere")] public MeshFilter ChildMeshFilterWithStringName;
    [Header("ChildMeshFilterWithFieldName")]
    [AutoSet("Capsule")] public MeshFilter Capsule;
    
    private void Awake() {
        this.SetFields();
    }
}