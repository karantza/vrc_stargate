using UdonSharp;
using UnityEngine;
using VRC.SDKBase;
using VRC.Udon;

public class DepthCameraRange : UdonSharpBehaviour
{
    public GateController stargate;

    public GameObject depthCam;

    public void OnPlayerTriggerEnter(VRCPlayerApi player)
    {
        if (player != Networking.LocalPlayer) return;
        if (stargate) stargate.EnableDepthCamera(true);
        if (depthCam) depthCam.SetActive(true);
    }

    public void OnPlayerTriggerExit(VRCPlayerApi player)
    {
        if (player != Networking.LocalPlayer) return;
        if (stargate) stargate.EnableDepthCamera(false);
        if (depthCam) depthCam.SetActive(false);
    }
}
