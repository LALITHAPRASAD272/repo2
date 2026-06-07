Azure Storage Account Diagnostic Settings — Azure DevOps Automation
Automates enabling of Azure Storage Account Diagnostic Settings (Blob, Queue, Table, File) and routes logs to a centralized Log Analytics Workspace using a multi-stage Azure DevOps YAML pipeline with environment-based approvals.

Project Overview
ItemDetailResource Groupprasad-rgStorage Accountslabaccount434, labaccount435Log Analytics WorkspacelogsPipeline StagesPreProd → Approval → ProdScript TypePowerShell + Azure CLIAgentwindows-latest

Architecture
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

Repository Structure
/
├── pipeline.yaml
└── scripts/
    └── enable-diagnostics.ps1

Prerequisites
Before running the pipeline, complete these steps:
1. Register Resource Providers
Open Azure Cloud Shell and run:
bashaz provider register --namespace Microsoft.Insights
az provider register --namespace Microsoft.OperationalInsights
Verify registration (wait 1–5 minutes):
bashaz provider show --namespace Microsoft.Insights --query registrationState
Expected output: "Registered"
2. Create Azure DevOps Service Connection
Project Settings → Service Connections → New Service Connection
→ Azure Resource Manager → Service Principal (automatic)
→ Name it: Azure-ServiceConnection
→ Grant: Contributor on subscription
3. Create Environments
Pipelines → Environments → New Environment
→ Create: PreProd   (no approval needed)
→ Create: Prod      (add approval below)
4. Add Approval on Prod Environment
Pipelines → Environments → Prod
→ Approvals and Checks → Add → Approvals
→ Add approver → Save


Pipeline Workflow
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

Diagnostic Settings Created
For each storage account, the following diagnostic settings are created and pointed to the Log Analytics Workspace:
Setting NameServiceCategory Groupblob-diagnosticsBlob ServiceallLogsqueue-diagnosticsQueue ServiceallLogstable-diagnosticsTable ServiceallLogsfile-diagnosticsFile ServiceallLogs

Verify Logs in Log Analytics Workspace
Open Azure Portal → Log Analytics Workspace (logs) → Logs and run:
kusto// All storage logs
AzureDiagnostics
| where ResourceProvider == "MICROSOFT.STORAGE"
| order by TimeGenerated desc
| take 50
kusto// Filter by specific storage account
AzureDiagnostics
| where Resource in ("LABACCOUNT434", "LABACCOUNT435")
| order by TimeGenerated desc
| take 50
kusto// Blob operations only
StorageBlobLogs
| order by TimeGenerated desc
| take 50

Note: Logs may take 5–15 minutes to appear after first pipeline run. Upload a file to a blob container to generate activity.


Issues Faced and Fixes
Issue 1 — HttpResourceNotFound
Cause: Used az resource show with storageAccounts/blobServices resource type — this path is unreliable for sub-resources.
Fix: Fetch the parent storage account ID first, then construct the sub-resource path manually:
powershell$StorageId = az storage account show --name $Storage --query id -o tsv
$BlobId    = "$StorageId/blobServices/default"
Issue 2 — Please register subscription with Microsoft.Insights
Cause: Microsoft.Insights resource provider was not registered on the subscription.
Fix:
bashaz provider register --namespace Microsoft.Insights
az provider show --namespace Microsoft.Insights --query registrationState

Azure DevOps Components Used
ComponentPurposeAzure Repos GitSource control for pipeline and scriptService ConnectionAuthenticates pipeline to Azure subscriptionYAML PipelineMulti-stage deployment orchestrationDeployment JobsTracks deployment history per environmentPreProd EnvironmentValidation stage with no approvalProd EnvironmentProtected with manual approval gateAzureCLI@2 TaskExecutes PowerShell script with Azure auth

Key Learnings

Deployment jobs (not regular jobs) must be used when working with Azure DevOps Environments — they provide deployment history, approval support, and rollback visibility.
az resource show is unreliable for storage sub-resources. Always fetch the parent resource ID and append the sub-resource path.
categoryGroup: allLogs is more robust than listing individual categories like StorageRead, StorageWrite, StorageDelete — category names differ across subscription types.
Microsoft.Insights and Microsoft.OperationalInsights providers must be registered before any diagnostic settings API calls will succeed.


Tech Stack
Azure DevOps · YAML Pipelines · PowerShell · Azure CLI · Azure Monitor · Log Analytics Workspace · Azure Storage · KQL
