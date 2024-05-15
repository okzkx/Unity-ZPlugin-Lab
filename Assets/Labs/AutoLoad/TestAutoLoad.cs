using UnityEngine;
using ZPlugin;

public class TestAutoLoad : MonoBehaviour {
    [AutoLoad] public GameObject objectBeLoad;
    [AutoLoad(Name: "ObjectBeLoad")] public GameObject objectBeLoadWithName;

    private void Awake() {
        this.LoadFields();
    }
}