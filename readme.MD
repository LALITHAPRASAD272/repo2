# Azure Storage Account Diagnostic Settings — Azure DevOps Automation

Automates enabling of Azure Storage Account Diagnostic Settings (Blob, Queue, Table, File) and routes logs to a centralized Log Analytics Workspace using a multi-stage Azure DevOps YAML pipeline with environment-based approvals.

---

## Project Overview

| Item | Detail |
|---|---|
| Resource Group | `prasad-rg` |
| Storage Accounts | `labaccount434`, `labaccount435` |
| Log Analytics Workspace | `logs` |
| Pipeline Stages | PreProd → Approval → Prod |
| Script Type | PowerShell + Azure CLI |
| Agent | `windows-latest` |

---

## Architecture

```
Azure DevOps Repository
        │
        ▼
Azure DevOps Pipeline (pipeline.yaml)
        │
        ├──▶ Stage 1: PreProd
        │         │
        │         ▼
        │    PowerShell Script
        │    (enable-diagnostics.ps1)
        │         │
        │         ▼
        │    Diagnostic Settings Enabled
        │    labaccount434 + labaccount435
        │         │
        ▼
  Manual Approval Gate (Prod Environment)
        │
        ▼
     Stage 2: Prod
        │
        ▼
   Same PowerShell Script runs again
        │
        ▼
   Logs → Log Analytics Workspace (logs)
```

---

## Repository Structure

```
/
├── pipeline.yaml
└── scripts/
    └── enable-diagnostics.ps1
```

---

## Prerequisites

Before running the pipeline, complete these steps:

### 1. Register Resource Providers

Open Azure Cloud Shell and run:

```bash
az provider register --namespace Microsoft.Insights
az provider register --namespace Microsoft.OperationalInsights
```

Verify registration (wait 1–5 minutes):

```bash
az provider show --namespace Microsoft.Insights --query registrationState
```

Expected output: `"Registered"`

### 2. Create Azure DevOps Service Connection

```
Project Settings → Service Connections → New Service Connection
→ Azure Resource Manager → Service Principal (automatic)
→ Name it: Azure-ServiceConnection
→ Grant: Contributor on subscription
```

### 3. Create Environments

```
Pipelines → Environments → New Environment
→ Create: PreProd   (no approval needed)
→ Create: Prod      (add approval below)
```

### 4. Add Approval on Prod Environment

```
Pipelines → Environments → Prod
→ Approvals and Checks → Add → Approvals
→ Add approver → Save
```

---

## Pipeline File — `pipeline.yaml`

```yaml
trigger: none

pool:
  vmImage: 'windows-latest'

stages:

  - stage: PreProd
    displayName: Enable Diagnostics - PreProd
    jobs:
      - deployment: DeployPreProd
        displayName: Run Diagnostics Script
        environment: PreProd
        strategy:
          runOnce:
            deploy:
              steps:
                - checkout: self
                - task: AzureCLI@2
                  displayName: Enable Diagnostics
                  inputs:
                    azureSubscription: 'Azure-ServiceConnection'
                    scriptType: ps
                    scriptLocation: scriptPath
                    scriptPath: 'scripts/enable-diagnostics.ps1'

  - stage: Prod
    displayName: Enable Diagnostics - Prod
    dependsOn: PreProd
    condition: succeeded()
    jobs:
      - deployment: DeployProd
        displayName: Run Diagnostics Script
        environment: Prod
        strategy:
          runOnce:
            deploy:
              steps:
                - checkout: self
                - task: AzureCLI@2
                  displayName: Enable Diagnostics
                  inputs:
                    azureSubscription: 'Azure-ServiceConnection'
                    scriptType: ps
                    scriptLocation: scriptPath
                    scriptPath: 'scripts/enable-diagnostics.ps1'
```

---

## PowerShell Script — `scripts/enable-diagnostics.ps1`

```powershell
$ResourceGroup = "prasad-rg"
$WorkspaceName = "logs"

$StorageAccounts = @(
    "labaccount434",
    "labaccount435"
)

Write-Host "Getting Log Analytics Workspace ID..."
$LawId = az monitor log-analytics workspace show `
    --resource-group $ResourceGroup `
    --workspace-name $WorkspaceName `
    --query id -o tsv

Write-Host "Workspace ID: $LawId"

foreach ($Storage in $StorageAccounts) {
    Write-Host "===================================="
    Write-Host "Processing Storage Account: $Storage"
    Write-Host "===================================="

    $StorageId = az storage account show `
        --name $Storage `
        --resource-group $ResourceGroup `
        --query id -o tsv

    Write-Host "Storage ID: $StorageId"

    # Blob
    $BlobId = "$StorageId/blobServices/default"
    az monitor diagnostic-settings create `
        --name "blob-diagnostics" `
        --resource $BlobId `
        --workspace $LawId `
        --logs '[{"categoryGroup":"allLogs","enabled":true}]'
    Write-Host "Blob Diagnostics Enabled"

    # Queue
    $QueueId = "$StorageId/queueServices/default"
    az monitor diagnostic-settings create `
        --name "queue-diagnostics" `
        --resource $QueueId `
        --workspace $LawId `
        --logs '[{"categoryGroup":"allLogs","enabled":true}]'
    Write-Host "Queue Diagnostics Enabled"

    # Table
    $TableId = "$StorageId/tableServices/default"
    az monitor diagnostic-settings create `
        --name "table-diagnostics" `
        --resource $TableId `
        --workspace $LawId `
        --logs '[{"categoryGroup":"allLogs","enabled":true}]'
    Write-Host "Table Diagnostics Enabled"

    # File
    $FileId = "$StorageId/fileServices/default"
    az monitor diagnostic-settings create `
        --name "file-diagnostics" `
        --resource $FileId `
        --workspace $LawId `
        --logs '[{"categoryGroup":"allLogs","enabled":true}]'
    Write-Host "File Diagnostics Enabled"
}

Write-Host "All Diagnostics Enabled Successfully"
```

---

## Pipeline Workflow

```
Run Pipeline
     │
     ▼
PreProd Stage runs
     │
     ▼
PowerShell script executes
Blob + Queue + Table + File diagnostics enabled
on labaccount434 and labaccount435
     │
     ▼
PreProd Success ✅
     │
     ▼
Waiting for Manual Approval ⏳
     │
     ▼
Approver reviews and clicks Approve
     │
     ▼
Prod Stage runs
     │
     ▼
Same script runs on Prod
     │
     ▼
All Diagnostics Enabled ✅
```

---

## Diagnostic Settings Created

For each storage account, the following diagnostic settings are created and pointed to the Log Analytics Workspace:

| Setting Name | Service | Category Group |
|---|---|---|
| `blob-diagnostics` | Blob Service | allLogs |
| `queue-diagnostics` | Queue Service | allLogs |
| `table-diagnostics` | Table Service | allLogs |
| `file-diagnostics` | File Service | allLogs |

---

## Verify Logs in Log Analytics Workspace

Open Azure Portal → Log Analytics Workspace (`logs`) → Logs and run:

```kusto
// All storage logs
AzureDiagnostics
| where ResourceProvider == "MICROSOFT.STORAGE"
| order by TimeGenerated desc
| take 50
```

```kusto
// Filter by specific storage account
AzureDiagnostics
| where Resource in ("LABACCOUNT434", "LABACCOUNT435")
| order by TimeGenerated desc
| take 50
```

```kusto
// Blob operations only
StorageBlobLogs
| order by TimeGenerated desc
| take 50
```

> Note: Logs may take 5–15 minutes to appear after first pipeline run. Upload a file to a blob container to generate activity.

---

## Issues Faced and Fixes

### Issue 1 — `HttpResourceNotFound`

**Cause:** Used `az resource show` with `storageAccounts/blobServices` resource type — this path is unreliable for sub-resources.

**Fix:** Fetch the parent storage account ID first, then construct the sub-resource path manually:

```powershell
$StorageId = az storage account show --name $Storage --query id -o tsv
$BlobId    = "$StorageId/blobServices/default"
```

### Issue 2 — `Please register subscription with Microsoft.Insights`

**Cause:** `Microsoft.Insights` resource provider was not registered on the subscription.

**Fix:**

```bash
az provider register --namespace Microsoft.Insights
az provider show --namespace Microsoft.Insights --query registrationState
```

---

## Azure DevOps Components Used

| Component | Purpose |
|---|---|
| Azure Repos Git | Source control for pipeline and script |
| Service Connection | Authenticates pipeline to Azure subscription |
| YAML Pipeline | Multi-stage deployment orchestration |
| Deployment Jobs | Tracks deployment history per environment |
| PreProd Environment | Validation stage with no approval |
| Prod Environment | Protected with manual approval gate |
| AzureCLI@2 Task | Executes PowerShell script with Azure auth |

---

## Key Learnings

- Deployment jobs (not regular jobs) must be used when working with Azure DevOps Environments — they provide deployment history, approval support, and rollback visibility.
- `az resource show` is unreliable for storage sub-resources. Always fetch the parent resource ID and append the sub-resource path.
- `categoryGroup: allLogs` is more robust than listing individual categories like `StorageRead`, `StorageWrite`, `StorageDelete` — category names differ across subscription types.
- `Microsoft.Insights` and `Microsoft.OperationalInsights` providers must be registered before any diagnostic settings API calls will succeed.

---

## Tech Stack

`Azure DevOps` · `YAML Pipelines` · `PowerShell` · `Azure CLI` · `Azure Monitor` · `Log Analytics Workspace` · `Azure Storage` · `KQL`
