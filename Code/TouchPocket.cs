
using UdonSharp;
using UnityEngine;
using VRC.SDKBase;
using VRC.Udon;

public class TouchPocket : UdonSharpBehaviour
{
    public GateController gate;

    void Start()
    {
        
    }

    public void OnTriggerEnter(Collider col)
    {
        gate.ObjectTouchingVolume(col.gameObject, true);
    } 

    public void OnTriggerStay(Collider col)
    {
        gate.ObjectTouchingVolume(col.gameObject, true);
    }

    public void OnTriggerExit(Collider col)
    {
        gate.ObjectTouchingVolume(col.gameObject, false);
    }

    public override void OnPlayerTriggerEnter(VRCPlayerApi player)
    {
        if (player == Networking.LocalPlayer)
            gate.LocalPlayerTouchingVolume(true);
    }

    public override void OnPlayerTriggerExit (VRCPlayerApi player)
    {
        if (player == Networking.LocalPlayer)
            gate.LocalPlayerTouchingVolume(false);
    }
}
