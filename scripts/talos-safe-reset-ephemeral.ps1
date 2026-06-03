param(
    [Parameter(Mandatory = $true)]
    [string]$Node,

    [Parameter(Mandatory = $true)]
    [string]$Address,

    [Parameter(Mandatory = $true)]
    [string]$Config,

    [int]$LonghornEvictionTimeoutMinutes = 45,

    [int]$NodeReadyTimeoutMinutes = 20,

    [switch]$ForceDrain,

    [switch]$Yes
)

$ErrorActionPreference = "Stop"

function Invoke-Step {
    param(
        [string]$Message,
        [scriptblock]$Command
    )

    Write-Host ""
    Write-Host "==> $Message"
    & $Command
}

function Get-LonghornRunningReplicasOnNode {
    $replicas = kubectl -n longhorn-system get replicas.longhorn.io -o json | ConvertFrom-Json

    @(
        $replicas.items | Where-Object {
            $_.spec.nodeID -eq $Node -and
            $null -eq $_.metadata.deletionTimestamp -and
            $_.status.currentState -ne "stopped"
        }
    )
}

function Wait-LonghornReplicaEviction {
    $deadline = (Get-Date).AddMinutes($LonghornEvictionTimeoutMinutes)

    while ((Get-Date) -lt $deadline) {
        $remaining = Get-LonghornRunningReplicasOnNode

        if ($remaining.Count -eq 0) {
            Write-Host "No running Longhorn replicas remain on $Node"
            return
        }

        $names = ($remaining | ForEach-Object { $_.metadata.name }) -join ", "
        Write-Host "Waiting for running Longhorn replicas to leave $Node ($($remaining.Count) remaining): $names"
        Start-Sleep -Seconds 30
    }

    throw "Timed out waiting for running Longhorn replicas to leave $Node"
}

function Confirm-EphemeralReset {
    if ($Yes) {
        return
    }

    Write-Host ""
    Write-Host "This will reset only the Talos EPHEMERAL volume on $Node ($Address)."
    Write-Host "It is destructive to EPHEMERAL data, but it does not wipe STATE."
    Write-Host "Type '$Node/EPHEMERAL' to continue."

    $confirmation = Read-Host "Confirmation"
    if ($confirmation -ne "$Node/EPHEMERAL") {
        throw "Confirmation did not match '$Node/EPHEMERAL'"
    }
}

if (-not (Test-Path -LiteralPath $Config)) {
    throw "Talos config file does not exist: $Config"
}

Confirm-EphemeralReset

$longhornSchedulingChanged = $false
$nodeDrained = $false

try {
    Invoke-Step "Disable Longhorn scheduling and request replica eviction on $Node" {
        kubectl -n longhorn-system patch nodes.longhorn.io $Node --type merge -p '{"spec":{"allowScheduling":false,"evictionRequested":true}}'
        $script:longhornSchedulingChanged = $true
    }

    Invoke-Step "Wait for Longhorn replicas to leave $Node" {
        Wait-LonghornReplicaEviction
    }

    Invoke-Step "Drain Kubernetes node $Node" {
        $drainArgs = @(
            "drain",
            $Node,
            "--ignore-daemonsets",
            "--delete-emptydir-data",
            "--disable-eviction",
            "--timeout=10m"
        )

        if ($ForceDrain) {
            $drainArgs += "--force"
        }

        kubectl @drainArgs
        $script:nodeDrained = $true
    }

    Invoke-Step "Stage Talos config on $Node" {
        talosctl apply-config --nodes $Address --file $Config --mode=staged
    }

    Invoke-Step "Reset only the Talos EPHEMERAL volume on $Node and reboot" {
        talosctl reset --nodes $Address --system-labels-to-wipe EPHEMERAL --reboot
    }

    Invoke-Step "Wait for $Node to return Ready" {
        Start-Sleep -Seconds 45
        kubectl wait "node/$Node" --for=condition=Ready "--timeout=$($NodeReadyTimeoutMinutes)m"
    }

    Invoke-Step "Verify Talos volume status on $Node" {
        talosctl --nodes $Address get volumestatus
    }
}
finally {
    if ($nodeDrained) {
        Invoke-Step "Uncordon Kubernetes node $Node" {
            kubectl uncordon $Node
        }
    }

    if ($longhornSchedulingChanged) {
        Invoke-Step "Re-enable Longhorn scheduling on $Node" {
            kubectl -n longhorn-system patch nodes.longhorn.io $Node --type merge -p '{"spec":{"allowScheduling":true,"evictionRequested":false}}'
        }
    }
}
