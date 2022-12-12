using UdonSharp;
using UnityEngine;
using VRC.SDKBase;
using VRC.Udon;

[UdonBehaviourSyncMode(BehaviourSyncMode.Manual)]
public class GateController : UdonSharpBehaviour
{
    public GameObject transitSpace;

    public Animator gateAnimator;

    public AudioSource failSound;

    [UdonSynced]
    public bool isGateOpen; // True if the gate should be open

    [UdonSynced]
    public bool isGatePortal; // True if the open gate is a world portal

    private float startTime;

    private Camera myDepthCamera;

    public void EnableDepthCamera(bool enable)
    {
        // Toggle off the camera's game object if we're out of range
        myDepthCamera.gameObject.SetActive (enable);
    }

    void Start()
    {
        startTime = Time.time;
        myDepthCamera = transform.Find("Depth Camera").GetComponent<Camera>();
    }

    public override void OnDeserialization()
    {
        if (isGateOpen && Time.time - startTime < 3)
        {
            gateAnimator.SetTrigger("TurnOnDirectly");
        }
        else
        {
            AssertAnimatorState();
        }
    }

    private void AssertAnimatorState()
    {
        gateAnimator.SetBool("Active", isGateOpen);
    }

    /* Handle the world portal logic. */
    public void OnPortalDropped()
    {
        if (!Networking.LocalPlayer.IsOwner(gameObject)) return; // Gate state is controlled by master only to keep it synced

        if (isGateOpen && !isGatePortal)
        {
            // Close and reopen
            gateAnimator.SetBool("Active", false);
            RequestSerialization();
            AssertAnimatorState();
        }

        isGatePortal = true;
        isGateOpen = true;
        RequestSerialization();
        AssertAnimatorState();
    }

    public void OnPortalClosed()
    {
        if (!Networking.LocalPlayer.IsOwner(gameObject)) return; // Gate state is controlled by master only to keep it synced
        if (!isGateOpen || !isGatePortal) return;

        isGatePortal = false;
        isGateOpen = false;
        RequestSerialization();
        AssertAnimatorState();
    }

    /* Handle the intra-world teleport logic */
    public Transform[] ignoreList;

    public Transform destination;

    public Transform localBack;

    public GateController targetLocalGate;

    private bool touchFront;

    private bool touchVolume;

    private GameObject[] objectTransitList = new GameObject[10];

    private int[] objectTransitState = new int[10]; // 0 = no contact. 1 = touched the front. 2 = touched the interior.

    // This is triggered by the local DHD.
    public void ToggleLocalGate()
    {
        if (isGatePortal || (!isGateOpen && targetLocalGate.isGateOpen))
        {
            failSound.Play();
            return;
        }

        if (isGateOpen)
        {
            CloseLocalGate();
            targetLocalGate.CloseLocalGate();
        }
        else
        {
            OpenLocalGate();
            targetLocalGate.OpenLocalGate();
        }
    }

    public void OpenLocalGate()
    {
        Networking.SetOwner(Networking.LocalPlayer, gameObject);
        isGatePortal = false;
        isGateOpen = true;
        RequestSerialization();
        AssertAnimatorState();
    }

    public void CloseLocalGate()
    {
        Networking.SetOwner(Networking.LocalPlayer, gameObject);
        isGatePortal = false;
        isGateOpen = false;

        RequestSerialization();
        AssertAnimatorState();
    }

    public void PrimeForIncoming()
    {
        // When a player enters, there's one frame after they're teleported but before the other gate detects them
        // and turns on the Buffer graphics. So this method exists for the other gate to "call ahead" and turn on that buffer mesh
        // so the player doesn't get a flicker upon transit.
        // In the future this might also move our render textures, cameras, etc.
        transitSpace.SetActive(true);
    }

    public void LocalPlayerTouchingFront(bool touching)
    {
        touchFront = touching;

        // Touching the front of the gate always makes the pocket visible.
        transitSpace.SetActive((touchVolume || touchFront) && isGateOpen);

        // If you lose contact with the front while inside the pocket, you transit.
        if (touchVolume && !touchFront && isGateOpen)
        {
            TransitPlayer();
        }
    }

    public void LocalPlayerTouchingVolume(bool touching)
    {
        touchVolume = touching;

        // Touching the front of the gate always makes the pocket visible.
        transitSpace.SetActive((touchVolume || touchFront) && isGateOpen);

        // If we have left the volume, and we're not in contact with the surface, we're out of the pocket.
        // Maybe we transited!
        if (!touchVolume && !touchFront)
        {
            transitSpace.SetActive(false);
        }
    }

    private bool ShouldIgnore(GameObject obj)
    {
        foreach (var ignore in ignoreList)
        if (obj.transform.IsChildOf(ignore)) return true;
        return false;
    }

    private void SetTransitState(GameObject obj, int state)
    {
        for (int i = 0; i < objectTransitList.Length; i++)
        {
            if (objectTransitList[i] == obj)
            {
                if (state == 0)
                {
                    objectTransitList[i] = null;
                    objectTransitState[i] = 0;
                }
                else
                {
                    objectTransitList[i] = obj;
                    objectTransitState[i] = state;
                }
                return;
            }
        }

        // We didn't find  it, add an entry
        if (state > 0)
        {
            for (int i = 0; i < objectTransitList.Length; i++)
            {
                if (objectTransitList[i] == null)
                {
                    objectTransitList[i] = obj;
                    objectTransitState[i] = state;
                    return;
                }
            }
        }
    }

    private int GetTransitState(GameObject obj)
    {
        for (int i = 0; i < objectTransitList.Length; i++)
        {
            if (objectTransitList[i] == obj) return objectTransitState[i];
        }
        return 0;
    }

    public void ObjectTouchingFront(GameObject obj, bool touching)
    {
        if (!isGateOpen || ShouldIgnore(obj)) return;

        var transitState = GetTransitState(obj);

        if (transitState == 0 && touching)
            SetTransitState(obj, 1); // Advance to the touching-front state
        else if (transitState == 2 && !touching)
            TransitObject(obj); // Transit the object
        else if (!touching) SetTransitState(obj, 0); // If we stop touching the front and aren't in state 2, cancel the process
    }

    public void ObjectTouchingVolume(GameObject obj, bool touching)
    {
        if (!isGateOpen || ShouldIgnore(obj)) return;

        var transitState = GetTransitState(obj);

        if (transitState == 1 && touching) SetTransitState(obj, 2); // Advance to the touching-interior state
        if (transitState == 2 && !touching) SetTransitState(obj, 1); // Back out of the touching-interior state
    }

    static Vector3 PosFromMat(Matrix4x4 mat)
    {
        return new Vector3(mat[0, 3], mat[1, 3], mat[2, 3]);
    }

    Matrix4x4 GateTransform(Matrix4x4 startAt)
    {
        Matrix4x4 srcGateTx = localBack.transform.localToWorldMatrix;
        Matrix4x4 destTx = destination.transform.localToWorldMatrix;

        Matrix4x4 relTx = srcGateTx.inverse * startAt;

        var relPos = PosFromMat(relTx);

        Matrix4x4 flip =
            Matrix4x4
                .TRS(Vector3.zero,
                Quaternion.Euler(0, 0, 180), // Rotate so we're coming out straight
                new Vector3(1, 1, 1));

        return destTx * flip * relTx;
    }

    void TransitPlayer()
    {
        if (!destination || isGatePortal) return; // no destination set? Don't teleport

        targetLocalGate.PrimeForIncoming(); // Tell the other gate that the player is about to arrive.

        Matrix4x4 playerTx =
            Matrix4x4
                .TRS(Networking.LocalPlayer.GetPosition(),
                Networking.LocalPlayer.GetRotation(),
                Vector3.one);

        Matrix4x4 newTx = GateTransform(playerTx);

        var position = PosFromMat(newTx);
        var rotation = newTx.rotation;

        Networking.LocalPlayer.TeleportTo (position, rotation);
    }

    void TransitObject(GameObject obj)
    {
        SetTransitState(obj, 0);

        if (!destination) return; // no destination set? Don't teleport

        if (Networking.LocalPlayer.IsOwner(obj))
        {
            Matrix4x4 objTx =
                Matrix4x4
                    .TRS(obj.transform.position,
                    obj.transform.rotation,
                    Vector3.one);

            var newTx = GateTransform(objTx);

            obj.transform.position = PosFromMat(newTx);
            obj.transform.rotation = newTx.rotation;

            // Kick objects out of the other gate with a little momentum, to make sure they clear the buffer area.
            var rb = obj.GetComponent<Rigidbody>();
            if (rb)
                rb.velocity +=
                    (
                    Vector3
                    )(localBack.transform.localToWorldMatrix *
                    new Vector4(0, -5, 0, 0));

            // If this object is synced, it'll interpolate position for non-owners. So we tell it not to.
            var os = obj.GetComponent<VRC.SDK3.Components.VRCObjectSync>();
            if (os) os.FlagDiscontinuity();
        }
    }
}
