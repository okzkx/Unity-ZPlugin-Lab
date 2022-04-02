using System;
using UnityEngine;
using ZPlugin;

public class TestTimer : MonoBehaviour {
    private Timer timer;

    private void Start() {
        timer = new Timer();
        TimerUtil.InvokeDelay(() => Debug.Log("TimerUtil.InvokeDelay"), 3f);
        TimerUtil.InverseLerp(10, (t) => Debug.Log(t));
    }

    private void Update() {
        OnGUITool.Show(timer);
    }
}