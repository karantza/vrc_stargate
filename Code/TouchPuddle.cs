
using UdonSharp;
using UnityEngine;
using VRC.SDKBase;
using VRC.Udon;

public class TouchPuddle     : UdonSharpBehaviour
{
    public GateController gate;

    public AudioSource enterAudio;
    
    public GameObject[] exceptions ;
    
    void Start()
    {
        
    }

    public void OnTriggerEnter(Collider col)
    {
        foreach(var item in exceptions)
            if (col.gameObject == item)
                return;

                
        if (gate.isGateOpen) enterAudio.Play();
        gate.ObjectTouchingFront(col.gameObject, true);

    }

    public void OnTriggerExit(Collider col)
    {
        foreach(var item in exceptions)
            if (col.gameObject == item)
                return;
        gate.ObjectTouchingFront(col.gameObject, false);
    }

    public override void OnPlayerTriggerEnter(VRCPlayerApi player)
    {
        if (gate.isGateOpen) enterAudio.Play();
        if (player == Networking.LocalPlayer)
            gate.LocalPlayerTouchingFront(true);
    }

    public override void OnPlayerTriggerExit (VRCPlayerApi player)
    {
        if (player == Networking.LocalPlayer)
            gate.LocalPlayerTouchingFront(false);
    }
}
