
using UdonSharp;
using UnityEngine;
using VRC.SDKBase;
using VRC.Udon;

public class GateButton : UdonSharpBehaviour
{
    public GateController gate;
    public AudioSource sound;


    public override void Interact()
    {
        sound.Play();
        gate.ToggleLocalGate();
    }

}
