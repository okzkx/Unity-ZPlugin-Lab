using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class GrabPassFeature : ScriptableRendererFeature
{
    class GrabPass : ScriptableRenderPass
    {
        static readonly string k_RenderTag = "GrabPass"; //可在framedebug中看渲染
        RenderTargetIdentifier currentTarget;
        RenderTargetHandle tempColorTarget;
        string m_GrabPassName = "_GrabPassTexture"; //shader中的grabpass名字

        public GrabPass()
        {
            renderPassEvent = RenderPassEvent.AfterRenderingTransparents;
            tempColorTarget.Init(m_GrabPassName);
        }

        public void SetUp(RenderTargetIdentifier currentTarget)
        {
            this.currentTarget = currentTarget;
        }

        public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
        {
        }

        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            var cmd = CommandBufferPool.Get(k_RenderTag);

            cmd.GetTemporaryRT(tempColorTarget.id, Screen.width, Screen.height); //获取临时rt
            cmd.SetGlobalTexture(m_GrabPassName, tempColorTarget.Identifier()); //设置给shader中
            Blit(cmd, currentTarget, tempColorTarget.Identifier());

            context.ExecuteCommandBuffer(cmd);
            CommandBufferPool.Release(cmd);
        }

        public override void OnCameraCleanup(CommandBuffer cmd)
        {
        }
    }

    private GrabPass m_ScriptablePass;

    public override void Create()
    {
        m_ScriptablePass = new GrabPass();
    }

    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        m_ScriptablePass.SetUp(renderer.cameraColorTarget);
        renderer.EnqueuePass(m_ScriptablePass);
    }
}
